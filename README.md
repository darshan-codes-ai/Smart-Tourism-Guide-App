# 🌍 TourMate — Smart Tourism Guide App

<p align="center">
  <img src="docs/assets/tourmate-banner.png" alt="TourMate Banner">
</p>

<p align="center">
  <b>AI-Powered Smart Tourism Guide & Itinerary Planner</b>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-tech-stack">Tech Stack</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-getting-started">Getting Started</a> •
  <a href="#-firebase-setup">Firebase Setup</a> •
  <a href="#-performance--lighthouse">Performance & Lighthouse</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter">
  <img src="https://img.shields.io/badge/Dart-3.13.3-0175C2?logo=dart">
  <img src="https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase">
  <img src="https://img.shields.io/badge/OpenStreetMap-flutter__map-7EBC6F?logo=openstreetmap">
  <img src="https://img.shields.io/badge/Open--Meteo-Weather%20API-FFA726">
  <img src="https://img.shields.io/github/license/darshan-codes-ai/Smart-Tourism-Guide-App">
</p>

---

## ✨ Features

TourMate provides a comprehensive, end-to-end tourism experience across mobile and web:

* 🗺️ **Attraction Discovery**: Browse curated global destinations with categories, search filtering, distance calculations, and high-resolution photography.
* 📍 **Interactive Maps (OpenStreetMap)**: Free, open-source geospatial exploration powered by `flutter_map` and OpenStreetMap tile servers with user GPS location support.
* 🤖 **AI-Powered Travel Recommendations**: Smart suggestion engine filtering attractions based on user travel preferences, budget tiers, and activity types.
* 🧳 **Smart Trip Planner & Itinerary Generation**: Day-by-day travel itinerary builder with budget tracking, traveler counters, and day filter chips.
* ⭐ **Reviews & Ratings**: Authentic traveler ratings (1–5 stars) and detailed reviews backed by Firestore subcollections.
* ⛅ **Weather & Geocoding (Open-Meteo REST APIs)**: Real-time 7-day destination weather forecasts, temperature, precipitation chance, wind speed, and worldwide geocoding search.
* 👨‍💼 **Admin Dashboard**: Secure administrative portal to manage attractions, view metrics, and curate tourism content.
* 🛡️ **Role-Based Security**: Hardened Firestore rules validating user ownership on favorites, trips, and reviews, with strict administrative authorization on attraction catalogs.

---

## 🛠️ Tech Stack

* **Frontend**: [Flutter 3.47.4](https://flutter.dev) (Dart 3.13.3)
* **Backend & Authentication**: [Firebase Core](https://firebase.google.com), Firebase Auth, Cloud Firestore
* **Mapping**: [flutter_map 8.3.2](https://pub.dev/packages/flutter_map) + [latlong2](https://pub.dev/packages/latlong2) (OpenStreetMap tiles)
* **Weather & Geocoding**: [Open-Meteo REST APIs](https://open-meteo.com) (HTTP client with 15–30 min memory caching and request deduplication)
* **Navigation & State**: [go_router 18.0.1](https://pub.dev/packages/go_router)
* **Design & Typography**: Material Design 3, [google_fonts](https://pub.dev/packages/google_fonts)

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK 3.47+](https://docs.flutter.dev/get-started/install)
* [Dart SDK 3.13+](https://dart.dev/get-dart)
* Google Chrome (for web debugging and Lighthouse audits)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/darshan-codes-ai/Smart-Tourism-Guide-App.git
   cd Smart-Tourism-Guide-App
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify analyzer status**:
   ```bash
   flutter analyze
   ```

4. **Run the automated test suite**:
   ```bash
   flutter test
   ```

5. **Run locally on Chrome**:
   ```bash
   flutter run -d chrome
   ```

---

## 🔥 Firebase Setup

TourMate connects to Cloud Firestore and Firebase Authentication.

### Configuration

Firebase options are configured in `lib/firebase_options.dart`. For a new deployment:

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password** and **Google Sign-In** under Authentication.
3. Enable **Cloud Firestore** in production mode.
4. Deploy the project security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Security Rules Highlights (`firestore.rules`)

* `/users/{uid}`: Authenticated users can only read/update their own profile. Privilege escalation to `admin` is blocked server-side.
* `/users/{uid}/favorites/{attractionId}`: User-isolated read and write permissions.
* `/users/{uid}/trips/{tripId}`: Strictly restricted to the trip owner (`userId == auth.uid`).
* `/attractions/{attractionId}`: Publicly readable; create, update, and delete require verified `isAdmin()` claims.
* `/attractions/{attractionId}/reviews/{reviewId}`: Publicly readable; writes require authenticated user identity matching review author.

---

## ⚡ Performance & Lighthouse

TourMate includes custom web bootstrapping optimizations designed for high Lighthouse scores:

* **Instant HTML/CSS Shell**: Provides sub-second First Contentful Paint (0.2s desktop / 0.8s mobile) with branded styling while Flutter initializes.
* **Deprecation-Free Bootstrap**: Clean `web/flutter_bootstrap.js` eliminates deprecated service-worker and V8 warnings.
* **SEO & Metadata**: Complete OpenGraph, Twitter Cards, mobile viewport, and semantic accessibility tags.
* **Compilation Options**:
  * Standard Release Build: `flutter build web --release`
  * Multi-target WASM Build: `flutter build web --wasm` (WasmGC + Skwasm with CanvasKit fallback)

### Production Serving Recommendations

When deploying to Firebase Hosting or a CDN:
* Serve static assets with `Cache-Control: public, max-age=31536000, immutable`.
* For WASM multithreading, include:
  * `Cross-Origin-Opener-Policy: same-origin`
  * `Cross-Origin-Embedder-Policy: credentialless`
