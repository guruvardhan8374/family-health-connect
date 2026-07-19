import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'sync_service.dart';
import 'offline_queue_service.dart';
import 'app_config.dart';

class ApiService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/api/v1';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generic POST used by the offline queue flush mechanism.
  static Future<Map<String, dynamic>?> postRaw(
      String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final url = endpoint.startsWith('http')
          ? Uri.parse(endpoint)
          : Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Helper to send write mutations (POST, PUT, PATCH, DELETE).
  /// If offline, enqueues to the offline queue and returns a status map.
  static Future<Map<String, dynamic>?> _sendMutation(
    String endpoint,
    String method,
    Map<String, dynamic> payload,
    Future<http.Response> Function() requestFn,
  ) async {
    final online = SyncService.instance.isOnline;
    if (!online) {
      await OfflineQueueService.instance.push(
        endpoint: endpoint,
        method: method,
        payload: payload,
      );
      return {'status': 'queued', 'offline': true};
    }

    try {
      final response = await requestFn();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          try {
            return jsonDecode(response.body) as Map<String, dynamic>?;
          } catch (_) {
            return {'status': 'success'};
          }
        }
        return {'status': 'success'};
      }
      return null;
    } catch (e) {
      await OfflineQueueService.instance.push(
        endpoint: endpoint,
        method: method,
        payload: payload,
      );
      return {'status': 'queued', 'offline': true};
    }
  }


  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true'
        },
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => http.Response('{"error":"timeout"}', 408),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
        };
      } else if (response.statusCode == 408 || response.statusCode == 504) {
        return {
          'success': false,
          'error': 'timeout',
        };
      } else {
        return {
          'success': false,
          'error': 'unauthorized',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'network_error',
      };
    }
  }

  // ── Cached profile: returns from memory after the first call ────────────────
  static Map<String, dynamic>? _cachedProfile;

  static Future<Map<String, dynamic>?> getProfile() async {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        _cachedProfile = jsonDecode(response.body) as Map<String, dynamic>;
        return _cachedProfile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clears the profile cache (call on logout).
  static void clearProfileCache() => _cachedProfile = null;

  static Future<List<dynamic>> getHealthData() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/health/records/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateLocation({required double lat, required double lng}) async {
    final payload = {'latitude': lat, 'longitude': lng};
    final res = await _sendMutation(
      '/users/locations/',
      'POST',
      payload,
      () async => http.post(
        Uri.parse('$baseUrl/users/locations/'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ),
    );
    return res != null;
  }

  static Future<List<dynamic>> getFamilyMembers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/family/members/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- CHAT API ---
  static Future<List<dynamic>> getConversations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversations/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getChatMessages(int conversationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chat/messages/?conversation=$conversationId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> sendMessage(int conversationId, String content) async {
    final payload = {
      'conversation': conversationId,
      'content': content,
      'message_type': 'TEXT'
    };
    final res = await _sendMutation(
      '/chat/messages/',
      'POST',
      payload,
      () async => http.post(
        Uri.parse('$baseUrl/chat/messages/'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ),
    );
    return res != null;
  }

  // --- EMERGENCY API ---
  static Future<bool> triggerSOS({double? lat, double? lng}) async {
    final payload = {
      'location_lat': lat,
      'location_lng': lng,
      'message': 'Emergency! I need help immediately from my mobile app.'
    };
    final res = await _sendMutation(
      '/emergency/alerts/',
      'POST',
      payload,
      () async => http.post(
        Uri.parse('$baseUrl/emergency/alerts/'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ),
    );
    return res != null;
  }

  // --- SETTINGS API ---
  static Future<Map<String, dynamic>?> getProfileSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/settings/profile/'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateProfileSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/profile/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/settings/notifications/'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateNotificationSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/notifications/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPrivacySettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/settings/privacy/'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updatePrivacySettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/privacy/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getThemeSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/settings/theme/'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateThemeSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/theme/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getAccountSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/settings/account/'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateAccountSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/account/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/account/'),
        headers: headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Network connection failed.'};
    }
  }

  static Future<bool> deleteAccount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/settings/account/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- FAMILY MANAGEMENT API ---
  static Future<Map<String, dynamic>?> inviteFamilyMember(int groupId, String email, String label) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/family/groups/$groupId/invite/'),
        headers: headers,
        body: jsonEncode({'email': email, 'label': label}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> joinFamilyByCode(String code, String label) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/family/groups/join-by-code/'),
        headers: headers,
        body: jsonEncode({'family_code': code, 'label': label}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getFamilyGroups() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/family/groups/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createFamilyGroup(String name, String description) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/family/groups/';
      print('[ApiService] createFamilyGroup URL: $url');
      print('[ApiService] Request Headers: $headers');
      print('[ApiService] Request Body: {"name": "$name", "description": "$description"}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );
      
      print('[ApiService] Response Status: ${response.statusCode}');
      print('[ApiService] Response Body: ${response.body}');
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[ApiService] Error creating family group: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true'
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
          'phone_number': phoneNumber,
          'role': role,
        }),
      );
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'status_code': response.statusCode};
      }
    } catch (e) {
      return null;
    }
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/verify-otp/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true'
        },
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> createHealthRecord(Map<String, dynamic> data) async {
    final res = await _sendMutation(
      '/health/records/',
      'POST',
      data,
      () async => http.post(
        Uri.parse('$baseUrl/health/records/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      ),
    );
    return res != null;
  }

  static Future<bool> syncHealthSnapshot(Map<String, dynamic> data) async {
    final res = await _sendMutation(
      '/health/snapshots/',
      'POST',
      data,
      () async => http.post(
        Uri.parse('$baseUrl/health/snapshots/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      ),
    );
    return res != null;
  }

  static Future<Map<String, dynamic>?> getHealthSummary({String range = 'daily'}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/health/summary/?range=$range'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getHealthGoals() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/health/goals/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }


  // ─── Phone OTP Authentication ───────────────────────────────────────────────

  /// Sends a one-time password to [phoneNumber].
  /// Returns null on success, or an error string on failure.
  static Future<String?> sendPhoneOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/send-phone-otp/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({'phone_number': phoneNumber}),
      );
      if (response.statusCode == 200) return null; // success
      final body = jsonDecode(response.body);
      return body['error']?.toString() ?? 'Failed to send OTP';
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  /// Verifies [otp] for [phoneNumber]. On success returns the token map
  /// (access, refresh, user_id, username, role). On failure returns null.
  static Future<Map<String, dynamic>?> verifyPhoneOtp(
      String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/verify-phone-otp/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Wireless Vitals & IoT Sync API ──────────────────────────────────────────

  /// Triggers a manual sync for an external platform (e.g. GOOGLE_FIT, APPLE_HEALTH, FITBIT, GARMIN)
  static Future<bool> syncIoTData(String platform) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/iot/sync/'),
        headers: headers,
        body: jsonEncode({'platform': platform}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves sync logs and histories for external devices/platforms
  static Future<List<dynamic>> getIoTSyncHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/iot/history/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

