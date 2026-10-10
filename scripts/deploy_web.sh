#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Travel Buddy - Production Flutter Web Deploy Script
# ==============================================================================

echo "📦 Running production build first..."
./scripts/build_web.sh

echo "🌐 Deploying to Hosting..."
# Example: Firebase Hosting / Cloudflare Pages / Netlify / Vercel
if command -v firebase &> /dev/null; then
  echo "Deploying via Firebase Hosting..."
  firebase deploy --only hosting
elif command -v npx &> /dev/null; then
  echo "Build ready in build/web/ - Deploy with your provider, e.g.:"
  echo "  - Cloudflare Pages: npx wrangler pages deploy build/web"
  echo "  - Netlify:         npx netlify deploy --prod --dir=build/web"
  echo "  - Vercel:          npx vercel build/web --prod"
else
  echo "Done! Upload 'build/web' directory to your static web host."
fi
