import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // Bypassing Windows Firewall by using a permanent secure tunnel to your backend
  static const String baseUrl = 'https://familyhealthbackend.loca.lt/api/v1';
  // Note: 10.0.2.2 is Android emulator's alias for localhost
  // For physical device, use your computer's local IP e.g. http://192.168.1.x:8000

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true', // Bypasses the localtunnel warning screen
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

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
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/chat/messages/'),
        headers: headers,
        body: jsonEncode({
          'conversation': conversationId,
          'content': content,
          'message_type': 'TEXT'
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- EMERGENCY API ---
  static Future<bool> triggerSOS({double? lat, double? lng}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/emergency/alerts/'),
        headers: headers,
        body: jsonEncode({
          'location_lat': lat,
          'location_lng': lng,
          'message': 'Emergency! I need help immediately from my mobile app.'
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
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
      final response = await http.post(
        Uri.parse('$baseUrl/family/groups/'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
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
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/health/records/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
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
}
