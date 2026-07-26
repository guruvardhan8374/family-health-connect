import 'package:flutter/foundation.dart';

class AppConfig {
  // Active Local Development API URL pointing to localhost via ADB USB reverse port forwarding
  static const String _activeUrl = 'http://192.168.1.6:8000';

  static String get apiBaseUrl => _activeUrl;

  static Future<void> initialize() async {
    debugPrint('[AppConfig] Static local configuration active. Using API URL: $apiBaseUrl');
  }
}
