import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'sync_service.dart';
import 'offline_queue_service.dart';
import 'app_config.dart';

class ApiService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/api/v1';

  // ── Persistent HTTP client — reuses TCP connections instead of opening
  //    a new socket for every request (saves 100-300ms per call on mobile).
  static final http.Client _client = http.Client();

  static Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  /// Refreshes access token using stored refresh_token if 401 occurs
  static Future<bool> refreshJwtToken() async {
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await AuthService.logout();
        return false;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(_kWriteTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          await AuthService.updateAccessToken(newAccess, newRefreshToken: newRefresh);
          return true;
        }
      }
      // Token refresh failed (refresh token also invalid/expired) — force logout
      await AuthService.logout();
      return false;
    } catch (_) {
      await AuthService.logout();
      return false;
    }
  }

  /// Call this on logout so the next login fetches a fresh token.
  static void clearTokenCache() {
    _cachedProfile = null;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Standard GET timeout: 10 s on mobile (was unlimited — could hang forever)
  static const _kGetTimeout = Duration(seconds: 10);
  // ── Write timeout: 15 s for POST/PUT/PATCH
  static const _kWriteTimeout = Duration(seconds: 15);

  /// Generic POST used by the offline queue flush mechanism.
  static Future<Map<String, dynamic>?> postRaw(
      String endpoint, dynamic body) async {
    try {
      final headers = await _getHeaders();
      final url = endpoint.startsWith('http')
          ? Uri.parse(endpoint)
          : Uri.parse('$baseUrl$endpoint');
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_kWriteTimeout);
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
      final response = await _client.post(
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
        // Extract the actual error message from the server response
        String serverMessage = 'unauthorized';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            // DRF ValidationError returns non_field_errors or detail
            if (body['non_field_errors'] is List && (body['non_field_errors'] as List).isNotEmpty) {
              serverMessage = (body['non_field_errors'] as List).first.toString();
            } else if (body['detail'] != null) {
              serverMessage = body['detail'].toString();
            } else if (body['username'] is List && (body['username'] as List).isNotEmpty) {
              serverMessage = (body['username'] as List).first.toString();
            } else if (body['password'] is List && (body['password'] as List).isNotEmpty) {
              serverMessage = (body['password'] as List).first.toString();
            } else {
              // Fallback: join all error values
              final msgs = body.values
                  .expand((v) => v is List ? v : [v])
                  .map((e) => e.toString())
                  .toList();
              if (msgs.isNotEmpty) serverMessage = msgs.first;
            }
          }
        } catch (_) {}
        return {
          'success': false,
          'error': serverMessage,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'network_error',
      };
    }
  }


  // ── Short-lived TTL cache (15 seconds) for frequent read endpoints ─────────
  static List<dynamic>? _cachedFamilyMembers;
  static DateTime? _familyMembersCacheTime;

  static List<dynamic>? _cachedHealthData;
  static DateTime? _healthDataCacheTime;

  static List<dynamic>? _cachedConversations;
  static DateTime? _conversationsCacheTime;

  static List<dynamic>? _cachedFamilyGroups;
  static DateTime? _familyGroupsCacheTime;

  static const _kCacheTtl = Duration(seconds: 15);

  /// Clears all response caches (call on logout or mutation)
  static void clearAllCaches() {
    _cachedToken = null;
    _cachedProfile = null;
    _cachedFamilyMembers = null;
    _cachedHealthData = null;
    _cachedConversations = null;
    _cachedFamilyGroups = null;
  }

  // ── Cached profile: returns from memory after the first call ────────────────
  static Map<String, dynamic>? _cachedProfile;

  static Future<Map<String, dynamic>?> getProfile() async {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: headers,
      ).timeout(_kGetTimeout);
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
  static void clearProfileCache() => clearAllCaches();

  static Future<List<dynamic>> getHealthData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHealthData != null && _healthDataCacheTime != null) {
      if (DateTime.now().difference(_healthDataCacheTime!) < _kCacheTtl) {
        return _cachedHealthData!;
      }
    }
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/health/records/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _cachedHealthData = data;
        _healthDataCacheTime = DateTime.now();
        return data;
      }
      return _cachedHealthData ?? [];
    } catch (e) { return _cachedHealthData ?? []; }
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

  static Future<List<dynamic>> getFamilyMembers({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFamilyMembers != null && _familyMembersCacheTime != null) {
      if (DateTime.now().difference(_familyMembersCacheTime!) < _kCacheTtl) {
        return _cachedFamilyMembers!;
      }
    }
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/family/members/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> data = [];
        if (body is List) {
          data = body;
        } else if (body is Map && body['results'] is List) {
          data = body['results'] as List<dynamic>;
        }
        _cachedFamilyMembers = data;
        _familyMembersCacheTime = DateTime.now();
        return data;
      }
      return _cachedFamilyMembers ?? [];
    } catch (e) { return _cachedFamilyMembers ?? []; }
  }

  // --- CHAT API ---
  static Future<List<dynamic>> getConversations({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedConversations != null && _conversationsCacheTime != null) {
      if (DateTime.now().difference(_conversationsCacheTime!) < _kCacheTtl) {
        return _cachedConversations!;
      }
    }
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/chat/conversations/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _cachedConversations = data;
        _conversationsCacheTime = DateTime.now();
        return data;
      }
      return _cachedConversations ?? [];
    } catch (e) { return _cachedConversations ?? []; }
  }

  static Future<List<dynamic>> getChatMessages(int conversationId) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/chat/messages/?conversation=$conversationId'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
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
      final response = await _client.get(Uri.parse('$baseUrl/settings/profile/'), headers: headers).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updateProfileSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(Uri.parse('$baseUrl/settings/profile/'), headers: headers, body: jsonEncode(data)).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse('$baseUrl/settings/notifications/'), headers: headers).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updateNotificationSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(Uri.parse('$baseUrl/settings/notifications/'), headers: headers, body: jsonEncode(data)).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getPrivacySettings() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse('$baseUrl/settings/privacy/'), headers: headers).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updatePrivacySettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(Uri.parse('$baseUrl/settings/privacy/'), headers: headers, body: jsonEncode(data)).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getThemeSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse('$baseUrl/settings/theme/'), headers: headers).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updateThemeSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(Uri.parse('$baseUrl/settings/theme/'), headers: headers, body: jsonEncode(data)).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getAccountSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse('$baseUrl/settings/account/'), headers: headers).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updateAccountSettings(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(Uri.parse('$baseUrl/settings/account/'), headers: headers, body: jsonEncode(data)).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(
        Uri.parse('$baseUrl/settings/account/'),
        headers: headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ).timeout(_kWriteTimeout);
      if (response.statusCode == 200) return {'success': true};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) { return {'error': 'Network connection failed.'}; }
  }

  static Future<bool> deleteAccount() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl/settings/account/'),
        headers: headers,
      ).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  // --- FAMILY MANAGEMENT API ---
  static Future<Map<String, dynamic>> inviteFamilyMember(int groupId, String email, String label) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/family/groups/$groupId/invite/'),
        headers: headers,
        body: jsonEncode({'email': email, 'label': label}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        clearAllCaches();
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      String serverMessage = 'Failed to send invitation (HTTP ${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) serverMessage = body['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': serverMessage};
    } catch (e) {
      return {'success': false, 'error': 'Network connection timeout or error.'};
    }
  }

  static Future<Map<String, dynamic>> joinFamilyByCode(String code, String label) async {
    try {
      var headers = await _getHeaders();
      var response = await _client.post(
        Uri.parse('$baseUrl/family/groups/join-by-code/'),
        headers: headers,
        body: jsonEncode({'family_code': code, 'label': label}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        final refreshed = await refreshJwtToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await _client.post(
            Uri.parse('$baseUrl/family/groups/join-by-code/'),
            headers: headers,
            body: jsonEncode({'family_code': code, 'label': label}),
          ).timeout(const Duration(seconds: 30));
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        clearAllCaches();
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      String serverMessage = 'Failed to join group (HTTP ${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          serverMessage = body['error'].toString();
        } else if (body is Map && body['detail'] != null) {
          serverMessage = body['detail'].toString();
        }
      } catch (_) {}
      return {'success': false, 'error': serverMessage};
    } catch (e) {
      return {'success': false, 'error': 'Network connection timeout or error.'};
    }
  }

  static Future<List<dynamic>> getFamilyGroups({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFamilyGroups != null && _familyGroupsCacheTime != null) {
      if (DateTime.now().difference(_familyGroupsCacheTime!) < _kCacheTtl) {
        return _cachedFamilyGroups!;
      }
    }
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/family/groups/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> data = [];
        if (body is List) {
          data = body;
        } else if (body is Map && body['results'] is List) {
          data = body['results'] as List<dynamic>;
        }
        _cachedFamilyGroups = data;
        _familyGroupsCacheTime = DateTime.now();
        return data;
      }
      return _cachedFamilyGroups ?? [];
    } catch (e) { return _cachedFamilyGroups ?? []; }
  }

  static Future<Map<String, dynamic>> createFamilyGroup(String name, String description) async {
    try {
      var headers = await _getHeaders();
      var response = await _client.post(
        Uri.parse('$baseUrl/family/groups/'),
        headers: headers,
        body: jsonEncode({'name': name, 'description': description}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        final refreshed = await refreshJwtToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await _client.post(
            Uri.parse('$baseUrl/family/groups/'),
            headers: headers,
            body: jsonEncode({'name': name, 'description': description}),
          ).timeout(const Duration(seconds: 30));
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        clearAllCaches();
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }

      String serverMessage = 'Failed to create Family Circle (HTTP ${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          if (body['detail'] != null) {
            serverMessage = body['detail'].toString();
          } else if (body['name'] is List && (body['name'] as List).isNotEmpty) {
            serverMessage = (body['name'] as List).first.toString();
          } else if (body['error'] != null) {
            serverMessage = body['error'].toString();
          }
        }
      } catch (_) {}

      return {'success': false, 'error': serverMessage};
    } catch (e) {
      return {'success': false, 'error': 'Network connection timeout or error.'};
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
      final response = await _client.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'username': username, 'email': email, 'password': password,
          'password_confirm': passwordConfirm, 'phone_number': phoneNumber, 'role': role}),
      ).timeout(_kWriteTimeout);
      try { return jsonDecode(response.body) as Map<String, dynamic>; }
      catch (_) { return {'status_code': response.statusCode}; }
    } catch (e) { return null; }
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/verify-otp/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
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

  static Future<bool> logHealthMetric(String type, double value) async {
    final payload = {
      'metric_type': type,
      'value': value,
    };
    final res = await _sendMutation(
      '/health/metrics/',
      'POST',
      payload,
      () async => http.post(
        Uri.parse('$baseUrl/health/metrics/'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ),
    );
    return res != null;
  }

  static Future<Map<String, dynamic>?> getHealthSummary({String range = 'daily'}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/health/summary/?range=$range'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> getTodayHealthSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/health/summary/today/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> getHealthGoals() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/health/goals/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }


  // ─── Phone OTP Authentication ───────────────────────────────────────────────

  /// Sends a one-time password to [phoneNumber].
  /// Returns null on success, or an error string on failure.
  static Future<String?> sendPhoneOtp(String phoneNumber) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/send-phone-otp/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'phone_number': phoneNumber}),
      ).timeout(_kWriteTimeout);
      if (response.statusCode == 200) return null;
      final body = jsonDecode(response.body);
      return body['error']?.toString() ?? 'Failed to send OTP';
    } catch (e) { return 'Network error. Please check your connection.'; }
  }

  static Future<Map<String, dynamic>?> verifyPhoneOtp(String phoneNumber, String otp) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/verify-phone-otp/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
      ).timeout(_kWriteTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  // ─── Wireless Vitals & IoT Sync API ──────────────────────────────────────────

  /// Triggers a manual sync for an external platform (e.g. GOOGLE_FIT, APPLE_HEALTH, FITBIT, GARMIN)
  static Future<bool> syncIoTData(String platform) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/iot/sync/'),
        headers: headers,
        body: jsonEncode({'platform': platform}),
      ).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> getIoTSyncHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/iot/history/'),
        headers: headers,
      ).timeout(_kGetTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
      return [];
    } catch (e) { return []; }
  }
}

