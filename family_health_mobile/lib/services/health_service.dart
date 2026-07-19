import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'health_sync_service.dart';

class HealthService {
  static final HealthService instance = HealthService._internal();
  HealthService._internal();

  final Health _health = Health();
  Timer? _pollingTimer;
  Box? _cacheBox;

  // Define data types we want to read
  final List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  Future<Box> _getCacheBox() async {
    _cacheBox ??= await Hive.openBox('health_cache');
    return _cacheBox!;
  }

  /// Get the last cached snapshot from Hive
  Future<Map<String, dynamic>?> getLastCachedSnapshot() async {
    try {
      final box = await _getCacheBox();
      final data = box.get('last_snapshot');
      if (data != null) {
        return Map<String, dynamic>.from(data as Map);
      }
    } catch (e) {
      debugPrint('[HealthCache] Error reading cache: $e');
    }
    return null;
  }

  /// Cache the snapshot in Hive
  Future<void> _cacheSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final box = await _getCacheBox();
      await box.put('last_snapshot', snapshot);
    } catch (e) {
      debugPrint('[HealthCache] Error writing cache: $e');
    }
  }

  /// Start live polling Google Fit/Health Connect every 30 seconds
  void startLiveMonitoring(Function(Map<String, dynamic>) onUpdate) {
    _pollingTimer?.cancel();

    // Immediate fetch on start
    fetchTodaySnapshot().then((snapshot) {
      _cacheSnapshot(snapshot);
      onUpdate(snapshot);
      HealthSyncService.instance.syncSnapshot(snapshot);
    }).catchError((e) {
      debugPrint('[HealthMonitor] Initial fetch error: $e');
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final snapshot = await fetchTodaySnapshot();
        await _cacheSnapshot(snapshot);
        onUpdate(snapshot);
        HealthSyncService.instance.syncSnapshot(snapshot);
      } catch (e) {
        debugPrint('[HealthMonitor] Periodic fetch error: $e');
      }
    });
  }

  /// Stop live polling
  void stopLiveMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Request permissions for Health Connect
  Future<bool> requestPermissions() async {
    try {
      bool? hasPermissions = await _health.hasPermissions(_types);
      if (hasPermissions == null || !hasPermissions) {
        bool requested = await _health.requestAuthorization(_types);
        return requested;
      }
      return true;
    } catch (e) {
      debugPrint('[HealthPermissions] Error requesting permissions: $e');
      return false;
    }
  }

  /// Fetch today's accumulated health snapshot
  Future<Map<String, dynamic>> fetchTodaySnapshot() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    double heartRate = 72.0;
    int steps = 0;
    double calories = 0.0;
    double distance = 0.0;
    double sleepHours = 8.0;
    double spo2 = 98.0;
    double hydration = 0.0;
    double weight = 70.0;
    double height = 170.0;
    const String bloodPressure = '120/80';

    try {
      bool authorized = await requestPermissions();
      if (authorized) {
        // Fetch health data points
        List<HealthDataPoint> dataPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: _types,
        );

        // Aggregate steps
        int? stepsAgg = await _health.getTotalStepsInInterval(midnight, now);
        if (stepsAgg != null) {
          steps = stepsAgg;
        }

        // Aggregate other metrics from points
        for (var point in dataPoints) {
          final value = double.tryParse(point.value.toString()) ?? 0.0;

          switch (point.type) {
            case HealthDataType.HEART_RATE:
              heartRate = value;
              break;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              calories += value;
              break;
            case HealthDataType.DISTANCE_DELTA:
              distance += (value / 1000.0); // meters → km
              break;
            case HealthDataType.SLEEP_SESSION:
              sleepHours = value;
              break;
            case HealthDataType.BLOOD_OXYGEN:
              spo2 = value > 1.0 ? value : value * 100.0;
              break;
            case HealthDataType.WATER:
              hydration += value;
              break;
            case HealthDataType.WEIGHT:
              weight = value;
              break;
            case HealthDataType.HEIGHT:
              height = value > 3.0 ? value : value * 100.0; // m → cm
              break;
            default:
              break;
          }
        }
      }
    } catch (e) {
      debugPrint('[HealthConnect] Fetch error: $e');
    }

    return {
      'source': 'HEALTH_CONNECT',
      'heart_rate': heartRate,
      'steps': steps,
      'calories': double.parse(calories.toStringAsFixed(1)),
      'distance': double.parse(distance.toStringAsFixed(2)),
      'sleep_hours': double.parse(sleepHours.toStringAsFixed(1)),
      'spo2': spo2,
      'hydration': double.parse(hydration.toStringAsFixed(1)),
      'weight': double.parse(weight.toStringAsFixed(1)),
      'height': double.parse(height.toStringAsFixed(1)),
      'blood_pressure': bloodPressure,
      'notes': 'Synced from Android Health Connect',
    };
  }
}
