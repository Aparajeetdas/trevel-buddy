# Travel Buddy - Serverless Google Proxy

A high-performance, secure backend proxy for **Google Places (New)**, **Google Routes**, **Google Geocoding**, and **Google Gemini 1.5**.

## Key Architecture & Security
- **No Keys in App**: The Flutter web and mobile app contains zero Google API keys.
- **Single Restricted Server Key**: The proxy holds one backend key restricted in Google Cloud Console to:
  1. Places API (New)
  2. Routes API
  3. Geocoding API
- **Strict Controls**:
  - Google Field Masks applied to every Places and Routes call to minimize egress and API costs.
  - 8-second timeout on all upstream calls via `AbortController`.
  - Rate limiting (30 requests/minute per client IP) to block abuse.
  - Safe Link Resolution: Redirect-following is strictly restricted to allowlisted Google Maps domains (`maps.app.goo.gl`, `goo.gl`, `google.com`, `maps.google.com`) to prevent SSRF vulnerabilities.
  - Origin restriction through `CORS_ORIGIN`.

## Endpoints
- `POST /places/autocomplete`: Places API (New) Autocomplete with city-bias circle and session tokens.
- `POST /places/details`: Places API (New) Details with field masks (`displayName`, `formattedAddress`, `rating`, `photos`, etc.).
- `POST /places/nearby`: Places API (New) Search Nearby by category, coordinates and radius.
- `POST /geocode`: Reverse and forward geocoding with 8-second timeout.
- `POST /route`: Google Routes API `computeRoutes` with traffic-aware duration, polyline, and 1.3x straight-line fallback.
- `POST /resolve-link`: Safe short-link resolver that extracts place/coordinates from Google Maps URLs and queries Places API Text Search.
- `POST /explain`: Gemini 1.5 Flash fare explanations with deterministic local fallback.
- `POST /agent`: AI guide assistant with function actions (`open_in_maps`, `check_price`, `view_traps`).
- `GET /health`: Service health check.

## Setup & Local Run

```bash
cd proxy
cp .env.example .env
# Set GOOGLE_MAPS_SERVER_KEY and GEMINI_API_KEY in .env
node server.js
```

Default port: `8080`.

## Production Deployment Steps

### 1. Google Cloud Run (Recommended)
```bash
cd proxy
gcloud run deploy travel-buddy-proxy \
  --source . \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_MAPS_SERVER_KEY="YOUR_KEY",GEMINI_API_KEY="YOUR_KEY",CORS_ORIGIN="https://your-domain.com"
```

### 2. Render / Railway / Vercel
1. Create a Web Service pointing to the repository.
2. Set Root Directory to `proxy`.
3. Set Build Command to `npm install` and Start Command to `node server.js`.
4. Add Environment Variables:
   - `GOOGLE_MAPS_SERVER_KEY`: Your server key.
   - `GEMINI_API_KEY`: Your Gemini key.
   - `CORS_ORIGIN`: Your frontend domain (or `*`).
   - `PORT`: `8080` (or provider's default).
