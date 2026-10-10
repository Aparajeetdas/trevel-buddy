/**
 * Travel Buddy - Agent Rate Limiter & User Quota Tracker
 *
 * Rules:
 *   - Per-user quota: 30 requests per day (resets at UTC midnight)
 *   - Per-IP rate limit: 10 requests per minute
 *   - Returns { allowed: boolean, retryAfterSeconds?: number, reason?: string }
 */

// In-memory user daily quotas: Map<uid, { date: 'YYYY-MM-DD', count: number }>
const userQuotas = new Map();

// In-memory IP sliding windows: Map<ip, number[]> (timestamps in ms)
const ipRequestLogs = new Map();

/**
 * Checks and records a request for the authenticated user ID.
 * @param {string} uid - Firebase User ID
 * @param {number} maxPerDay - Max requests per calendar day (default 30)
 * @returns {{ allowed: boolean, remaining: number, retryAfterSeconds: number }}
 */
function checkUserQuota(uid, maxPerDay = 30) {
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);

  // Compute seconds until next UTC midnight for Retry-After
  const tomorrow = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
  const secondsUntilMidnight = Math.max(1, Math.ceil((tomorrow.getTime() - now.getTime()) / 1000));

  let record = userQuotas.get(uid);
  if (!record || record.date !== todayStr) {
    record = { date: todayStr, count: 0 };
    userQuotas.set(uid, record);
  }

  if (record.count >= maxPerDay) {
    return {
      allowed: false,
      remaining: 0,
      retryAfterSeconds: secondsUntilMidnight,
      reason: `Daily user quota of ${maxPerDay} requests reached`,
    };
  }

  record.count += 1;
  return {
    allowed: true,
    remaining: maxPerDay - record.count,
    retryAfterSeconds: 0,
  };
}

/**
 * Checks and records a request for the client IP address.
 * @param {string} clientIp - Client IP address
 * @param {number} maxPerMinute - Max requests per 60 seconds (default 10)
 * @returns {{ allowed: boolean, retryAfterSeconds: number }}
 */
function checkIpRateLimit(clientIp, maxPerMinute = 10) {
  const now = Date.now();
  const windowMs = 60 * 1000;
  const cutoff = now - windowMs;

  let timestamps = ipRequestLogs.get(clientIp);
  if (!timestamps) {
    timestamps = [];
    ipRequestLogs.set(clientIp, timestamps);
  }

  // Filter timestamps within window
  timestamps = timestamps.filter((t) => t > cutoff);
  ipRequestLogs.set(clientIp, timestamps);

  if (timestamps.length >= maxPerMinute) {
    const oldestInWindow = timestamps[0];
    const retryAfterSeconds = Math.max(1, Math.ceil((oldestInWindow + windowMs - now) / 1000));
    return {
      allowed: false,
      retryAfterSeconds,
      reason: `IP rate limit of ${maxPerMinute} requests per minute exceeded`,
    };
  }

  timestamps.push(now);
  return {
    allowed: true,
    retryAfterSeconds: 0,
  };
}

/**
 * Clears user quotas and IP rate logs (used for testing).
 */
function resetRateLimits() {
  userQuotas.clear;
  userQuotas.clear();
  ipRequestLogs.clear();
}

module.exports = {
  checkUserQuota,
  checkIpRateLimit,
  resetRateLimits,
};
