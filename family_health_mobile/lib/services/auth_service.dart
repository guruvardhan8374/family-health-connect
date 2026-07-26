import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey       = 'access_token';
  static const String _refreshKey     = 'refresh_token';
  static const String _usernameKey    = 'username';
  static const String _userIdKey      = 'user_id';
  static const String _emailKey       = 'email';
  static const String _roleKey        = 'role';
  static const String _profilePicKey  = 'profile_picture';
  static const String _phoneKey       = 'phone_number';
  static const String _bioKey         = 'bio';
  static const String _authProviderKey = 'auth_provider';

  // ── Singleton SharedPreferences instance — loaded once, never again ──────
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Auth state notifier for reactive UI navigation (Login vs MainShell) ──
  static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);

  // ── In-memory cache for the most-accessed fields (zero I/O on hot path) ──
  static String? _cachedToken;
  static String? _cachedUsername;
  static String? _cachedUserId;
  static String? _cachedEmail;
  static String? _cachedRole;

  static Future<bool> isLoggedIn() async {
    if (_cachedToken != null) {
      final valid = _cachedToken!.isNotEmpty;
      isLoggedInNotifier.value = valid;
      return valid;
    }
    final prefs = await _getPrefs();
    _cachedToken = prefs.getString(_tokenKey);
    final valid = _cachedToken != null && _cachedToken!.isNotEmpty;
    isLoggedInNotifier.value = valid;
    return valid;
  }

  /// Save JWT token + basic identity fields in one prefs instance.
  static Future<void> saveToken({
    required String token,
    required String username,
    required String userId,
    String authProvider = 'django',
    String? refreshToken,
  }) async {
    // Update in-memory cache immediately (instant reads after this)
    _cachedToken    = token;
    _cachedUsername = username;
    _cachedUserId   = userId;

    final prefs = await _getPrefs();
    await Future.wait([
      prefs.setString(_tokenKey,       token),
      prefs.setString(_usernameKey,    username),
      prefs.setString(_userIdKey,      userId),
      prefs.setString(_authProviderKey, authProvider),
      if (refreshToken != null) prefs.setString(_refreshKey, refreshToken),
    ]);

    // Clear all memory caches on login to drop any stale data from previous sessions
    ApiService.clearAllCaches();

    isLoggedInNotifier.value = true;
  }

  /// Save full profile from the login token response — no extra API call needed.
  static Future<void> saveProfile({
    required String email,
    required String role,
    String profilePicture = '',
    String phoneNumber    = '',
    String bio            = '',
  }) async {
    _cachedEmail = email;
    _cachedRole  = role;

    final prefs = await _getPrefs();
    await Future.wait([
      prefs.setString(_emailKey,      email),
      prefs.setString(_roleKey,       role),
      prefs.setString(_profilePicKey, profilePicture),
      prefs.setString(_phoneKey,      phoneNumber),
      prefs.setString(_bioKey,        bio),
    ]);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await _getPrefs();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_refreshKey);
  }

  /// Atomically updates access token (and optional rotated refresh token) in memory and disk
  static Future<void> updateAccessToken(String newToken, {String? newRefreshToken}) async {
    _cachedToken = newToken;
    final prefs = await _getPrefs();
    await prefs.setString(_tokenKey, newToken);
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      await prefs.setString(_refreshKey, newRefreshToken);
    }
  }

  static Future<String> getUsername() async {
    if (_cachedUsername != null) return _cachedUsername!;
    final prefs = await _getPrefs();
    _cachedUsername = prefs.getString(_usernameKey) ?? 'User';
    return _cachedUsername!;
  }

  static Future<String> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;
    final prefs = await _getPrefs();
    _cachedUserId = prefs.getString(_userIdKey) ?? '';
    return _cachedUserId!;
  }

  static Future<String> getEmail() async {
    if (_cachedEmail != null) return _cachedEmail!;
    final prefs = await _getPrefs();
    _cachedEmail = prefs.getString(_emailKey) ?? '';
    return _cachedEmail!;
  }

  static Future<String> getRole() async {
    if (_cachedRole != null) return _cachedRole!;
    final prefs = await _getPrefs();
    _cachedRole = prefs.getString(_roleKey) ?? 'MEMBER';
    return _cachedRole!;
  }

  static Future<String> getProfilePicture() async {
    final prefs = await _getPrefs();
    return prefs.getString(_profilePicKey) ?? '';
  }

  static Future<String?> getAuthProvider() async {
    final prefs = await _getPrefs();
    return prefs.getString(_authProviderKey);
  }

  static Future<void> logout() async {
    // Clear in-memory cache
    _cachedToken    = null;
    _cachedUsername = null;
    _cachedUserId   = null;
    _cachedEmail    = null;
    _cachedRole     = null;

    final prefs = await _getPrefs();
    await prefs.clear();
    
    // Clear all memory caches on logout
    ApiService.clearAllCaches();

    isLoggedInNotifier.value = false;
  }
}

