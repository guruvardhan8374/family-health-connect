import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

const resources = {
  en: {
    translation: {
      "welcome": "Welcome to FamilyConnect",
      "dashboard": "Dashboard",
      "health_hub": "Health Hub",
      "intelligence": "Intelligence",
      "sos": "SOS Emergency",
      "voice_assistant": "Voice Assistant"
    }
  },
  hi: {
    translation: {
      "welcome": "FamilyConnect में आपका स्वागत है",
      "dashboard": "डैशबोर्ड",
      "health_hub": "स्वास्थ्य केंद्र",
      "intelligence": "बुद्धिमत्ता",
      "sos": "एसओएस आपातकाल",
      "voice_assistant": "वॉयस असिस्टेंट"
    }
  },
  te: {
    translation: {
      "welcome": "FamilyConnect కి స్వాగతం",
      "dashboard": "డాష్‌బోర్డ్",
      "health_hub": "ఆరోగ్య కేంద్రం",
      "intelligence": "మేధస్సు",
      "sos": "SOS అత్యవసర పరిస్థితి",
      "voice_assistant": "వాయిస్ అసిస్టెంట్"
    }
  },
  ta: {
    translation: {
      "welcome": "FamilyConnect-க்கு வரவேற்கிறோம்",
      "dashboard": "டாஷ்போர்டு",
      "health_hub": "சுகாதார மையம்",
      "intelligence": "புத்திசாலித்தனம்",
      "sos": "SOS அவசரநிலை",
      "voice_assistant": "குரல் உதவியாளர்"
    }
  }
};

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;
