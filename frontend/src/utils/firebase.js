import { initializeApp } from "firebase/app";
import { 
  getAuth, 
  GoogleAuthProvider, 
  signInWithPopup, 
  signInWithRedirect, 
  getRedirectResult 
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
 * Signs in with Google using popup window, with automatic redirect fallback
 * if browser popup blocker interferes.
 */
export const signInWithGoogle = async () => {
  try {
    const result = await signInWithPopup(auth, googleProvider);
    return result.user;
  } catch (error) {
    if (error.code === 'auth/popup-blocked' || error.message?.includes('popup-blocked')) {
      console.warn("[Firebase] Popup blocked by browser. Attempting redirect fallback...");
      try {
        await signInWithRedirect(auth, googleProvider);
        return null; // Will redirect away
      } catch (redirectErr) {
        console.error("[Firebase] Redirect fallback error:", redirectErr);
        throw redirectErr;
      }
    }
    console.error("Firebase Login Error:", error);
    throw error;
  }
};

/**
 * Checks if user is returning from a redirect login.
 */
export const checkRedirectResult = async () => {
  try {
    const result = await getRedirectResult(auth);
    return result?.user || null;
  } catch (error) {
    console.error("Redirect Result Error:", error);
    return null;
  }
};

