import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'offline_queue_service.dart';
import 'api_service.dart';
import 'app_config.dart';

/// Real-time sync service — connects to ws/sync/?token=<jwt> and
/// broadcasts typed events to all active listeners.
///
/// Handles:
///   - Auto-reconnect with exponential back-off
///   - Connectivity detection (connectivity_plus)
///   - Offline queue flush when back online
///   - Typed event dispatch via broadcast stream
///
/// Usage:
///   await SyncService.instance.connect();
///   _sub = SyncService.instance.stream.listen((event) {
///     if (event['type'] == 'chat.message') { ... }
///   });
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  // ── Base WS URL ────────────────────────────────────────────────────────────
  static String get _apiBase => AppConfig.apiBaseUrl;
  static String get _wsBase {
    final base = AppConfig.apiBaseUrl;
    if (base.startsWith('https://')) {
      final host = base.replaceFirst('https://', '').split('/')[0];
      return 'wss://$host:443';
    } else if (base.startsWith('http://')) {
      final host = base.replaceFirst('http://', '').split('/')[0];
      if (!host.contains(':')) {
        return 'ws://$host:80';
      }
      return 'ws://$host';
    } else {
      return base.startsWith('https')
          ? base.replaceFirst('https', 'wss')
          : base.replaceFirst('http', 'ws');
    }
  }

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  StreamSubscription? _connectivitySubscription;
  bool _manualDisconnect = false;
  int _retryCount = 0;
  static const int _maxRetries = 10;
  bool _isOnline = true;

  /// Public broadcast stream — listen to receive sync events.
  Stream<Map<String, dynamic>> get stream {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  bool get isOnline => _isOnline;

  /// Initialize: connect WS + start listening for connectivity changes.
  Future<void> connect() async {
    if (_isOpen()) return;
    _manualDisconnect = false;
    _retryCount = 0;
    await _open();
    _listenConnectivity();
  }

  /// Disconnect cleanly (on logout).
  void disconnect() {
    _manualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  bool _isOpen() => _channel != null;

  Future<void> _open() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    final uri = Uri.parse('$_wsBase/ws/sync/?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      // Await handshake — catches SocketException / WebSocketChannelException
      // that would otherwise surface as unhandled errors on the stream.
      await _channel!.ready;
      _channel!.stream.listen(
        (data) {
          try {
            final event = jsonDecode(data as String) as Map<String, dynamic>;
            _controller ??= StreamController<Map<String, dynamic>>.broadcast();
            _controller!.add(event);
          } catch (_) {}
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: false,
      );
      _retryCount = 0;
    } catch (e) {
      // Swallow connection errors (host unreachable, no network, etc.)
      // _onDisconnect will schedule a retry with exponential back-off.
      _channel = null;
      _onDisconnect();
    }
  }

  void _onDisconnect() {
    _channel = null;
    if (_manualDisconnect) return;
    if (_retryCount >= _maxRetries) return;

    AuthService.getToken().then((token) {
      if (token == null) return;
      final delay = Duration(seconds: (1 << _retryCount).clamp(1, 30));
      _retryCount++;
      Future.delayed(delay, _open);
    });
  }

  void _listenConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      _isOnline = online;

      if (online && wasOffline) {
        // Back online — reconnect WS
        if (!_isOpen()) {
          _retryCount = 0;
          await _open();
        }
        // Flush offline queue
        if (OfflineQueueService.instance.hasPending) {
          final flushed = await OfflineQueueService.instance.flush(
            (endpoint, body) => ApiService.postRaw(endpoint, body),
          );
          if (flushed) {
            // Notify listeners that sync completed
            _controller?.add({'type': 'sync.flushed', 'data': {}});
          }
        }
      }
    });
  }
}
