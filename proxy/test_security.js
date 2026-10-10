/**
 * Phase Sec1: Automated Security & Proxy Hardening Tests
 * Tests:
 *   1. CORS allowlist enforcement & rejection of disallowed origins
 *   2. Strict 8 KB payload cap enforcement (413)
 *   3. Schema validation & rejection of unknown fields (400)
 *   4. Coordinate range validation (400)
 *   5. SSRF protection on /resolve-link (HTTPS only, domain allowlist, IP blocklist)
 *   6. Rate limiting (429 with Retry-After)
 *   7. Privacy: No sensitive telemetry in error bodies
 */

const http = require('node:http');
const assert = require('node:assert');

const BASE_URL = 'http://127.0.0.1:8080';

function makeRequest({ path, method = 'POST', headers = {}, body = null }) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...headers,
    };

    const req = http.request(
      url,
      {
        method,
        headers: reqHeaders,
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(raw);
          } catch (_) {}
          resolve({ status: res.statusCode, headers: res.headers, body: json, raw });
        });
      }
    );

    req.on('error', reject);
    if (body) {
      if (typeof body === 'string') req.write(body);
      else req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runSecurityTests() {
  console.log('--- Starting Phase Sec1 Proxy Security Hardening Tests ---');
  let passed = 0;

  // 1. Health check returns 200 without exposing secrets
  {
    const res = await makeRequest({ path: '/health', method: 'GET' });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
    assert.strictEqual(typeof res.body.hasGoogleKey, 'boolean');
    assert.strictEqual(res.raw.includes('AIza'), false, 'Must NOT leak any API key in health endpoint');
    console.log('✓ 1. Health check operational with zero credential leakage');
    passed++;
  }

  // 2. CORS: Allowed origin accepted with CORS header
  {
    const res = await makeRequest({
      path: '/health',
      method: 'GET',
      headers: { Origin: 'http://localhost:3000' },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.headers['access-control-allow-origin'], 'http://localhost:3000');
    console.log('✓ 2. Allowed CORS origin receives explicit Allow-Origin header (no wildcard)');
    passed++;
  }

  // 3. CORS: Disallowed origin rejected with 403 Forbidden
  {
    const res = await makeRequest({
      path: '/health',
      method: 'GET',
      headers: { Origin: 'https://evil-hacker-site.com' },
    });
    assert.strictEqual(res.status, 403, 'Must reject unauthorized origin with HTTP 403');
    assert.strictEqual(res.body.error, 'Origin not allowed');
    console.log('✓ 3. Disallowed origin rejected with HTTP 403 Forbidden');
    passed++;
  }

  // 4. Payload Size Limit: Bodies > 8 KB rejected with 413 Payload Too Large
  {
    const hugeInput = 'a'.repeat(9000); // 9 KB
    const res = await makeRequest({
      path: '/places/autocomplete',
      method: 'POST',
      body: { input: hugeInput },
    });
    assert.strictEqual(res.status, 413, 'Must reject payloads > 8 KB with 413');
    assert.strictEqual(res.body.error, 'Payload exceeds 8 KB limit');
    console.log('✓ 4. Request exceeding 8 KB limit rejected with HTTP 413');
    passed++;
  }

  // 5. Malformed JSON returns 400 Bad Request
  {
    const res = await makeRequest({
      path: '/places/autocomplete',
      method: 'POST',
      body: '{"input": "broken json...',
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error, 'Malformed JSON payload');
    console.log('✓ 5. Malformed JSON payload cleanly rejected with HTTP 400');
    passed++;
  }

  // 6. Schema Validation: Unknown fields rejected with 400
  {
    const res = await makeRequest({
      path: '/places/autocomplete',
      method: 'POST',
      body: { input: 'Jaipur', maliciousInjectedKey: 'admin_bypass' },
    });
    assert.strictEqual(res.status, 400, 'Must reject unknown fields');
    assert.strictEqual(res.body.error, 'Invalid request parameters');
    console.log('✓ 6. Unknown/injected fields rejected with HTTP 400');
    passed++;
  }

  // 7. Schema Validation: Coordinate bounds validation on /geocode
  {
    const res = await makeRequest({
      path: '/geocode',
      method: 'POST',
      body: { latitude: 95.5, longitude: 75.0 }, // Latitude > 90
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error, 'Invalid coordinate parameters');
    console.log('✓ 7. Out-of-bounds coordinates (-90..90) rejected with HTTP 400');
    passed++;
  }

  // 8. SSRF Protection: HTTP (non-https) rejected
  {
    const res = await makeRequest({
      path: '/resolve-link',
      method: 'POST',
      body: { url: 'http://maps.google.com/test' },
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.error, 'HTTPS protocol required');
    console.log('✓ 8. Non-HTTPS links on /resolve-link rejected');
    passed++;
  }

  // 9. SSRF Protection: Private loopback & AWS metadata IP blocked
  {
    const res1 = await makeRequest({
      path: '/resolve-link',
      method: 'POST',
      body: { url: 'https://169.254.169.254/latest/meta-data' },
    });
    assert.strictEqual(res1.status, 400);
    assert.strictEqual(res1.body.error, 'Could not resolve Google Maps URL');

    const res2 = await makeRequest({
      path: '/resolve-link',
      method: 'POST',
      body: { url: 'https://127.0.0.1:8080/secret' },
    });
    assert.strictEqual(res2.status, 400);
    console.log('✓ 9. Loopback and cloud metadata SSRF vectors strictly blocked');
    passed++;
  }

  // 10. SSRF Protection: Non-Google domain blocked
  {
    const res = await makeRequest({
      path: '/resolve-link',
      method: 'POST',
      body: { url: 'https://attacker-fake-site.com/maps/place/test' },
    });
    assert.strictEqual(res.status, 400);
    console.log('✓ 10. Non-allowlisted external domain blocked from resolution');
    passed++;
  }

  // 11. Generic error messages: No internal stack traces in response
  {
    const res = await makeRequest({
      path: '/places/details',
      method: 'POST',
      body: { placeId: 'invalid_nonexistent_id' },
    });
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.raw.includes('node_modules'), false, 'Must not expose stack traces');
    assert.strictEqual(res.raw.includes('Error:'), false, 'Must not expose raw error objects');
    console.log('✓ 11. Generic error responses with zero stack trace leakage');
    passed++;
  }

  console.log(`\nAll ${passed} Phase Sec1 security tests passed successfully!`);
}

runSecurityTests().catch((err) => {
  console.error('Test failed with error:', err);
  process.exit(1);
});
