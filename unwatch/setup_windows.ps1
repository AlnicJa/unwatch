# Unwatch — Windows Developer Setup Script
# Run in PowerShell as Administrator:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\setup_windows.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  UNWATCH — Windows Setup" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check prerequisites ────────────────────────────────────────────────────

function Check-Command($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Check-Command "git")) {
    Write-Host "  [!] Git not found. Download from https://git-scm.com/download/win" -ForegroundColor Red
    Write-Host "      Install it, restart PowerShell, then re-run this script."
    exit 1
}
Write-Host "  [✓] Git found" -ForegroundColor Green

if (-not (Check-Command "java")) {
    Write-Host "  [!] Java not found." -ForegroundColor Yellow
    Write-Host "      Download JDK 17 from: https://adoptium.net/temurin/releases/?version=17"
    Write-Host "      Install it, restart PowerShell, then re-run this script."
    exit 1
}
Write-Host "  [✓] Java found" -ForegroundColor Green

# ── 2. Install Flutter ────────────────────────────────────────────────────────

$flutterDir = "$env:USERPROFILE\flutter"

if (-not (Test-Path "$flutterDir\bin\flutter.bat")) {
    Write-Host ""
    Write-Host "Installing Flutter SDK..." -ForegroundColor Yellow
    
    $flutterZip = "$env:TEMP\flutter.zip"
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.0-stable.zip"
    
    Write-Host "  Downloading Flutter (~700MB)..."
    Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip -UseBasicParsing
    
    Write-Host "  Extracting..."
    Expand-Archive -Path $flutterZip -DestinationPath "$env:USERPROFILE" -Force
    Remove-Item $flutterZip
    
    Write-Host "  [✓] Flutter extracted to $flutterDir" -ForegroundColor Green
} else {
    Write-Host "  [✓] Flutter already installed at $flutterDir" -ForegroundColor Green
}

# Add Flutter to PATH for this session
$env:PATH = "$flutterDir\bin;$env:PATH"

# Add permanently if not already there
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*flutter\bin*") {
    [System.Environment]::SetEnvironmentVariable(
        "PATH",
        "$flutterDir\bin;$userPath",
        "User"
    )
    Write-Host "  [✓] Added Flutter to system PATH" -ForegroundColor Green
}

# ── 3. Accept Android licenses ─────────────────────────────────────────────────

Write-Host ""
Write-Host "Accepting Android SDK licenses..." -ForegroundColor Yellow
Write-Host "  (Type 'y' and press Enter for each prompt)"
Write-Host ""

try {
    & flutter doctor --android-licenses
} catch {
    Write-Host "  [!] License acceptance failed — run manually: flutter doctor --android-licenses" -ForegroundColor Yellow
}

# ── 4. Get project dependencies ───────────────────────────────────────────────

Write-Host ""
Write-Host "Getting Flutter packages..." -ForegroundColor Yellow
& flutter pub get
Write-Host "  [✓] Packages installed" -ForegroundColor Green

# ── 5. Run flutter doctor ─────────────────────────────────────────────────────

Write-Host ""
Write-Host "Running Flutter doctor..." -ForegroundColor Yellow
& flutter doctor -v

# ── 6. Generate Android keystore ──────────────────────────────────────────────

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  ANDROID KEYSTORE SETUP" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$keystorePath = ".\android\app\unwatch.keystore"

if (-not (Test-Path $keystorePath)) {
    Write-Host "Generating Android release keystore..." -ForegroundColor Yellow
    Write-Host "  You will be prompted for your name, org, and passwords."
    Write-Host "  IMPORTANT: Save these passwords — you need them forever to update the app!"
    Write-Host ""
    
    & keytool -genkey -v `
        -keystore $keystorePath `
        -alias unwatch `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000
    
    Write-Host ""
    Write-Host "  [✓] Keystore saved to $keystorePath" -ForegroundColor Green
    Write-Host "  [!] BACK THIS FILE UP — losing it means you cannot update your app!" -ForegroundColor Red
    
    # Create key.properties template
    $keyProps = @"
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=unwatch
storeFile=unwatch.keystore
"@
    $keyProps | Out-File -FilePath ".\android\key.properties" -Encoding UTF8
    Write-Host "  [✓] Created android\key.properties — fill in your passwords!" -ForegroundColor Green
} else {
    Write-Host "  [✓] Keystore already exists at $keystorePath" -ForegroundColor Green
}

# ── 7. Instructions summary ───────────────────────────────────────────────────

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Open Android Studio and install an Android emulator" -ForegroundColor White
Write-Host "     (SDK Manager → AVD Manager → Create Virtual Device)"
Write-Host ""
Write-Host "  2. Run the app locally (Android):" -ForegroundColor White
Write-Host "     flutter run" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. Push to GitHub and set up Codemagic for iOS + Android releases:" -ForegroundColor White
Write-Host "     See CODEMAGIC_SETUP.md for step-by-step instructions" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. Build Android APK for manual testing:" -ForegroundColor White
Write-Host "     flutter build apk --debug" -ForegroundColor Yellow
Write-Host ""
