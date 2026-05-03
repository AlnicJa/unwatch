# Unwatch 👁️

**See what's watching you.** Unwatch is a cross-platform Flutter app (iOS + Android) that shows Flock Safety ALPR cameras, red light cameras, and speed cameras on a live map — with proximity alerts and camera-avoiding route planning.

---

## Features

| Feature | Description |
|---|---|
| 🗺️ **Live camera map** | Dark map with color-coded markers — Flock/ALPR (amber), red light (red), speed (blue) |
| 📍 **Proximity alerts** | Push notifications at 150m and 60m from any camera |
| 🛣️ **Camera-avoiding routes** | Route planning via OSRM that injects waypoints to avoid cameras |
| 🔍 **Destination search** | Geocoded search via Nominatim (OpenStreetMap, no API key) |
| 📡 **Live data** | Camera data from OpenStreetMap Overpass API (same as deflock.me) |
| 🔒 **No accounts, no tracking** | Zero telemetry — all data stays on device |

---

## Tech Stack

- **Framework:** Flutter 3.x (Dart)
- **State management:** Riverpod
- **Maps:** flutter_map + CARTO dark tiles
- **Camera data:** OpenStreetMap Overpass API
- **Routing:** OSRM public API (free, no key)
- **Geocoding:** Nominatim (free, no key)
- **Notifications:** flutter_local_notifications

---

## Setup & Build

### Prerequisites

```bash
# Install Flutter SDK (3.13+)
# https://docs.flutter.dev/get-started/install

flutter doctor  # verify setup
```

### 1. Clone & install

```bash
git clone <your-repo>
cd unwatch
flutter pub get
```

### 2. Run on simulator/device

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# List available devices
flutter devices
```

### 3. Build for release

#### iOS (App Store)

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode:
1. Set your **Team** (Apple Developer account — $99/year at developer.apple.com)
2. Set **Bundle Identifier** — e.g. `com.yourname.unwatch`
3. Archive → Distribute App → App Store Connect

#### Android (Play Store)

```bash
# Generate keystore (first time only)
keytool -genkey -v -keystore unwatch.jks -keyalg RSA -keysize 2048 -validity 10000 -alias unwatch

# Build AAB
flutter build appbundle --release
```

Upload the `.aab` file to Google Play Console.

---

## App Store Submission Checklist

### Apple App Store
- [ ] Apple Developer account ($99/year)
- [ ] Bundle ID registered in App Store Connect
- [ ] App icons at all required sizes (use `flutter_launcher_icons`)
- [ ] Screenshots for iPhone 6.7", 6.5", 5.5"
- [ ] Privacy policy URL (required — see Privacy section below)
- [ ] App Store description
- [ ] Review notes explaining data sources

**Key App Store review note:** All camera data is sourced from OpenStreetMap, a public dataset. This app does not collect, store, or share any user data. Location is used only on-device for proximity alerts.

**Category:** Navigation  
**Age Rating:** 4+  
**Keywords:** privacy, surveillance, ALPR, Flock Safety, camera map, navigation

### Google Play Store
- [ ] Google Play Console account ($25 one-time)
- [ ] Keystore file secured and backed up
- [ ] Feature graphic (1024×500px)
- [ ] Screenshots (min 2)
- [ ] Privacy policy URL
- [ ] Data safety form (location — used only on-device)

---

## Configuration

### Change search radius defaults
Edit `lib/widgets/filter_bar.dart`:
```dart
final _radii = [4.0, 8.0, 16.0]; // km
final _labels = ['2.5 mi', '5 mi', '10 mi'];
```

### Change proximity alert distances
Edit `lib/services/location_service.dart`:
```dart
static const _proximityAlertRadius = 150.0; // meters — first alert
static const _highAlertRadius = 60.0;        // meters — urgent alert
```

### Change camera avoidance buffer
Edit `lib/services/routing_service.dart`:
```dart
double avoidanceRadius = 80.0, // meters from route line
```

### Add your own map tile provider
Replace the tile URL in `lib/screens/map_screen.dart`:
```dart
urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
```
Options: Mapbox (free tier), Stadia Maps, Thunderforest, self-hosted.

---

## Data Sources

| Source | URL | License |
|---|---|---|
| Flock/ALPR cameras | OpenStreetMap via Overpass API | ODbL |
| Red light / speed cameras | OpenStreetMap via Overpass API | ODbL |
| Routing | OSRM public instance | Various |
| Geocoding | Nominatim | ODbL |
| Base map tiles | CARTO Dark Matter | CC BY 3.0 |

**Adding more cameras:** Visit [openstreetmap.org](https://openstreetmap.org) or use the [DeFlock app](https://deflock.me) to contribute camera locations.

---

## Privacy Policy Template

> Unwatch does not collect, transmit, or sell any personal data. Location data is processed entirely on your device and is never sent to any server operated by Unwatch. Camera data is fetched from the OpenStreetMap public API (overpass-api.de). No analytics, no crash reporting, no accounts.

---

## Roadmap (v2)

- [ ] Turn-by-turn navigation voice guidance
- [ ] GPX export of camera locations
- [ ] Offline camera caching (SQLite)
- [ ] Community reporting (contribute to OSM)
- [ ] Heatmap density overlay
- [ ] CarPlay / Android Auto support
- [ ] Widget for iOS lock screen / home screen

---

## Legal

This app uses publicly available data from OpenStreetMap. Camera locations on public streets are increasingly considered public records. A Washington court ruled Flock camera data are public records (Nov 2025).

Intended for: privacy awareness, journalism, research, and public education.
Not intended for: evasion of law enforcement, illegal activities, or vandalism.
