class AppConfig {
  // ─── PRODUCTION (Render cloud) ────────────────────────────────────────────
  // This URL works from ANYWHERE: mobile data, any Wi-Fi, any country.
  // No need to be on the same Wi-Fi as the laptop.
  static const String productionUrl = 'https://family-health-connect-backend.onrender.com';

  // ─── LOCAL DEVELOPMENT ────────────────────────────────────────────────────
  // Only works when phone and laptop are on the SAME Wi-Fi network.
  // Run `ipconfig` on Windows to get your PC's current LAN IP.
  static const String localUrl = 'http://10.218.104.94:8000';

  // ─── ACTIVE URL ───────────────────────────────────────────────────────────
  // Uses production URL by default so the app works everywhere.
  // Override with --dart-define=API_URL=http://192.168.1.6:8000 for local dev.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: localUrl,
  );
}
