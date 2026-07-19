class AppConfig {
  // Use Render backend as default production target, fallback to local IP
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://family-health-connect-backend.onrender.com',
  );
}
