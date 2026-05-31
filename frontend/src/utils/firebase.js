import { initializeApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithRedirect,
  getRedirectResult,
} from "firebase/auth";

// Firebase project config (values injected from environment variables)
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "YOUR_API_KEY",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "YOUR_PROJECT.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "YOUR_PROJECT_ID",
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "YOUR_PROJECT.appspot.com",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "YOUR_MESSAGING_SENDER_ID",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();

/**
 * Initiates Google Sign-In using redirect flow.
 * The user is redirected to Google's sign-in page.
 * After authentication, Google redirects back to the app.
 * Call getGoogleRedirectResult() on the landing page to retrieve the user.
 */
export const signInWithGoogle = async () => {
  try {
    await signInWithRedirect(auth, googleProvider);
    // NOTE: After this line the browser navigates away.
    // The user result is retrieved in getGoogleRedirectResult().
  } catch (error) {
    console.error("Firebase Redirect Error:", error);
    throw error;
  }
};

/**
 * Call this once on the login page mount to capture
 * the result after Google redirects the user back.
 * Returns the Firebase User object or null if no redirect happened.
 */
export const getGoogleRedirectResult = async () => {
  try {
    const result = await getRedirectResult(auth);
    if (result) {
      return result.user;
    }
    return null;
  } catch (error) {
    console.error("Firebase Redirect Result Error:", error);
    throw error;
  }
};
