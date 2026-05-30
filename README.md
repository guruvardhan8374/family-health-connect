# Family Health Connect – Production-Ready Ecosystem

Smart Personal & Family Connectivity App with Health-Aware Support. This repository contains the complete full-stack codebase optimized for **Production Deployment**, **PWA Installation**, and **Android Mobile Packaging (APK)**.

## Project Structure
- `/familyconnect` – Python Django, Django REST Framework (DRF), Django Channels/WebSockets (Daphne), and PostgreSQL.
- `/frontend` – React, Vite, Tailwind CSS v4, Recharts, Lucide Icons, and Progressive Web App (PWA) support.
- `/mobile` – Mobile wrapper configuration and automated PowerShell Android build script.
- `docker-compose.yml` – Local development and orchestration stack.
- `.github/workflows/ci-cd.yml` – Automated CI/CD pipeline to compile the Android APK in the cloud.

---

## 🚀 1. Production Deployment Guide

### A. Backend Hosting (Render / Railway / AWS)
The backend is Dockerized and supports ASGI (Daphne) for production WebSockets. We provide a `render.yaml` blueprint for Render.

#### Deployment Steps on Render:
1. Log in to your [Render Dashboard](https://dashboard.render.com).
2. Click **New +** and select **Blueprint**.
3. Link your GitHub repository.
4. Render will read the `render.yaml` configuration and automatically spin up:
   - **PostgreSQL Database** (`familyconnect-db`)
   - **Redis Service** (`familyconnect-redis` for WebSocket layer cache)
   - **Daphne Web Service** (`family-health-connect-backend`)
5. In the backend Web Service **Environment** settings, configure:
   - `CORS_ALLOWED_ORIGINS`: Set to your frontend Vercel/Netlify URL.
   - `DATABASE_URL` & `REDIS_URL`: Auto-wired by Blueprint.
   - `GEMINI_API_KEY`: Add your Gemini AI API key for Health Intelligence.

---

### B. Frontend Hosting (Vercel / Netlify)
The React application builds to static assets, which can be served for free on Vercel or Netlify.

#### Deployment Steps on Vercel:
1. Log in to [Vercel](https://vercel.com).
2. Click **Add New** -> **Project** and select your repository.
3. Set the root directory to `frontend`.
4. Configure the build settings:
   - **Framework Preset**: Vite
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
5. Under **Environment Variables**, add:
   - `VITE_API_URL`: Set to your Render backend web service URL (e.g., `https://your-backend.onrender.com`).
6. Click **Deploy**. Vercel will apply the `vercel.json` routing configuration to handle client-side routing.

---

## 📱 2. Progressive Web App (PWA) Setup

The web application is fully PWA-enabled out of the box using `vite-plugin-pwa`. It provides:
- **Offline Caching**: All static JS, CSS, and HTML resources are precached by the service worker (`sw.js`).
- **Web App Manifest**: Configured in `frontend/public/manifest.json` with standard icons, theme colors, and standalone display.
- **Installability**: Browsers on Android, iOS, or Desktop will prompt users to "Add to Home Screen" like a native application.

---

## 🤖 3. Android APK Compilation

We use **Capacitor** to wrap the React production bundle into a native Android application.

### Option A: Cloud Compile via GitHub Actions (Zero Setup - Recommended)
You do not need to install Android Studio or the Android SDK locally.
1. Commit and push your changes to the `main` branch of your GitHub repository.
2. Go to the **Actions** tab of your repository on GitHub.
3. The **CI/CD Pipeline & Android APK Build** workflow will run.
4. Once completed, click on the workflow run, scroll to **Artifacts**, and download `family-health-connect-apk` which contains the compiled `app-debug.apk`.

---

### Option B: Local Android APK Build
To compile the APK on your machine, you must have **Java JDK 17** and **Android SDK** installed.

1. Generate PWA assets and run a production build:
   ```bash
   cd frontend
   # Programmatically generate high-res icons and splash screen using Python Pillow
   python generate_pwa_assets.py
   # Build the React application
   npm run build
   ```
2. Sync the assets to the Android capacitor project:
   ```bash
   npx cap sync android
   ```
3. Compile the APK using the Gradle wrapper:
   ```bash
   cd android
   # Windows:
   .\gradlew.bat assembleDebug
   # Linux/macOS:
   chmod +x gradlew && ./gradlew assembleDebug
   ```
4. The generated APK will be available at:
   `frontend/android/app/build/outputs/apk/debug/app-debug.apk`

*Tip: On Windows, you can simply run the automation script in the `mobile/` directory:*
```powershell
cd mobile
.\build-apk.ps1
```

---

## 📦 4. Play Store-Ready Release Build

To publish the application on the Google Play Store, you need a signed release build (Android App Bundle - `.aab`).

### Step 1: Generate a Signing Keystore
Run the following keytool command to generate a private signing key:
```bash
keytool -genkey -v -keystore familyconnect.keystore -alias familyconnect -keyalg RSA -keysize 2048 -validity 10000
```
Keep this keystore file secure and note down the store and key passwords.

### Step 2: Configure Android Signing Variables
Create a file named `gradle.properties` inside `frontend/android/` (or update the existing one) with:
```properties
RELEASE_STORE_FILE=../familyconnect.keystore
RELEASE_STORE_PASSWORD=your_store_password
RELEASE_KEY_ALIAS=familyconnect
RELEASE_KEY_PASSWORD=your_key_password
```

### Step 3: Compile Release Android App Bundle (AAB)
Compile the production optimized Android App Bundle:
```bash
cd frontend/android
.\gradlew.bat bundleRelease
```
The Play Store upload-ready file is generated at:
`frontend/android/app/build/outputs/bundle/release/app-release.aab`

---

## 💻 5. Local Orchestration (Docker Compose)

For unified local execution of the full stack (Database, Cache, Backend, and Frontend):
1. In the root workspace directory, run:
   ```bash
   docker-compose up --build
   ```
2. This will run:
   - **PostgreSQL Database** on port `5432`
   - **Redis Cache/Channels Layer** on port `6379`
   - **ASGI Backend Web Service** on `http://localhost:8000`
   - **React Frontend Application** on `http://localhost:5173`
