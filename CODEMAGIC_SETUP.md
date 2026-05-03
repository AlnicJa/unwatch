# Codemagic Setup Guide
### Build iOS + Android on Windows — No Mac Required

---

## How This Works

```
Your Windows PC  →  GitHub  →  Codemagic Cloud  →  App Store + Play Store
  (write code)      (push)      (Mac build server)     (automatic upload)
```

You write code on Windows. Codemagic builds iOS on their Mac servers in the cloud.
**Free tier: 500 build minutes/month** (enough for ~10 full builds).

---

## Step 1 — GitHub Setup

1. Create a free account at **github.com**
2. Create a new **private repository** called `unwatch`
3. In the unwatch project folder, open PowerShell:

```powershell
git init
git add .
git commit -m "Initial commit — Unwatch app"
git remote add origin https://github.com/YOUR_USERNAME/unwatch.git
git push -u origin main
```

---

## Step 2 — Codemagic Account

1. Go to **codemagic.io** → Sign up with GitHub
2. Click **"Add application"**
3. Select your `unwatch` repository
4. Choose **"Flutter App"** → it will detect `codemagic.yaml` automatically

---

## Step 3 — Apple Developer Account (iOS)

Required to ship to App Store. Cost: **$99/year** at developer.apple.com.

### 3a. Create an App Store Connect API Key
1. Go to **appstoreconnect.apple.com** → Users and Access → Integrations → Keys
2. Click **+** → Name: "Codemagic" → Role: "App Manager"
3. Download the `.p8` key file (you can only download once!)
4. Note the **Key ID** and **Issuer ID**

### 3b. Register your Bundle ID
1. Go to **developer.apple.com** → Certificates, IDs & Profiles → Identifiers
2. Click **+** → App IDs → App
3. Bundle ID: `app.unwatch.unwatch` (or your own, matching `codemagic.yaml`)
4. Enable: **Push Notifications**, **Background Modes**
5. Click Continue → Register

### 3c. Create App in App Store Connect
1. Go to **appstoreconnect.apple.com** → My Apps → **+**
2. Platform: iOS, Name: Unwatch, Bundle ID: `app.unwatch.unwatch`
3. Primary Language: English

### 3d. Add secrets to Codemagic
In Codemagic → your app → **Environment variables** tab:

| Variable name | Value | Group | Secure |
|---|---|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | From Step 3a | ios_creds | ✓ |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | From Step 3a (Key ID) | ios_creds | ✓ |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of `.p8` file | ios_creds | ✓ |
| `CERTIFICATE_PRIVATE_KEY` | Your signing key (see below) | ios_creds | ✓ |

### 3e. Generate a signing certificate (on any machine via Codemagic)
In Codemagic → Teams → your team → **Code signing identities**:
- Click **"Generate certificate"** → Distribution → Download
- Codemagic handles everything else automatically!

---

## Step 4 — Android Signing

### 4a. Generate keystore (run this on Windows in the project folder)
```powershell
.\setup_windows.ps1   # This does it automatically
# OR manually:
keytool -genkey -v -keystore android/app/unwatch.keystore -alias unwatch -keyalg RSA -keysize 2048 -validity 10000
```

⚠️ **BACK UP `unwatch.keystore` immediately** — if you lose it, you can never update your Play Store app.

### 4b. Upload keystore to Codemagic
In Codemagic → your app → **Code signing** tab → Android:
1. Upload `android/app/unwatch.keystore`
2. Enter your alias (`unwatch`) and passwords
3. Codemagic names it `unwatch_keystore` (matching `codemagic.yaml`)

### 4c. Google Play Console
1. Create account at **play.google.com/console** ($25 one-time)
2. Create app → Enter details → App category: Travel & Local
3. Go to **Setup → API access** → Link to Google Cloud project
4. Create service account → Download JSON credentials
5. In Codemagic environment variables, add:

| Variable | Value | Secure |
|---|---|---|
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | JSON file contents | ✓ |

---

## Step 5 — First Build

### Trigger a build:
```powershell
git tag v1.0.0
git push origin v1.0.0
```

This triggers both `ios-release` and `android-release` workflows automatically.

### Monitor builds:
- Go to **codemagic.io** → your app → Builds
- iOS build: ~20-30 minutes
- Android build: ~10-15 minutes
- You'll get an email when done

---

## Step 6 — App Store Submission

### iOS:
1. Codemagic automatically uploads to **TestFlight** (internal testing)
2. In App Store Connect → TestFlight → invite yourself as tester → test it
3. When ready: App Store Connect → My Apps → Unwatch → Prepare for Submission
4. Add screenshots (required sizes: 6.7", 6.5", 5.5")
5. Write description, keywords, privacy policy URL
6. Submit for Review (~24-48 hours)

**Privacy policy** (required — you can use a free generator):
- Go to **app-privacy-policy-generator.firebaseapp.com**
- Host it on GitHub Pages (free)

### Android:
1. Codemagic uploads to Play Store **Internal Testing** track automatically
2. In Play Console → Release → Testing → Internal Testing → Manage testers
3. Add yourself as tester → download from Play Store
4. When ready: Promote to Production

---

## Build Workflow Summary

```
Every push to any branch  →  dev-check (analyze + test, ~5 min)
git tag v1.x.x            →  ios-release + android-release (~30 min total)
                          →  Auto-uploaded to TestFlight + Play Internal
```

---

## Costs Summary

| Service | Cost |
|---|---|
| Codemagic (500 min/month) | **Free** |
| GitHub private repo | **Free** |
| Apple Developer Program | $99/year |
| Google Play Console | $25 one-time |
| Map tiles (CARTO) | **Free** |
| Routing (OSRM) | **Free** |
| Camera data (OSM Overpass) | **Free** |
| Geocoding (Nominatim) | **Free** |

**Total Year 1: ~$124**

---

## Troubleshooting

**Build fails: "No provisioning profile"**
→ In Codemagic → Code signing → ensure iOS Distribution certificate is uploaded and bundle ID matches

**Android build fails: "Keystore not found"**
→ In Codemagic → Code signing → verify keystore alias and passwords match what you set

**flutter pub get fails**
→ Check `pubspec.yaml` for typos in dependency versions

**App rejected by Apple**
→ Most common reason: missing privacy policy URL. Add one before submitting.

---

## Useful Commands (Windows PowerShell)

```powershell
# Run on Android emulator
flutter run

# Build debug APK (install directly on Android phone)
flutter build apk --debug
# File at: build\app\outputs\flutter-apk\app-debug.apk

# Check everything is set up correctly
flutter doctor -v

# Update Flutter
flutter upgrade

# Clean build cache if something is broken
flutter clean
flutter pub get
```
