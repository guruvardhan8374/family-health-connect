# Family Health Connect - Android APK Compilation Automator
# Run this script inside the 'mobile' directory or project root.

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Family Health Connect - Building Android APK" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$RootPath = Resolve-Path ".."
$FrontendPath = Join-Path $RootPath "frontend"
$AndroidPath = Join-Path $FrontendPath "android"

# Step 1: Build the React Application
Write-Host "`n[1/4] Building React Frontend..." -ForegroundColor Yellow
Push-Location $FrontendPath
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: React frontend build failed!" -ForegroundColor Red
    Pop-Location
    Exit 1
}
Pop-Location

# Step 2: Sync Web Assets to Capacitor Android Codebase
Write-Host "`n[2/4] Syncing web assets with Capacitor Android..." -ForegroundColor Yellow
Push-Location $FrontendPath
npx cap sync android
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Capacitor sync failed!" -ForegroundColor Red
    Pop-Location
    Exit 1
}
Pop-Location

# Step 3: Run Gradle Build to Compile APK
Write-Host "`n[3/4] Running Gradle assembly..." -ForegroundColor Yellow
Push-Location $AndroidPath
.\gradlew.bat assembleDebug
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Gradle compilation failed! Please verify Java JDK 17+ and Android SDK are installed." -ForegroundColor Red
    Pop-Location
    Exit 1
}
Pop-Location

# Step 4: Copy Compiled APK to Mobile Folder
Write-Host "`n[4/4] Locating and copying compiled APK..." -ForegroundColor Yellow
$BuiltApkPath = Join-Path $AndroidPath "app/build/outputs/apk/debug/app-debug.apk"
$DestApkPath = Join-Path $PSScriptRoot "family-health-connect.apk"

if (Test-Path $BuiltApkPath) {
    Copy-Item -Path $BuiltApkPath -Destination $DestApkPath -Force
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "SUCCESS: APK generated successfully!" -ForegroundColor Green
    Write-Host "Output path: $DestApkPath" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
} else {
    Write-Host "Error: Built APK file not found at $BuiltApkPath" -ForegroundColor Red
    Exit 1
}
