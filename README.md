# Travel Buddy 🇮🇳 
### AI Price Intelligence & Tourist Trap Protection

> **"Tourists get overcharged everywhere. Travel Buddy tells you the fair price before you pay."**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Gemini 1.5](https://img.shields.io/badge/Gemini-1.5%20Flash-4285F4?logo=google)](https://ai.google.dev)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-Places%20&%20Routes-34A853?logo=googlemaps)](https://developers.google.com/maps)
[![Tests](https://img.shields.io/badge/Tests-29%20Passing-success.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)

---

## 🧭 The Problem
Travelers and tourists in India regularly face excessive markups (300% to 500%), aggressive touts, fake "monument closed" detours, commission-driven gem/textile shop diversions, and opaque street pricing. Without verified local rate cards, tourists have no way to know whether a quoted price is reasonable.

**Travel Buddy** solves this before money changes hands. Enter a quote or use live GPS tracking to get an instant verdict: **Fair** (green), **Suspicious** (amber), or **High Risk** (red), complete with a realistic counter-offer and negotiation phrases in local vernacular.

---

## 🏗️ AI Price Intelligence Architecture

```
                                  [ User Input ]
             Service Type (Auto/Taxi/Guide/Meal/Stay) | Quoted Price (₹) | Location
                                        │
                                        ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │                       4-Layer Intelligence Matrix                      │
    ├───────────────────┬───────────────────┬────────────────┬───────────────┤
    │  1. Official RTO  │   2. Community    │3. Tourist Trap │  4. Location  │
    │     Tariffs       │    Benchmarks     │   Database     │  Intelligence │
    │ (Base+Km+Min+Time)│ (Recency weights, │ (Geo-fenced,   │(Price Anomaly │
    │                   │ 10% outlier clip) │ Severities 1-3)│ Zones & Index)│
    └─────────┬─────────┴─────────┬─────────┴────────┬───────┴───────┬───────┘
              │                   │                  │               │
              └───────────────────┼──────────────────┼───────────────┘
                                  ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │                 Deterministic Pricing Engine (Scoring 0-100)           │
    │  • Price Score (0-60) + Location Anomaly (0-20) + Trap Risk (0-20)     │
    │  • Overrides: Quoted ≤ Official Max cannot exceed Suspicious           │
    │  • Overrides: Quoted > 1.5x Official Max forced to High Risk           │
    │  • Counter-offer = Fair Max (with Romanized bargaining phrase)         │
    └───────────────────────────────────┬────────────────────────────────────┘
                                        │
                                        ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │                      Verdict & Result Interface                        │
    │  🟢 Fair (0-29)   │   🟡 Suspicious (30-59)   │   🔴 High Risk (60-100)│
    └───────────────────────────────────┬────────────────────────────────────┘
                                        │
                                        ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │                Gemini 1.5 Serverless Proxy (/explain, /agent)          │
    │  • Secure backend proxy (never exposes GEMINI_API_KEY to client)       │
    │  • Rate limit (20 req/min/IP), 8s timeout, local rule fallback         │
    │  • Cultural context, itemized cost breakdown, Ask Buddy Guide Agent    │
    └────────────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Important Notice: Prototype Sample Tariffs
> **Disclaimer on Official Tariffs:**
> The official tariffs, rate cards, and monument fees included in this prototype (`assets/data/tariffs.json`) are **sample / unverified benchmark records** compiled for demonstration and hackathon testing purposes.
>
> In the production roadmap:
> 1. Rate cards will sync directly with state Regional Transport Offices (RTO) and Ministry of Tourism gazettes.
> 2. Verified tariff submissions will be accepted through our RTO Data Portal.
> 3. Whenever unverified sample data is referenced, the app clearly displays the **"Sample data"** and **"as of <date>"** indicators.

---

## 🌟 Hero Features

### 1. ⚡ "Check a Price Before You Pay" (Hero Feature)
Prominently located at the top of Home, in every Place Guide, and inside Ride Mode:
* **8 Adaptive Service Types**: Auto-rickshaws, Taxis, Bike Cabs, Tour Guides, Restaurant Meals, Hotel Rooms, Entry Tickets, and Custom Services.
* **Google Places Autocomplete**: Real-time pickup & destination autocomplete with traffic-aware distance and duration computation via Google Routes API.
* **7-Section Result Breakdown**:
  1. **Verdict Banner**: Fair (🟢), Suspicious (🟡), or High Risk (🔴) with risk score.
  2. **Risk Gauge**: 0–100 calibrated risk gauge with confidence indicator.
  3. **Fair Price Range Bar**: Visual range slider pinning the quoted price against `Fair Min` and `Fair Max`.
  4. **Multi-Source Transparency**: Side-by-side RTO tariff vs. Community benchmark vs. Mobility model.
  5. **Gemini 1.5 Explanation**: Shimmer-loaded cost breakdown, regional cultural context, and one-tap copyable counter-offer phrase.
  6. **Nearby Tourist Trap Alerts**: Immediate warnings if the trip starts or ends near an active overcharging trap.
  7. **One-Tap Actions**: Report this price, counter-offer, or consult Ask Buddy.

### 2. 🚖 Real-Time Ride Mode Meter
* Live GPS fare counter calculating fair price kilometer by kilometer as you travel.
* Compares running meter price against the quoted or street rate in real time.
* Audio and visual alert if the driver deviates or markup exceeds threshold.

### 3. 🚨 Tourist Trap Database
* Searchable repository of 25+ geo-fenced tourist trap patterns categorized into:
  * `touting_commission` (gem shops, fake marble emporiums)
  * `fake_tickets` (bogus entry counters outside monuments)
  * `closed_monument_scam` (driver claims monument is shut for prayer/festival)
  * `meter_refusal` (claiming meter is broken or charging per-person)
* Severity ratings (Level 1 Info to Level 3 Critical Danger).
* Actionable avoidance tips: exact walking paths, prepaid booth locations, and helpline numbers.

### 4. 🗺️ Location Intelligence & Safe Zone Heatmap
* Anomaly pricing indices identifying high-risk zones (e.g., Jaipur Junction price index: 1.45x).
* Interactive Area Insight sheets with safer alternatives (e.g., "Prepaid Auto Booth at Platform 1 exit").

### 5. 🤖 Ask Buddy: AI Guide & Price Guardian
* Conversational AI assistant powered by Gemini 1.5 Flash via our secure serverless proxy.
* Built-in client-side function calling tools:
  * `checkPrice`: evaluate quotes for any vehicle or service.
  * `view_traps`: open relevant tourist trap warnings.
  * `start_ride`: trigger real-time GPS ride meter.
  * `show_map`: focus map coordinates on safe pickup points.
* Inline actionable cards embedded directly inside chat bubbles.

---

## 🔑 Setup & Configuration

### 1. Google Maps & Places Integration
The Flutter client reads the Google Maps API key at compile time using `--dart-define`. **No API keys are committed to source control.**

To run with your Google Maps API Key:
```bash
flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY
```

> **Fallback Guarantee**: If `GOOGLE_MAPS_API_KEY` is not provided or quota limits are exceeded, the app cleanly falls back to offline seed places and a Haversine curvature formula ($\text{Distance} \times 1.3$) with a low-confidence badge.

---

### 2. Serverless Security Proxy & API Keys Architecture
To keep all credentials strictly confidential and safe from reverse engineering, the Flutter mobile and web clients contain **zero** Google Maps or Gemini API keys. All calls are routed through the proxy in `proxy/`.

#### Google Cloud Key Restrictions
Restrict your `GOOGLE_MAPS_SERVER_KEY` in the Google Cloud Console to **only**:
1. **Places API (New)**
2. **Routes API**
3. **Geocoding API**
Apply IP/server restrictions or HTTP referrers corresponding to your proxy deployment.

#### ⚠️ Key Rotation & Secret Scanning Notice
* **Rotate Exposed Keys**: If any Google Maps or Gemini API key was ever previously committed or shared, rotate and delete it immediately in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) and [Google AI Studio](https://aistudio.google.com/).
* **Gitleaks Pre-commit Scanning**: Configured in `.gitleaks.toml` to prevent accidental credential leakage in commits. Run:
  ```bash
  gitleaks detect --source . -v
  ```

#### Local Proxy Setup:
```bash
cd proxy
cp .env.example .env
# Edit .env and paste your GOOGLE_MAPS_SERVER_KEY and GEMINI_API_KEY
npm start
```
The proxy runs on port `8080` with strict CORS origin verification, 8 KB body limits, per-IP rate limits, circuit breaker daily caps, and SSRF-protected link resolution.

#### Deploying the Proxy to Production:
* **Google Cloud Run**:
  ```bash
  cd proxy
  gcloud run deploy travel-buddy-proxy --source . \
    --set-env-vars GOOGLE_MAPS_SERVER_KEY=YOUR_KEY,GEMINI_API_KEY=YOUR_KEY,ALLOWED_ORIGINS=https://your-app.web.app \
    --allow-unauthenticated
  ```
* **Render / Vercel / Railway / Firebase Cloud Functions**:
  Deploy the `proxy/` directory and configure environment variables in your cloud dashboard.
* Build the Flutter client configured to your deployed proxy:
  ```bash
  flutter build web --release --dart-define=GOOGLE_MAPS_PROXY_URL=https://your-proxy.com --dart-define=GEMINI_PROXY_URL=https://your-proxy.com
  ```

---

## 🎬 6-Scenario Hackathon Judging Demo Script

Follow this step-by-step walkthrough to test all features:

### Scenario 1: Jaipur Auto Overcharge (High Risk Trap)
1. Tap **"Check a Price Before You Pay"** at the top of the Home screen.
2. Select **Auto-rickshaw**. Enter **₹250** quoted price.
3. Tap the preset **`Jaipur Auto ₹250 (Trap)`** or enter Pickup: `Jaipur Junction`, Drop: `Hawa Mahal` (~4.2 km).
4. Tap **Check Fair Price Verdict**.
5. **Observed Result**:
   * Verdict: 🔴 **High Risk** (Risk Score ~78/100).
   * Fair Range: **₹90 - ₹120**.
   * Markup: **+₹130 (108% overcharge)**.
   * Traps Near Here: Alerts traveler about the active *"Jaipur Junction Auto Syndicate & Gem Shop Detour"* trap.
   * Suggested Counter-Offer: **₹110** with local Hindi phrase: *"Bhaiya, ₹110 doonga, chalna hai toh bolo"*.

### Scenario 2: Monument Guide Scam (Suspicious / High Risk)
1. In the Checker, tap preset **`Amer Guide ₹2200 (Scam)`** (Service: Guide, Duration: 2 Hours, Quoted: ₹2200).
2. Tap **Check Fair Price Verdict**.
3. **Observed Result**:
   * Verdict: 🔴 **High Risk** (Official Department of Tourism approved guide rate for 2 hours is ₹600 - ₹800).
   * Notice alerts user to check for official Rajasthan Tourism badge and government ID before hiring.

### Scenario 3: Fair Street Price
1. In the Checker, tap preset **`Delhi Auto ₹60 (Fair)`** (Pickup: NDLS Station, Drop: Connaught Place, Quoted: ₹60).
2. Tap **Check Fair Price Verdict**.
3. **Observed Result**:
   * Verdict: 🟢 **Fair** (Risk Score ~12/100).
   * Green banner: *"This price matches local standards. Safe to accept!"*

### Scenario 4: Tourist Trap Database Browser
1. In the bottom navigation, tap **Scam Alerts** / **Tourist Trap DB**.
2. Filter by severity: **Critical (Red)**, **High**, or **Moderate**.
3. Search for *"gem"* or *"station"*. Tap on **Jaipur Railway Station Syndicate**.
4. Read the detailed avoid tip, safest alternatives, and report timeline.

### Scenario 5: Submitting a Community Price Report
1. On any result screen or from the Community Hub, tap **"Report Overcharge"**.
2. Fill in the quoted ₹ amount, service type, and whether the driver was aggressive.
3. Submit the report. The benchmark counter updates and is immediately integrated into local recency-weighted percentiles.

### Scenario 6: Conversational Assistance with "Ask Buddy"
1. Tap the floating **Ask Buddy** button at the bottom right of any screen.
2. Type or select: *"Is ₹250 auto fair here?"*
3. Buddy provides a friendly 2-sentence response detailing official base fares and displays interactive action cards: **[Check Auto Price]** and **[Start Live Ride Meter]**.
4. Tap **[Start Live Ride Meter]** to immediately transition to real-time Ride Mode!

---

## 🧪 Testing & Validation

Run the test suite:
```bash
flutter test
```
**Results**:
* `29/29` unit tests passing across pricing engine calculations, outlier trimming, scoring overrides, Gemini proxy models, and Google routes models.
* `flutter analyze` reports **0 issues** across the entire workspace.

---

## 💻 Tech Stack
* **Client**: Flutter 3.x (Web, iOS, Android)
* **Architecture**: Riverpod + Clean Repository Pattern
* **Maps**: Flutter Map (OpenStreetMap) + Google Places (New) & Routes API
* **AI Engine**: Google Gemini 1.5 Flash via Node.js Serverless Proxy
* **Styling**: Tailored Material 3 Design System (strictly modular, all UI files <300 lines)

---

---

## 🔒 Privacy & Data Protection (India's DPDP Act 2023 Alignment)

Travel Buddy adheres strictly to the principles of India's Digital Personal Data Protection (DPDP) Act 2023:

1. **Principle of Purpose Limitation**: Data collected from users is strictly used to compute local price benchmarks and alert travellers against tourist rip-offs. Never sold or utilized for profiling.
2. **Data Minimization**:
   - Zero collection of names, email addresses, or phone numbers in community reports.
   - Anonymous identifiers only, used exclusively for rate limiting (max 20 submissions/day) and anti-poisoning duplicate prevention.
   - Precise GPS coordinates remain on-device; coordinates attached to submitted reports are rounded to ~100m.
   - Uploaded photos have EXIF metadata and GPS tags stripped on the client.
3. **Right to Erasure (Clear My Data)**: Users can permanently wipe all locally cached data, search history, saved destinations, and custom settings with a single tap on the **"Clear My Data"** button in their Profile.
4. **Defamation Safety & Legal Redress**: Individual drivers or businesses are never named from a single unverified report. All affected entities have access to an in-app **Takedown & Appeal Request** procedure reviewed within 24-48 hours.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

# trevel-buddy
