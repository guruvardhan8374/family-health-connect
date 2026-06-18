# Firebase Phone Authentication Setup Guide

This project now uses **Firebase Phone Authentication** for its primary phone-based login and registration flow across both the Web (React) and Mobile (Flutter) applications. User profiles are automatically created and stored in **Firebase Firestore**.

The legacy Django backend endpoints (`/users/send-phone-otp/` and `/users/verify-phone-otp/`) remain available as a fallback or for API testing, but the frontend clients interface directly with Firebase.

Follow these steps to configure your Firebase project for Phone Authentication.

---

## 1. Firebase Console Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your existing project or create a new one.
3. Navigate to **Build > Authentication**.
4. Click on the **Sign-in method** tab.
5. Click **Add new provider** and select **Phone**.
6. Toggle the **Enable** switch.
7. (Optional but Recommended for Dev) Add **Test phone numbers**:
   - In the "Phone number for testing" section, add a number like `+16505551234` and a verification code like `123456`. This allows you to test the flow without sending real SMS messages or getting rate-limited.
8. Click **Save**.

---

## 2. Firestore Setup

Since the app stores user profiles (`uid`, `phoneNumber`, `lastLogin`, etc.) in Firestore:

1. Navigate to **Build > Firestore Database**.
2. Click **Create database** (if you haven't already).
3. Start in **Production mode**.
4. Deploy the security rules provided in the `firestore.rules` file in the root of this project. You can do this by copying and pasting the contents into the **Rules** tab in the Firebase Console:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       match /{document=**} {
         allow read, write: if false;
       }
     }
   }
   ```

---

## 3. Web Application Configuration (React/Vite)

The web application uses an invisible reCAPTCHA to prevent abuse. No special reCAPTCHA keys are needed; Firebase handles this automatically using your Firebase config.

Ensure your `.env` file in the `frontend` directory contains your correct Firebase project details:

```env
VITE_FIREBASE_API_KEY="your-api-key"
VITE_FIREBASE_AUTH_DOMAIN="your-project.firebaseapp.com"
VITE_FIREBASE_PROJECT_ID="your-project-id"
VITE_FIREBASE_STORAGE_BUCKET="your-project.appspot.com"
VITE_FIREBASE_MESSAGING_SENDER_ID="your-messaging-sender-id"
VITE_FIREBASE_APP_ID="your-app-id"
```

---

## 4. Mobile Application Configuration (Flutter)

The Flutter app uses the `firebase_auth` and `cloud_firestore` plugins. 

1. Ensure you have registered both an **iOS app** and an **Android app** in your Firebase project settings.
2. **Android**: 
   - Download the `google-services.json` file.
   - Place it in `family_health_mobile/android/app/`.
   - Optional: Add your SHA-1 and SHA-256 certificate fingerprints in the Firebase Console to enable automatic SMS retrieval without manual code entry.
3. **iOS**: 
   - Download the `GoogleService-Info.plist` file.
   - Place it in `family_health_mobile/ios/Runner/`.
   - Enable Push Notifications in Xcode (required for iOS background APNs verification).

---

## 5. Troubleshooting & Rate Limits

- **reCAPTCHA Issues (Web)**: If the OTP fails to send, check the browser console. The invisible reCAPTCHA might be blocked by ad-blockers or strict privacy settings.
- **Quota Exceeded**: Firebase Phone Auth has a generous free tier (10k/month), but SMS delivery to certain countries might be restricted. If you see "quota exceeded" errors, check your Firebase Billing limits.
- **Platform Verification Failed (Mobile)**: If Android fails to send the OTP without a reCAPTCHA fallback, ensure your SHA-1 hash is correctly registered in Firebase and that you are using a real device or a Play Services enabled emulator.
