import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // Primary default URL. Port 8000 is mapped on USB via ADB reverse, or direct Wi-Fi.
  static String _activeUrl = 'http://127.0.0.1:8000';

  static String get apiBaseUrl => _activeUrl;

  static const List<String> candidateUrls = [
    'http://127.0.0.1:8000', // ADB reverse USB port forwarding
    'http://192.168.1.7:8000', // Local Wi-Fi network host IP
    'http://10.0.2.2:8000', // Android Emulator host loopback
    'http://192.168.1.6:8000', // Alternative Wi-Fi host IP
    'https://family-health-connect-backend.onrender.com', // Cloud fallback
  ];

  static Future<void> initialize() async {
    if (kIsWeb) {
      _activeUrl = 'http://127.0.0.1:8000';
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1000);

    for (final candidate in candidateUrls) {
      try {
        final uri = Uri.parse('$candidate/api/health/');
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 500) {
          _activeUrl = candidate;
          debugPrint('[AppConfig] Connected successfully to API backend at: $_activeUrl');
          client.close();
          return;
        }
      } catch (_) {
        // Continue to next candidate
      }
    }
    client.close();
    debugPrint('[AppConfig] Could not auto-ping candidates. Falling back to active URL: $_activeUrl');
  }
}
