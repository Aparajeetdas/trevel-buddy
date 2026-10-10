#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Travel Buddy - Production Flutter Web Build Script
# ==============================================================================

BASE_HREF="${BASE_HREF:-/}"
API_URL="${API_BASE_URL:-https://api.travelbuddy.local}"

echo "🚀 Building Flutter Web (Release)..."
echo "   Base href:        $BASE_HREF"
echo "   Tree Shake Icons: ENABLED"
echo "   PWA Strategy:     none (prevents stale service worker hangs)"

flutter build web \
  --release \
  --base-href="$BASE_HREF" \
  --tree-shake-icons \
  --pwa-strategy=none \
  --dart-define=API_BASE_URL="$API_URL"

echo "✅ Web build generated successfully in build/web/"
