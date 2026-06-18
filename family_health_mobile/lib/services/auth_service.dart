import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _usernameKey = 'username';
  static const String _userIdKey = 'user_id';
  static const String _authProviderKey = 'auth_provider';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> saveToken({
    required String token,
    required String username,
    required String userId,
    String authProvider = 'django',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_authProviderKey, authProvider);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey) ?? 'User';
  }

  static Future<String?> getAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authProviderKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
