import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'health_sync_service.dart';

// ── The four core data types required by the Health Hub screen ───────────────
const List<HealthDataType> _coreTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.SLEEP_ASLEEP, // maps to SLEEP_IN_BED on iOS < 16
];

// ── Extended types for the full snapshot (dashboard / sync) ─────────────────
const List<HealthDataType> _allTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.WATER,
  HealthDataType.WEIGHT,
  HealthDataType.HEIGHT,
];

/// HealthService — singleton wrapper around the `health` package.
///
/// Usage:
///   await HealthService.instance.requestPermissions();     // ask OS
///   final m = await HealthService.instance.fetchTodayMetrics(); // read data
class HealthService {
  static final HealthService instance = HealthService._internal();
  HealthService._internal();

  final Health _health = Health();
  Timer? _pollingTimer;
  Box? _cacheBox;

  // ── Permission helpers ───────────────────────────────────────────────────

  /// Returns the list of [HealthDataAccess] values matching [types].
  /// health v11 requires explicit READ/READ_WRITE per type.
  List<HealthDataAccess> _readAccess(List<HealthDataType> types) =>
      types.map((_) => HealthDataAccess.READ).toList();

  // ── Cache ────────────────────────────────────────────────────────────────

  Future<Box> _getCacheBox() async {
    _cacheBox ??= await Hive.openBox('health_cache');
    return _cacheBox!;
  }

  /// Returns the last cached snapshot, or null if nothing is cached yet.
  Future<Map<String, dynamic>?> getLastCachedSnapshot() async {
    try {
      final box = await _getCacheBox();
      final data = box.get('last_snapshot');
      if (data != null) return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('[HealthCache] read error: $e');
    }
    return null;
  }

