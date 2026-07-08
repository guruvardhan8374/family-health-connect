import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

/// Real-time sync service — connects to the backend ws/sync/ endpoint
/// and broadcasts typed events to all active listeners.
///
/// Usage:
///   // Start in main.dart after login
///   SyncService.instance.connect();
///
///   // Listen in any widget's initState
///   _sub = SyncService.instance.stream.listen((event) {
///     if (event['type'] == 'settings.update' && event['section'] == 'theme') {
///       ThemeController.instance.loadTheme();
///     }
///   });
///
///   // Cancel in dispose()
///   _sub.cancel();

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  // ── Base WS URL (mirrors ApiService.baseUrl but ws(s)) ────────────────────
  static const String _apiBase = 'http://192.168.1.6:8000';
  static String get _wsBase {
    return _apiBase.startsWith('https')
        ? _apiBase.replaceFirst('https', 'wss')
        : _apiBase.replaceFirst('http', 'ws');
  }

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  bool _manualDisconnect = false;
  int _retryCount = 0;
  static const int _maxRetries = 10;

  /// Public broadcast stream — listen to receive sync events.
  Stream<Map<String, dynamic>> get stream {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  /// Connect (or reconnect) to the sync WebSocket.
  /// Call after login. Safe to call multiple times — will no-op if already open.
  Future<void> connect() async {
    if (_isOpen()) return;
    _manualDisconnect = false;
    _retryCount = 0;
    await _open();
  }

  /// Disconnect cleanly (e.g. on logout).
  void disconnect() {
    _manualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
  }

  bool _isOpen() {
    return _channel != null;
  }

  Future<void> _open() async {
    final token = await AuthService.getToken();
    if (token == null) return; // Not logged in — do not attempt connection

    final uri = Uri.parse('$_wsBase/ws/sync/?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final event = jsonDecode(data as String) as Map<String, dynamic>;
            _controller ??= StreamController<Map<String, dynamic>>.broadcast();
            _controller!.add(event);
          } catch (_) {
            // Ignore malformed frames
          }
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: false,
      );
      _retryCount = 0;
    } catch (e) {
      _onDisconnect();
    }
  }

  void _onDisconnect() {
    _channel = null;
    if (_manualDisconnect) return;
    if (_retryCount >= _maxRetries) return;

    // Check if we still have a token before retrying
    AuthService.getToken().then((token) {
      if (token == null) return; // No token — stop retrying
      final delay = Duration(seconds: (1 << _retryCount).clamp(1, 30));
      _retryCount++;
      Future.delayed(delay, _open);
    });
  }
}
