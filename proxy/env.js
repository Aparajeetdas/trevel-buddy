/**
 * Travel Buddy - Zod-Validated Environment Configuration
 * Validated at startup; credentials are never sent to the client and never logged.
 */

const { z } = require('zod');
const fs = require('node:fs');
const path = require('node:path');

// Auto-load .env file if present
try {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    for (const line of envContent.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        const key = trimmed.slice(0, eqIdx).trim();
        const val = trimmed.slice(eqIdx + 1).trim();
        if (!process.env[key]) {
          process.env[key] = val;
        }
      }
    }
  }
} catch (_) {}

const envSchema = z.object({
  GEMINI_API_KEY: z.string().optional().default(''),
  GEMINI_MODEL: z
    .string()
    .optional()
    .default('gemini-3.8-flash')
    .transform((m) => (m === 'gemini-1.5-flash' || !m ? 'gemini-3.8-flash' : m)),
  GOOGLE_MAPS_SERVER_KEY: z.string().optional().default(''),
  GOOGLE_MAPS_API_KEY: z.string().optional().default(''),
  PORT: z.string().optional().default('8080'),
  ALLOWED_ORIGINS: z.string().optional().default(''),
  FIREBASE_PROJECT_ID: z.string().optional().default('aparajeet-das'),
  DAILY_CAP_SEARCH: z.string().optional().default('10000'),
  DAILY_CAP_ROUTE: z.string().optional().default('5000'),
  DAILY_CAP_AI: z.string().optional().default('2000'),
  NODE_ENV: z.string().optional().default('development'),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  // Never log secret values; only output validation error structure
  console.error('[Configuration Error] Environment variable validation failed:', parsed.error.issues.map(i => i.path.join('.')));
}

const config = parsed.success ? parsed.data : envSchema.parse({});

module.exports = {
  GEMINI_API_KEY: config.GEMINI_API_KEY,
  GEMINI_MODEL: config.GEMINI_MODEL || 'gemini-1.5-flash',
  GOOGLE_MAPS_SERVER_KEY: config.GOOGLE_MAPS_SERVER_KEY || config.GOOGLE_MAPS_API_KEY || '',
  PORT: parseInt(config.PORT || '8080', 10),
  FIREBASE_PROJECT_ID: config.FIREBASE_PROJECT_ID || 'aparajeet-das',
  hasGeminiKey: Boolean(config.GEMINI_API_KEY && config.GEMINI_API_KEY.trim()),
  hasGeminiModel: Boolean(config.GEMINI_MODEL && config.GEMINI_MODEL.trim()),
  hasGoogleKey: Boolean((config.GOOGLE_MAPS_SERVER_KEY || config.GOOGLE_MAPS_API_KEY || '').trim()),
  isTest: config.NODE_ENV === 'test',
};
