import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';
import 'app_config.dart';

class HealthSyncService {
  static final HealthSyncService instance = HealthSyncService._internal();
  HealthSyncService._internal();

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
  bool _manualDisconnect = false;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connect to the health WebSocket endpoint
  Future<void> connect() async {
    if (_channel != null) return;
    _manualDisconnect = false;
    _retryCount = 0;
    await _open();
  }

  /// Disconnect the WebSocket
  void disconnect() {
    _manualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  Future<void> _open() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    final uri = Uri.parse('$_wsBase/ws/health/?token=$token');
    try {
      debugPrint('[HealthSyncWS] Connecting to health channel...');
      _channel = WebSocketChannel.connect(uri);
      // Await handshake — catches SocketException / WebSocketChannelException
      // that would otherwise surface as unhandled errors on the stream.
      await _channel!.ready;
      _channel!.stream.listen(
        (data) {
          debugPrint('[HealthSyncWS] Received: $data');
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: false,
      );
      _isConnected = true;
      _retryCount = 0;
      debugPrint('[HealthSyncWS] Connected.');
    } catch (e) {
      // Swallow connection errors silently (backend offline / no network).
      debugPrint('[HealthSyncWS] Connection failed (will retry): $e');
      _channel = null;
      _onDisconnect();
    }
  }

  void _onDisconnect() {
    _channel = null;
    _isConnected = false;
    if (_manualDisconnect) return;
    if (_retryCount >= _maxRetries) {
      debugPrint('[HealthSyncWS] Max reconnect retries reached.');
      return;
    }

    AuthService.getToken().then((token) {
      if (token == null) return;
      final delay = Duration(seconds: (1 << _retryCount).clamp(1, 30));
      _retryCount++;
      debugPrint('[HealthSyncWS] Reconnecting in ${delay.inSeconds}s...');
      Future.delayed(delay, _open);
    });
  }

  /// Sync snapshot to backend in real time
  Future<void> syncSnapshot(Map<String, dynamic> snapshot) async {
    final online = await _isNetworkAvailable();

    if (!online) {
      debugPrint('[HealthSync] Offline — queuing snapshot');
      await OfflineQueueService.instance.push(
        endpoint: '/health/snapshots/',
        method: 'POST',
        payload: snapshot,
      );
      return;
    }

    // Try WebSocket first
    if (_isConnected && _channel != null) {
      try {
        debugPrint('[HealthSync] Sending snapshot via WebSocket');
        _channel!.sink.add(jsonEncode({
          'type': 'health.vitals',
          'data': snapshot,
        }));
        return;
      } catch (e) {
        debugPrint('[HealthSync] WebSocket write failed, falling back to HTTP: $e');
      }
    }

    // HTTP fallback
    debugPrint('[HealthSync] Sending snapshot via HTTP POST');
    final res = await ApiService.postRaw('/health/snapshots/', snapshot);
    if (res == null) {
      debugPrint('[HealthSync] HTTP POST failed — queuing');
      await OfflineQueueService.instance.push(
        endpoint: '/health/snapshots/',
        method: 'POST',
        payload: snapshot,
      );
    } else {
      debugPrint('[HealthSync] Snapshot synced via HTTP');
    }
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.any((r) => r != ConnectivityResult.none);
  }
}
