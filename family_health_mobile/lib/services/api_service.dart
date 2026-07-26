import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'offline_queue_service.dart';
import 'app_config.dart';

class ApiService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/api/v1';

  static String normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final cleanBase = AppConfig.apiBaseUrl.replaceFirst('http://', '').replaceFirst('https://', '');
    if (url.contains('localhost:8000')) {
      return url.replaceAll('localhost:8000', cleanBase);
    }
    if (url.contains('127.0.0.1:8000')) {
      return url.replaceAll('127.0.0.1:8000', cleanBase);
    }
    if (url.contains('192.168.1.4:8000')) {
      return url.replaceAll('192.168.1.4:8000', cleanBase);
    }
    return url;
  }

  // ── Persistent HTTP client — reuses TCP connections instead of opening
  //    a new socket for every request (saves 100-300ms per call on mobile).
  //    NOTE: recreated on network reconnect so stale WiFi sockets are dropped.
  static http.Client _client = http.Client();

  /// Call this when the device switches networks (WiFi change, handoff, etc.).
  /// Closes the old TCP connection pool and opens a fresh one so pending
  /// requests don't hang on a dead socket.
  static void recreateClient() {
    try { _client.close(); } catch (_) {}
    _client = http.Client();
  }

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
    // Token is managed by AuthService; no local cache to clear here
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Helper to send authenticated GET requests with automatic token refresh on 401.
  static Future<http.Response?> _getAuthenticated(String urlString) async {
    try {
      var headers = await _getHeaders();
      var response = await _client.get(
        Uri.parse(urlString),
        headers: headers,
      ).timeout(_kGetTimeout);

      if (response.statusCode == 401) {
        final refreshed = await refreshJwtToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await _client.get(
            Uri.parse(urlString),
            headers: headers,
          ).timeout(_kGetTimeout);
        }
      }
      return response;
    } catch (e) {
      debugPrint('[ApiService] GET Exception on $urlString: $e');
      return null;
    }
  }

  /// Helper to send authenticated PUT requests with automatic token refresh on 401.
  static Future<http.Response?> _putAuthenticated(String urlString, Object? body) async {
    try {
      var headers = await _getHeaders();
      var response = await _client.put(
        Uri.parse(urlString),
        headers: headers,
        body: body,
      ).timeout(_kWriteTimeout);

      if (response.statusCode == 401) {
        debugPrint('[ApiService] PUT $urlString returned 401 — Refreshing JWT token...');
        final refreshed = await refreshJwtToken();
        if (refreshed) {
          headers = await _getHeaders();
          response = await _client.put(
            Uri.parse(urlString),
            headers: headers,
            body: body,
          ).timeout(_kWriteTimeout);
        }
      }
      return response;
    } catch (e) {
      debugPrint('[ApiService] PUT Exception on $urlString: $e');
      return null;
    }
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


  static Future<Map<String, dynamic>?> googleLogin(String email, String username, String idToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/google-login/'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true'
        },
        body: jsonEncode({
          'email': email,
          'username': username,
          'id_token': idToken,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
        };
      }
      String detail = 'google_login_failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) detail = body['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': detail};
    } catch (e) {
      return {'success': false, 'error': 'network_error: $e'};
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
      final response = await _getAuthenticated('$baseUrl/users/profile/');
      if (response != null && response.statusCode == 200) {
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
      final response = await _getAuthenticated('$baseUrl/health/records/');
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _cachedHealthData = data;
        _healthDataCacheTime = DateTime.now();
        return data;
      }
      return _cachedHealthData ?? [];
    } catch (e) { return _cachedHealthData ?? []; }
  }

  static Future<bool> updateLocation({
    required double lat,
    required double lng,
    double? speed,
    int? batteryLevel,
    bool? isMoving,
  }) async {
    final payload = {
      'latitude': lat,
      'longitude': lng,
      'speed': speed ?? 0.0,
      'battery_level': batteryLevel ?? 100,
      'is_moving': isMoving ?? false,
    };
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
      final response = await _getAuthenticated('$baseUrl/family/members/');
      if (response != null && response.statusCode == 200) {
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
      final response = await _getAuthenticated('$baseUrl/chat/conversations/');
      if (response != null && response.statusCode == 200) {
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
      final response = await _getAuthenticated('$baseUrl/chat/messages/?conversation=$conversationId');
      if (response != null && response.statusCode == 200) return jsonDecode(response.body);
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

  /// Gets or creates a family group conversation. Returns the conversation data map or null on failure.
  static Future<Map<String, dynamic>?> getOrCreateFamilyGroupChat(int groupId, String groupName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/conversations/group/'),
        headers: await _getHeaders(),
        body: jsonEncode({'family_group_id': groupId, 'name': groupName}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('[ApiService] getOrCreateFamilyGroupChat error: $e');
    }
    return null;
  }

  // --- EMERGENCY API ---
  static Future<bool> triggerSOS({double? lat, double? lng}) async {
    final payload = {
      'latitude': lat,
      'longitude': lng,
      'location_lat': lat,
      'location_lng': lng,
      'message': 'Emergency! I need help immediately from my mobile app.'
    };
    final res = await _sendMutation(
      '/emergency/alerts/trigger/',
      'POST',
      payload,
      () async => http.post(
        Uri.parse('$baseUrl/emergency/alerts/trigger/'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ),
    );
    return res != null;
  }

  static Future<List<Map<String, dynamic>>> getActiveSOSAlerts() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/emergency/alerts/active/');
      final res = await _client.get(uri, headers: headers).timeout(_kGetTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['results'] ?? []);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {
      debugPrint('[ApiService] getActiveSOSAlerts error: $e');
    }
    return [];
  }

  static Future<bool> resolveSOSAlert(int alertId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/emergency/alerts/$alertId/resolve/');
      final res = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'status': 'RESOLVED'}),
      ).timeout(_kWriteTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[ApiService] resolveSOSAlert error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getNearbyPolice({double? lat, double? lng}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/emergency/nearby-police/?lat=${lat ?? 12.9716}&lng=${lng ?? 77.5946}');
      final res = await _client.get(uri, headers: headers).timeout(_kGetTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['police_stations'] as List?;
        if (list != null) {
          return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
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

  static Future<Map<String, dynamic>> updateProfileSettings(Map<String, dynamic> data) async {
    final urlString = '$baseUrl/settings/profile/';
    final jsonPayload = jsonEncode(data);

    debugPrint('=====================================================');
    debugPrint('[ProfileUpdate] Starting Profile Update');
    debugPrint('[ProfileUpdate] Request URL: $urlString');
    debugPrint('[ProfileUpdate] Request Payload: $jsonPayload');

    try {
      final response = await _putAuthenticated(urlString, jsonPayload);
      if (response == null) {
        debugPrint('[ProfileUpdate ERROR] Network error or timeout when updating profile.');
        return {'success': false, 'error': 'Network connection error or timeout.'};
      }

      debugPrint('[ProfileUpdate] Response Status Code: ${response.statusCode}');
      debugPrint('[ProfileUpdate] Response Body: ${response.body}');
      debugPrint('=====================================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': decoded};
      } else {
        String errorMsg = 'Failed to update profile (${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map) {
            if (errBody['error'] != null) errorMsg = errBody['error'].toString();
            else if (errBody['detail'] != null) errorMsg = errBody['detail'].toString();
            else {
              final firstKey = errBody.keys.first;
              final val = errBody[firstKey];
              errorMsg = '$firstKey: ${val is List ? val.join(', ') : val}';
            }
          } else if (errBody is String) {
            errorMsg = errBody;
          }
        } catch (_) {}
        return {'success': false, 'error': errorMsg};
      }
    } catch (e, stack) {
      debugPrint('[ProfileUpdate EXCEPTION] $e\n$stack');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> uploadAvatarBytes(List<int> bytes, String filename, {String? filePath}) async {
    final String lowerName = filename.toLowerCase();
    String subType = 'jpeg';
    if (lowerName.endsWith('.png')) {
      subType = 'png';
    } else if (lowerName.endsWith('.webp')) {
      subType = 'webp';
    } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      subType = 'jpeg';
    }

    final mediaType = MediaType('image', subType);

    debugPrint('=====================================================');
    debugPrint('[AvatarUpload] Starting Avatar Upload');
    debugPrint('[AvatarUpload] Selected filename: $filename');
    if (filePath != null) debugPrint('[AvatarUpload] Local file path: $filePath');
    debugPrint('[AvatarUpload] Image size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
    debugPrint('[AvatarUpload] Target Content-Type: ${mediaType.mimeType}');

    Future<http.StreamedResponse> sendRequest(String? currentToken) async {
      final uri = Uri.parse('$baseUrl/users/avatar/');
      debugPrint('[AvatarUpload] Endpoint URL: $uri');
      debugPrint('[AvatarUpload] Request Headers: {Bypass-Tunnel-Reminder: true, Authorization: Bearer ${currentToken != null && currentToken.isNotEmpty ? "***PRESENT***" : "NONE"}}');

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Bypass-Tunnel-Reminder': 'true',
        if (currentToken != null && currentToken.isNotEmpty) 'Authorization': 'Bearer $currentToken',
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      );
      return await request.send().timeout(const Duration(seconds: 30));
    }

    try {
      String? token = await _getToken();
      var response = await sendRequest(token);

      // Handle 401 token expiration retry
      if (response.statusCode == 401) {
        debugPrint('[AvatarUpload] 401 Unauthorized — Refreshing JWT token...');
        final refreshed = await refreshJwtToken();
        if (refreshed) {
          token = await _getToken();
          debugPrint('[AvatarUpload] Token refreshed successfully — Retrying upload...');
          response = await sendRequest(token);
        }
      }

      final body = await response.stream.bytesToString();
      debugPrint('[AvatarUpload] Response Status Code: ${response.statusCode}');
      debugPrint('[AvatarUpload] Response Body: $body');
      debugPrint('=====================================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        debugPrint('[AvatarUpload ERROR] Server returned failure status: ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('=====================================================');
      debugPrint('[AvatarUpload EXCEPTION] $e');
      debugPrint('Stack Trace:\n$stack');
      debugPrint('=====================================================');
      return null;
    }
  }

  static Future<bool> deleteAvatar() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl/users/avatar/'),
        headers: headers,
      ).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      final response = await _getAuthenticated('$baseUrl/settings/notifications/');
      if (response != null && response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
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

  // --- NOTIFICATION CENTER API ---
  static Future<List<dynamic>> getNotifications({String? type}) async {
    try {
      String url = '$baseUrl/notifications/';
      if (type != null && type.isNotEmpty && type != 'ALL') {
        url += '?type=$type';
      }
      final response = await _getAuthenticated(url);
      if (response != null && response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) return body;
        if (body is Map && body['results'] is List) return body['results'] as List<dynamic>;
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _getAuthenticated('$baseUrl/notifications/unread-count/');
      if (response != null && response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['unread_count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) { return 0; }
  }

  static Future<bool> markNotificationAsRead(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(Uri.parse('$baseUrl/notifications/$id/mark-read/'), headers: headers).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.post(Uri.parse('$baseUrl/notifications/mark-all-read/'), headers: headers).timeout(_kWriteTimeout);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> deleteNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(Uri.parse('$baseUrl/notifications/$id/'), headers: headers).timeout(_kWriteTimeout);
      return response.statusCode == 200 || response.statusCode == 24;
    } catch (e) { return false; }
  }

  static Future<bool> deleteAllNotifications() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(Uri.parse('$baseUrl/notifications/delete-all/'), headers: headers).timeout(_kWriteTimeout);
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
      final response = await _getAuthenticated('$baseUrl/family/groups/');
      if (response != null && response.statusCode == 200) {
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
    final url = '$baseUrl/users/register/';
    final requestBodyMasked = {
      'username': username,
      'email': email,
      'password': '***',
      'password_confirm': '***',
      'phone_number': phoneNumber,
      'role': role
    };

    debugPrint('[NETWORK AUDIT] >>> START REGISTRATION REQUEST >>>');
    debugPrint('[NETWORK AUDIT] Request URL: $url');
    debugPrint('[NETWORK AUDIT] Request Headers: {"Content-Type": "application/json", "Bypass-Tunnel-Reminder": "true"}');
    debugPrint('[NETWORK AUDIT] Request Body (masked): ${jsonEncode(requestBodyMasked)}');

    try {
      recreateClient();
      final actualBody = jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'phone_number': phoneNumber,
        'role': role
      });

      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: actualBody,
      ).timeout(_kWriteTimeout);

      debugPrint('[NETWORK AUDIT] Response Status: ${response.statusCode}');
      debugPrint('[NETWORK AUDIT] Response Body: ${response.body}');
      debugPrint('[NETWORK AUDIT] <<< END REGISTRATION REQUEST (SUCCESS) <<<');

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (decodeErr) {
        debugPrint('[NETWORK AUDIT] JSON Decode Exception: $decodeErr');
        return {'status_code': response.statusCode, 'body': response.body};
      }
    } on TimeoutException catch (e) {
      debugPrint('[NETWORK AUDIT] TIMEOUT ERROR: Server failed to respond within ${_kWriteTimeout.inSeconds} seconds.');
      debugPrint('[NETWORK AUDIT] Exception Details: $e');
      debugPrint('[NETWORK AUDIT] <<< END REGISTRATION REQUEST (TIMEOUT) <<<');
      return {'network_error': true, 'detail': 'Connection timeout. Check your host IP and network connectivity. ($e)'};
    } on SocketException catch (e) {
      debugPrint('[NETWORK AUDIT] SOCKET ERROR: Cannot establish TCP connection to host.');
      debugPrint('[NETWORK AUDIT] Target Host: ${Uri.parse(url).host}, Port: ${Uri.parse(url).port}');
      debugPrint('[NETWORK AUDIT] Exception Details: $e');
      debugPrint('[NETWORK AUDIT] <<< END REGISTRATION REQUEST (SOCKET ERROR) <<<');
      return {'network_error': true, 'detail': 'Socket error. Ensure your phone is on the same network as the server. ($e)'};
    } catch (e) {
      debugPrint('[NETWORK AUDIT] GENERAL EXCEPTION: $e');
      debugPrint('[NETWORK AUDIT] <<< END REGISTRATION REQUEST (GENERAL EXCEPTION) <<<');
      return {'network_error': true, 'detail': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/verify-otp/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(_kWriteTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'OTP verified successfully.'};
      } else {
        return {'success': false, 'message': data['error'] ?? data['detail'] ?? 'Invalid or expired OTP.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/users/resend-otp/'),
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode({'email': email}),
      ).timeout(_kWriteTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'New verification code sent.'};
      } else {
        return {'success': false, 'message': data['error'] ?? data['detail'] ?? 'Failed to resend code.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
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
    } catch (e) {
      return [];
    }
  }
}




