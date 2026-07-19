import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed offline queue that stores pending REST mutations
/// and flushes them automatically when connectivity is restored.
///
/// Each entry is a Map with:
///   { 'endpoint': String, 'method': String, 'payload': Map, 'client_timestamp': String }
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._internal();
  OfflineQueueService._internal();

  static const String _boxName = 'offline_queue';
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _getBox {
    if (_box == null) throw StateError('OfflineQueueService not initialized. Call init() first.');
    return _box!;
  }

  /// Add a mutation to the queue.
  Future<void> push({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final entry = {
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'client_timestamp': DateTime.now().toIso8601String(),
    };
    await _getBox.add(jsonEncode(entry));
  }

  /// Get all pending mutations.
  List<Map<String, dynamic>> getAll() {
    return _getBox.values
        .map((e) => Map<String, dynamic>.from(jsonDecode(e as String)))
        .toList();
  }

  /// Clear the queue.
  Future<void> clear() async {
    await _getBox.clear();
  }

  bool get hasPending => _getBox.isNotEmpty;

  int get pendingCount => _getBox.length;

  /// Flush the queue by POSTing to /api/v1/sync/pending/.
  /// Returns true if all mutations were applied successfully.
  Future<bool> flush(Future<dynamic> Function(String endpoint, dynamic body) postFn) async {
    if (!hasPending) return true;

    final mutations = getAll();
    try {
      final result = await postFn('/sync/pending/', {
        'mutations': mutations,
      });

      final failed = (result?['failed'] ?? 0) as int;
      if (failed == 0) {
        await clear();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
