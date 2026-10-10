# Travel Buddy - Security Architecture & Hardening Guide

This document outlines the comprehensive security architecture, threat model, vulnerability reporting protocol, privacy practices under the India Digital Personal Data Protection (DPDP) Act 2023, and the mandatory production deployment checklist for Travel Buddy.

---

## 1. Threat Model & Mitigations

Travel Buddy operates in adversarial environments where transport syndicates, overcharging operators, and malicious actors may attempt to undermine the platform's price integrity or breach user privacy.

| Threat Category | Potential Attack Vector | Applied Mitigation |
| :--- | :--- | :--- |
| **AI Prompt Injection** | Adversarial instructions inserted into route names or quoted prices to trick Gemini into endorsing unfair prices or leaking internal prompts. | • Regex sanitization & injection pattern detection.<br>• Data boundary fencing with XML-style tags (`<untrusted_price_query>`).<br>• Enforced output schema validation.<br>• Fallback to deterministic algorithmic calculation on injection detection.<br>• Tool execution is strictly locked to an allowlist. |
| **Community Poisoning** | Syndicates flooding fake high prices to artificially inflate the community benchmark. | • Range validation (₹20 min, max ₹50,000, max ₹200/km for autos, ₹300/km for taxis).<br>• Deduplication window: 10 minutes per route/service.<br>• Anonymous daily rate limit: max 20 reports per device/day.<br>• Reputation weighting: initial weight 0.5, scaling to 1.0 after $\ge 3$ reports.<br>• Flag-and-exclude: flagged reports are excluded from benchmark percentiles. |
| **Credential Harvesting** | Decompiling client bundle to steal Google Maps or Gemini API keys. | • **Zero keys in client**: Flutter app contains no API keys.<br>• Keys live solely in proxy environment variables (`GOOGLE_MAPS_SERVER_KEY`, `GEMINI_API_KEY`).<br>• Gitleaks pre-commit scanning rejects accidental key commits. |
| **SSRF (Server-Side Request Forgery)** | Crafting malicious redirect URLs via `/resolve-link` to hit cloud metadata or internal private networks. | • Strict domain allowlist (`maps.google.com`, `maps.app.goo.gl`, `goo.gl`).<br>• DNS resolution check: blocks RFC 1918 private subnets, loopback (`127.0.0.1`), and cloud metadata (`169.254.169.254`).<br>• 8-second timeout on all outbound requests. |
| **Network Interception & MITM** | Intercepting user requests on hostile public Wi-Fi networks (airports, railway stations). | • Android `network_security_config.xml` pins certificates to system CAs only.<br>• `cleartextTrafficPermitted=false` blocks plaintext HTTP.<br>• Strict HTTPS enforced on all production endpoints. |
| **User Doxxing & Tracking** | Intercepting community reports to track travellers' physical coordinates or home/hotel locations. | • GPS coordinates truncated and rounded to 3 decimal places (~110m privacy radius).<br>• Auto-redaction of phone numbers and email addresses in all report text.<br>• Anonymous UUIDs rotated on "Clear My Data". |
| **Legal & Defamation Risks** | Business owners claiming false accusations or slander from crowd reports. | • Community Disclaimer Banner on every report.<br>• Dedicated Takedown & Appeal dialog for vehicle operators and vendors.<br>• Reports represent user experiences, not official or legal declarations. |

---

## 2. Vulnerability Reporting Policy

We welcome security researchers and community feedback.

- **Reporting Email**: `security@travelbuddy.app` (or open a private security advisory on GitHub).
- **Response SLA**: Initial acknowledgement within **24 hours**; triaged status update within **72 hours**.
- **Scope**:
  - Proxy endpoints (`proxy/server.js`)
  - AI Safety boundaries (`proxy/ai_safety.js`)
  - Client state and validation (`lib/core/utils/report_security_validator.dart`)
  - Firestore & Storage security rules (`firestore.rules`, `storage.rules`)
- **Safe Harbor**: Good-faith research following this policy is covered under our safe harbor commitment and will not face legal action.

---

## 3. Secret Management & Key Architecture

