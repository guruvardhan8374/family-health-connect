class AppConfig {
  // ─── PRODUCTION (Render cloud) ────────────────────────────────────────────
  // Live cloud backend shared by both React Web App & Flutter Mobile App
  static const String productionUrl = 'https://guruvardhan-fhc-backend.onrender.com';

  // ─── LOCAL DEVELOPMENT ────────────────────────────────────────────────────
  static const String localUrl = 'http://10.218.104.94:8000';

  // ─── ACTIVE URL ───────────────────────────────────────────────────────────
  // Default to productionUrl so both Web and Mobile use the exact same cloud DB
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: productionUrl,
  );
}