  Future<void> _cacheSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final box = await _getCacheBox();
      await box.put('last_snapshot', snapshot);
    } catch (e) {
      debugPrint('[HealthCache] write error: $e');
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Requests READ access for the four core health metrics:
  ///   HEART_RATE · STEPS · BLOOD_OXYGEN · SLEEP_ASLEEP
  ///
  /// Returns `true` if all permissions were granted.
  ///
  /// On Android this opens the Health Connect permission sheet.
  /// On iOS this opens the Apple Health permission sheet.
  Future<bool> requestPermissions() async {
    try {
      // health v11: use requestAuthorization(types, permissions:) overload
      final granted = await _health.requestAuthorization(
        _coreTypes,
        permissions: _readAccess(_coreTypes),
      );
      debugPrint('[HealthPermissions] Core permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[HealthPermissions] requestPermissions error: $e');
      return false;
    }
  }

  /// Requests READ access for all supported metrics (used by the dashboard).
  Future<bool> requestAllPermissions() async {
    try {
      final granted = await _health.requestAuthorization(
        _allTypes,
        permissions: _readAccess(_allTypes),
      );
      debugPrint('[HealthPermissions] All permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[HealthPermissions] requestAllPermissions error: $e');
      return false;
    }
  }

  /// Returns `true` if the four core permissions have already been granted.
  Future<bool> hasPermissions() async {
    try {
      final result = await _health.hasPermissions(
        _coreTypes,
        permissions: _readAccess(_coreTypes),
      );
      return result == true;
    } catch (e) {
      debugPrint('[HealthPermissions] hasPermissions error: $e');
      return false;
    }
  }

  // ── Core metric fetch (Health Hub screen) ────────────────────────────────

  /// Fetches the four core metrics for TODAY and returns them as a Map:
  ///
  /// ```dart
  /// {
  ///   'heart_rate':  double,   // latest bpm, 0.0 if unavailable
  ///   'steps':       int,      // total steps since midnight
  ///   'blood_oxygen': double,  // latest SpO₂ %, 0.0 if unavailable
  ///   'sleep_hours': double,   // total sleep hours from last night (22:00–now)
  /// }
  /// ```
  Future<Map<String, dynamic>> fetchTodayMetrics() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    // Sleep window: from 22:00 yesterday to now (captures overnight sleep)
    final sleepWindowStart = midnight.subtract(const Duration(hours: 2));

    double heartRate  = 0.0;
    int    steps      = 0;
    double bloodOxygen = 0.0;
    double sleepHours = 0.0;

    try {
      final authorized = await hasPermissions();
      if (!authorized) {
        debugPrint('[HealthMetrics] Permissions not granted — returning zeros');
        return _metricsMap(heartRate, steps, bloodOxygen, sleepHours);
      }

      // ── Heart Rate: latest reading today ──────────────────────────────
      final hrPoints = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      if (hrPoints.isNotEmpty) {
        // Sort descending by date, take the most recent value
        hrPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        heartRate = _toDouble(hrPoints.first.value);
      }

      // ── Steps: aggregated total since midnight ────────────────────────
      final totalSteps = await _health.getTotalStepsInInterval(midnight, now);
      steps = totalSteps ?? 0;

      // ── Blood Oxygen: latest reading today ───────────────────────────
      final spo2Points = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.BLOOD_OXYGEN],
      );
      if (spo2Points.isNotEmpty) {
        spo2Points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final raw = _toDouble(spo2Points.first.value);
        // Health Connect stores as fraction (0–1) on some devices; normalise
        bloodOxygen = raw <= 1.0 && raw > 0 ? raw * 100.0 : raw;
      }

      // ── Sleep: total SLEEP_ASLEEP minutes from last night window ─────
      final sleepPoints = await _health.getHealthDataFromTypes(
        startTime: sleepWindowStart,
        endTime: now,
        types: [HealthDataType.SLEEP_ASLEEP],
      );
      double totalSleepMinutes = 0.0;
      for (final pt in sleepPoints) {
        final durationMinutes =
            pt.dateTo.difference(pt.dateFrom).inMinutes.toDouble();
        totalSleepMinutes += durationMinutes;
      }
      sleepHours = double.parse((totalSleepMinutes / 60).toStringAsFixed(1));
    } catch (e) {
      debugPrint('[HealthMetrics] fetchTodayMetrics error: $e');
    }

    return _metricsMap(heartRate, steps, bloodOxygen, sleepHours);
  }

  /// Fetches core metrics and POSTs JSON to the Vercel backend endpoint.
  /// Includes the current user's ID in the payload.
  Future<bool> syncMetricsToVercel() async {
    try {
      final metrics = await fetchTodayMetrics();
      final userId = await AuthService.getUserId();

      final payload = {
        'user_id': userId,
        'heart_rate': metrics['heart_rate'],
        'steps': metrics['steps'],
        'blood_oxygen': metrics['blood_oxygen'],
        'sleep_hours': metrics['sleep_hours'],
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('[HealthSync] POSTing metrics to Vercel API: $payload');

      final response = await http.post(
        Uri.parse('https://family-health-connect-7mwd.vercel.app/api/health-sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[HealthSync] Vercel API status: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HealthSync] Vercel API sync error: $e');
      return false;
    }
  }

  Map<String, dynamic> _metricsMap(
    double heartRate,
    int steps,
    double bloodOxygen,
    double sleepHours,
  ) =>
      {
        'heart_rate':   heartRate,
        'steps':        steps,
        'blood_oxygen': bloodOxygen,
        'sleep_hours':  sleepHours,
      };

  double _toDouble(dynamic value) =>
      double.tryParse(value.toString()) ?? 0.0;

  // ── Full snapshot (dashboard / sync) ─────────────────────────────────────

  /// Fetches all supported metrics for today.
  /// Used by [startLiveMonitoring] and the health dashboard.
  Future<Map<String, dynamic>> fetchTodaySnapshot() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final sleepWindowStart = midnight.subtract(const Duration(hours: 2));

    double heartRate   = 72.0;
    int    steps       = 0;
    double calories    = 0.0;
    double distance    = 0.0;
    double sleepHours  = 8.0;
    double spo2        = 98.0;
    double hydration   = 0.0;
    double weight      = 70.0;
    double height      = 170.0;
    const bloodPressure = '120/80';

    try {
      final authorized = await requestAllPermissions();
      if (authorized) {
        // Aggregated steps
        final totalSteps = await _health.getTotalStepsInInterval(midnight, now);
        if (totalSteps != null) steps = totalSteps;

        // All other data points
        final dataPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: _allTypes,
        );

        // Sleep points use a different window
        final sleepPoints = await _health.getHealthDataFromTypes(
          startTime: sleepWindowStart,
          endTime: now,
          types: [HealthDataType.SLEEP_ASLEEP],
        );

        double totalSleepMinutes = 0.0;
        for (final pt in sleepPoints) {
          totalSleepMinutes +=
              pt.dateTo.difference(pt.dateFrom).inMinutes.toDouble();
        }
        if (totalSleepMinutes > 0) {
          sleepHours = double.parse((totalSleepMinutes / 60).toStringAsFixed(1));
        }

        for (final point in dataPoints) {
          final value = _toDouble(point.value);
          switch (point.type) {
            case HealthDataType.HEART_RATE:
              heartRate = value;
            case HealthDataType.BLOOD_OXYGEN:
              spo2 = value <= 1.0 && value > 0 ? value * 100.0 : value;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              calories += value;
            case HealthDataType.DISTANCE_DELTA:
              distance += value / 1000.0; // m → km
            case HealthDataType.WATER:
              hydration += value;
            case HealthDataType.WEIGHT:
              weight = value;
            case HealthDataType.HEIGHT:
              height = value > 3.0 ? value : value * 100.0; // m → cm
            default:
              break;
          }
        }
      }
    } catch (e) {
      debugPrint('[HealthConnect] fetchTodaySnapshot error: $e');
    }

    return {
      'source':          Platform.isIOS ? 'HEALTHKIT' : 'HEALTH_CONNECT',
      'heart_rate':      heartRate,
      'steps':           steps,
      'calories':        double.parse(calories.toStringAsFixed(1)),
      'distance':        double.parse(distance.toStringAsFixed(2)),
      'sleep_hours':     double.parse(sleepHours.toStringAsFixed(1)),
      'spo2':            spo2,
      'hydration':       double.parse(hydration.toStringAsFixed(1)),
      'weight':          double.parse(weight.toStringAsFixed(1)),
      'height':          double.parse(height.toStringAsFixed(1)),
      'blood_pressure':  bloodPressure,
      'notes':           Platform.isIOS
          ? 'Synced from Apple HealthKit'
          : 'Synced from Android Health Connect',
    };
  }

  // ── Live monitoring (30-second polling for dashboard) ────────────────────

  void startLiveMonitoring(Function(Map<String, dynamic>) onUpdate) {
    _pollingTimer?.cancel();

    // Immediate fetch
    fetchTodaySnapshot().then((snapshot) {
      _cacheSnapshot(snapshot);
      onUpdate(snapshot);
      HealthSyncService.instance.syncSnapshot(snapshot);
    }).catchError((Object e) {
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

  void stopLiveMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