```
┌─────────────────────────────────┐
│     Flutter Client (Web/APK)    │
│  • Zero API Keys in binary      │
│  • Obfuscated release builds    │
└────────────────┬────────────────┘
                 │ HTTPS only (Strict CORS allowlist)
                 ▼
┌─────────────────────────────────┐
│       Node.js Secure Proxy      │
│  • Environment Variables:       │
│    - GOOGLE_MAPS_SERVER_KEY     │
│    - GEMINI_API_KEY             │
│  • Per-IP Rate Limiting (60/m)  │
│  • 8 KB Maximum Body Size       │
│  • Daily Budget Hard Caps       │
└──────────┬──────────────┬───────┘
           │              │
           ▼              ▼
  Google Places & Routes   Google Gemini AI
  (IP & API restricted)   (Model restricted)
```

- Keys must **NEVER** be committed to source control.
- In development, keys are placed in `proxy/.env` (excluded by `.gitignore`).
- If an API key is ever detected in git history or CI logs, execute the rotation protocol immediately:
  1. Generate a new API key in Google Cloud Console.
  2. Update the environment variables in the hosting provider (e.g. Cloud Run, Railway).
  3. Delete the old key in Google Cloud Console.

---

## 4. Data Privacy, Collection & Retention (DPDP Act 2023)

Travel Buddy follows strict **Data Minimization** and **Purpose Limitation** principles:

| Data Element | Storage Location | Retention Period | Purpose |
| :--- | :--- | :--- | :--- |
| **GPS Location (Rough)** | Device RAM only (rounded to 3 decimals upon report submission) | Discarded upon app closure | Route distance calculation and regional fare tariff lookup |
| **Anonymous User UUID** | Local device preferences | Until user taps "Clear My Data" | Daily abuse prevention (20 reports/day cap) |
| **Paid Fare Reports** | Firestore (anonymized, create-only) | Aggregate long-term | Computing crowd-sourced fare percentiles |
| **Cached Place Details** | Proxy in-memory cache | 10 minutes | Minimizing redundant Google Places API queries |

### User Rights & "Clear My Data"
Users have the absolute right to erasure. Navigating to **Profile $\rightarrow$ Privacy & Legal $\rightarrow$ Clear My Data** permanently:
1. Clears all cached trip history and saved routes.
2. Removes all locally stored price reports.
3. Deletes and rotates the anonymous installation UUID.

---

## 5. Production Operator Deployment Checklist

Before taking the application into production, verify each item:

### A. Google Cloud Console
- [ ] **API Restriction**: Restrict `GOOGLE_MAPS_SERVER_KEY` to **Places API (New)**, **Routes API**, and **Geocoding API** only.
- [ ] **Application / IP Restriction**: Bind the key to the specific static outbound IP(s) of your proxy hosting server.
- [ ] **Billing Quotas**: In Google Cloud Billing, set a monthly budget with automated alerts at 50%, 80%, and 100%. Set hard quota caps on Places API requests/day.

### B. Gemini API (Google AI Studio)
- [ ] **Model Restriction**: Restrict `GEMINI_API_KEY` to `gemini-2.5-flash` or `gemini-2.5-flash-lite`.
- [ ] **Usage Limits**: Configure a daily query ceiling in Google AI Studio to prevent runaway costs from automated scrapers.

### C. Firebase Firestore & Storage Rules
- [ ] Deploy Firestore security rules:
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] Deploy Storage security rules:
  ```bash
  firebase deploy --only storage
  ```
- [ ] Verify client access is create-only; updates and deletions from mobile clients are blocked.

### D. Web Hosting Security Headers
Ensure your hosting provider (Firebase Hosting, Cloudflare Pages, Vercel, Netlify) serves the headers configured in `firebase.json` and `web/_headers`:
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY`
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy: geolocation=(self), camera=(), microphone=()`
- [ ] `Content-Security-Policy: default-src 'self'; ... frame-ancestors 'none';`

### E. Mobile Build Commands (Obfuscation)
Always compile Android release binaries with code shrinking, R8 ProGuard rules, and symbol obfuscation:
```bash
# Build obfuscated release APK with split debug symbols
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Build obfuscated App Bundle for Google Play
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
Save the resulting debug symbols under `build/app/outputs/symbols` in your secure internal archive for de-obfuscating crash logs.
