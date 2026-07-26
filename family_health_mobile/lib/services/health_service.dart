import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';
import 'health_sync_service.dart';
import 'app_config.dart';
import 'package:url_launcher/url_launcher.dart';

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
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.WATER,
  HealthDataType.WEIGHT,
  HealthDataType.HEIGHT,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.RESPIRATORY_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.WORKOUT,
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

  Future<bool> isPermissionDismissedOrGranted() async {
    try {
      final box = await _getCacheBox();
      return (box.get('perm_dismissed_or_granted') as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPermissionDismissedOrGranted(bool value) async {
    try {
      final box = await _getCacheBox();
      await box.put('perm_dismissed_or_granted', value);
    } catch (e) {
      debugPrint('[HealthService] setPermissionDismissedOrGranted error: $e');
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Requests READ access for all required health metrics.
  ///
  /// On Android this checks Health Connect status first. If missing, opens Play Store.
  /// Otherwise opens official Health Connect permission sheet.
  Future<bool> requestPermissions() async {
    // Always mark permission prompt as dismissed/handled so it doesn't loop
    await setPermissionDismissedOrGranted(true);
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await getHealthConnectStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
            status == HealthConnectSdkStatus.sdkUnavailable) {
          debugPrint('[HealthPermissions] Health Connect not installed. Launching Play Store...');
          await installHealthConnect();
          return false;
        }
      }

      final granted = await _health.requestAuthorization(
        _coreTypes,
        permissions: _readAccess(_coreTypes),
      );
      debugPrint('[HealthPermissions] Core permissions granted: $granted');
      return granted == true;
    } catch (e) {
      debugPrint('[HealthPermissions] requestPermissions error: $e');
      return false;
    }
  }

  /// Requests READ access for all supported metrics (used by settings).
  Future<bool> requestAllPermissions() async {
    return await requestPermissions();
  }

  /// Returns `true` if core permissions have already been granted.
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

    double? heartRate;
    int?    steps;
    double? bloodOxygen;
    double? sleepHours;

    try {
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
      if (totalSteps != null && totalSteps > 0) {
        steps = totalSteps;
      }

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
      if (totalSleepMinutes > 0) {
        sleepHours = double.parse((totalSleepMinutes / 60).toStringAsFixed(1));
      }
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

      debugPrint('[HealthSync] POSTing metrics to local Django API: $payload');

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/health-sync/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[HealthSync] Local API status: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HealthSync] Local API sync error: $e');
      return false;
    }
  }

  Map<String, dynamic> _metricsMap(
    double? heartRate,
    int? steps,
    double? bloodOxygen,
    double? sleepHours,
  ) =>
      {
        'heart_rate':   heartRate,
        'steps':        steps,
        'blood_oxygen': bloodOxygen,
        'sleep_hours':  sleepHours,
      };

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    final str = value.toString();
    // Handles String formats like "NumericHealthValue(numericValue: 75.0)" or raw numbers
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(str);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }
    return 0.0;
  }

  // ── Full snapshot (dashboard / sync) ─────────────────────────────────────

  /// Fetches all supported metrics for today.
  /// Used by [startLiveMonitoring] and the health dashboard.
  Future<Map<String, dynamic>> fetchTodaySnapshot() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final sleepWindowStart = midnight.subtract(const Duration(hours: 12));

    double? heartRate;
    double? restingHeartRate;
    double? heartRateVariability;
    int?    steps;
    double? calories;
    double? totalCalories;
    double? distance;
    double? floorsClimbed;
    double? sleepHours;
    double? spo2;
    double? hydration;
    double? weight;
    double? height;
    double? bodyFatPct;
    double? respiratoryRate;

    double? bpSystolic;
    double? bpDiastolic;
    double? sleepLight;
    double? sleepDeep;
    double? sleepRem;
    double? sleepAwake;
    double? bodyFat;
    int?    exerciseCount;
    int?    workoutMinutes;
    String? workoutType;
    String  deviceName = 'Mobile Device';
    try {
      // ── Query STEPS specifically: reliable Health Connect / Google Fit step extraction ──
      try {
        // 1. First query Health Connect native aggregate step count (Google Fit writes aggregate steps here)
        final totalDeduplicatedSteps = await _health.getTotalStepsInInterval(midnight, now);
        if (totalDeduplicatedSteps != null && totalDeduplicatedSteps > 0 && totalDeduplicatedSteps < 50000) {
          steps = totalDeduplicatedSteps;
          debugPrint('[HealthService] Native Health Connect total steps: $steps');
        }

          // 2. Query individual raw step data points
          final stepPoints = await _health.getHealthDataFromTypes(
            startTime: midnight,
            endTime: now,
            types: [HealthDataType.STEPS],
          );

          Map<String, int> appSums = {};
          int totalValidIntervalSteps = 0;

          for (final pt in stepPoints) {
            final val = _toDouble(pt.value).toInt();
            final durationHours = pt.dateTo.difference(pt.dateFrom).inHours;
            final src = '${pt.sourceId} ${pt.sourceName}'.toLowerCase();

            // Ignore single cumulative boot entries (>25,000 or >4h duration)
            if (val > 25000 || durationHours >= 4) {
              debugPrint('[HealthService] Ignoring cumulative boot step record: $val steps (duration: ${durationHours}h, source: $src)');
              continue;
            }

            if (val > 0) {
              appSums[src] = (appSums[src] ?? 0) + val;
              totalValidIntervalSteps += val;
            }
          }

          // Check specifically for Google Fit source ("fitness", "fit", "google")
          int? googleFitSteps;
          for (final entry in appSums.entries) {
            if (entry.key.contains('fit') || entry.key.contains('google') || entry.key.contains('com.google.android.apps.fitness')) {
              googleFitSteps = (googleFitSteps ?? 0) + entry.value;
            }
          }

          if (googleFitSteps != null && googleFitSteps > 0) {
            steps = googleFitSteps;
            debugPrint('[HealthService] Matched Google Fit raw steps: $steps');
          } else if ((steps == null || steps == 0) && appSums.isNotEmpty) {
            final validSums = appSums.values.where((v) => v > 0 && v < 50000).toList();
            if (validSums.isNotEmpty) {
              steps = validSums.reduce((a, b) => a > b ? a : b);
            }
          } else if ((steps == null || steps == 0) && totalValidIntervalSteps > 0) {
            steps = totalValidIntervalSteps;
          }
        } catch (e) {
          debugPrint('[HealthService] Error parsing step interval points: $e');
        }

        // ── Query each health metric individually in safe try/catch blocks ──
        Future<List<HealthDataPoint>> safeQuery(HealthDataType type) async {
          try {
            return await _health.getHealthDataFromTypes(
              startTime: midnight,
              endTime: now,
              types: [type],
            );
          } catch (e) {
            debugPrint('[HealthService] safeQuery error for $type: $e');
            return [];
          }
        }

        // Heart Rate
        final hrPoints = await safeQuery(HealthDataType.HEART_RATE);
        if (hrPoints.isNotEmpty) {
          hrPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(hrPoints.first.value);
          if (val > 0) heartRate = val;
        }

        // Blood Oxygen
        final spo2Points = await safeQuery(HealthDataType.BLOOD_OXYGEN);
        if (spo2Points.isNotEmpty) {
          spo2Points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(spo2Points.first.value);
          if (val > 0) spo2 = val <= 1.0 ? val * 100.0 : val;
        }

        // Active Energy Burned
        final calPoints = await safeQuery(HealthDataType.ACTIVE_ENERGY_BURNED);
        for (final pt in calPoints) {
          final val = _toDouble(pt.value);
          if (val > 0) calories = (calories ?? 0) + val;
        }

        // Distance
        final distPoints = await safeQuery(HealthDataType.DISTANCE_DELTA);
        for (final pt in distPoints) {
          final val = _toDouble(pt.value);
          if (val > 0) distance = (distance ?? 0) + (val / 1000.0);
        }

        // Hydration
        final waterPoints = await safeQuery(HealthDataType.WATER);
        for (final pt in waterPoints) {
          final val = _toDouble(pt.value);
          if (val > 0) hydration = (hydration ?? 0) + val;
        }

        // Weight
        final weightPoints = await safeQuery(HealthDataType.WEIGHT);
        if (weightPoints.isNotEmpty) {
          weightPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(weightPoints.first.value);
          if (val > 0) weight = val;
        }

        // Height
        final heightPoints = await safeQuery(HealthDataType.HEIGHT);
        if (heightPoints.isNotEmpty) {
          heightPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(heightPoints.first.value);
          if (val > 0) height = val > 3.0 ? val : val * 100.0;
        }

        // Resting Heart Rate
        final rhrPoints = await safeQuery(HealthDataType.RESTING_HEART_RATE);
        if (rhrPoints.isNotEmpty) {
          rhrPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(rhrPoints.first.value);
          if (val > 0) restingHeartRate = val;
        }

        // Heart Rate Variability
        final hrvPoints = await safeQuery(HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
        if (hrvPoints.isNotEmpty) {
          hrvPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(hrvPoints.first.value);
          if (val > 0) heartRateVariability = val;
        }

        // Respiratory Rate
        final respPoints = await safeQuery(HealthDataType.RESPIRATORY_RATE);
        if (respPoints.isNotEmpty) {
          respPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(respPoints.first.value);
          if (val > 0) respiratoryRate = val;
        }

        // VO2 Max — not available in health 11.1.1 on Android Health Connect
        // final vo2Points = await safeQuery(HealthDataType.VO2MAX);

        // Basal Metabolic Rate — not available in health 11.1.1 on Android Health Connect
        // final bmrPoints = await safeQuery(HealthDataType.BASAL_METABOLIC_RATE);

        // Total Calories (Basal + Active)
        final totalCalPoints = await safeQuery(HealthDataType.TOTAL_CALORIES_BURNED);
        for (final pt in totalCalPoints) {
          final val = _toDouble(pt.value);
          if (val > 0) totalCalories = (totalCalories ?? 0) + val;
        }

        // Flights Climbed (floors)
        final floorsPoints = await safeQuery(HealthDataType.FLIGHTS_CLIMBED);
        for (final pt in floorsPoints) {
          final val = _toDouble(pt.value);
          if (val > 0) floorsClimbed = (floorsClimbed ?? 0) + val;
        }

        // Body Fat Percentage
        final bodyFatPoints = await safeQuery(HealthDataType.BODY_FAT_PERCENTAGE);
        if (bodyFatPoints.isNotEmpty) {
          bodyFatPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final val = _toDouble(bodyFatPoints.first.value);
          // Health Connect stores body fat as 0.0–1.0 fraction on some devices
          if (val > 0) bodyFatPct = val > 1.0 ? val : val * 100.0;
        }

        // Workout / Exercise Sessions
        final workoutPoints = await safeQuery(HealthDataType.WORKOUT);
        if (workoutPoints.isNotEmpty) {
          exerciseCount = workoutPoints.length;
          int totalMin = 0;
          for (final pt in workoutPoints) {
            totalMin += pt.dateTo.difference(pt.dateFrom).inMinutes;
          }
          workoutMinutes = totalMin;
          // Use the most recent workout type
          workoutPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final wv = workoutPoints.first.value;
          workoutType = wv.toString().replaceAll('WorkoutHealthValue(', '').replaceAll(')', '').split(',').first;
        }
    } catch (e) {
      debugPrint('[HealthConnect] fetchTodaySnapshot error: $e');
    }

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    double? bmi;
    if (weight != null && weight > 0 && height != null && height > 0) {
      double heightMeters = height / 100.0;
      bmi = double.parse((weight / (heightMeters * heightMeters)).toStringAsFixed(1));
    }

    String? bloodPressure;
    if (bpSystolic != null && bpDiastolic != null && bpSystolic > 0 && bpDiastolic > 0) {
      bloodPressure = '${bpSystolic.toInt()}/${bpDiastolic.toInt()}';
    }

    return {
      'source':               isIOS ? 'HEALTHKIT' : (kIsWeb ? 'WEB_HEALTH' : 'HEALTH_CONNECT'),
      'heart_rate':           heartRate,
      'resting_heart_rate':   restingHeartRate,
      'hrv':                  heartRateVariability,
      'steps':                steps,
      'calories':             calories != null ? double.parse(calories.toStringAsFixed(1)) : null,
      'total_calories':       totalCalories != null ? double.parse(totalCalories.toStringAsFixed(1)) : null,
      'distance':             distance != null ? double.parse(distance.toStringAsFixed(2)) : null,
      'floors_climbed':       floorsClimbed != null ? double.parse(floorsClimbed.toStringAsFixed(0)) : null,
      'sleep_hours':          sleepHours != null ? double.parse(sleepHours.toStringAsFixed(1)) : null,
      'spo2':                 spo2,
      'hydration':            hydration != null ? double.parse(hydration.toStringAsFixed(1)) : null,
      'weight':               weight != null ? double.parse(weight.toStringAsFixed(1)) : null,
      'height':               height != null ? double.parse(height.toStringAsFixed(1)) : null,
      'body_fat_pct':         bodyFatPct != null ? double.parse(bodyFatPct.toStringAsFixed(1)) : null,
      'respiratory_rate':     respiratoryRate != null ? double.parse(respiratoryRate.toStringAsFixed(1)) : null,
      'vo2_max':              null, // not available in health 11.1.1
      'bmr':                  null, // not available in health 11.1.1
      'blood_pressure':       bloodPressure,
      'sleep_light':          sleepLight != null ? double.parse(sleepLight.toStringAsFixed(1)) : null,
      'sleep_deep':           sleepDeep != null ? double.parse(sleepDeep.toStringAsFixed(1)) : null,
      'sleep_rem':            sleepRem != null ? double.parse(sleepRem.toStringAsFixed(1)) : null,
      'sleep_awake':          sleepAwake != null ? double.parse(sleepAwake.toStringAsFixed(1)) : null,
      'body_fat':             bodyFat != null ? double.parse(bodyFat.toStringAsFixed(1)) : null,
      'exercise_count':       exerciseCount,
      'workout_minutes':      workoutMinutes,
      'workout_type':         workoutType,
      'device_name':          deviceName,
      'bmi':                  bmi,
      'notes':                isIOS
          ? 'Synced from Apple HealthKit'
          : (kIsWeb ? 'Synced from Web Health Portal' : 'Synced from Android Health Connect'),
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

  /// Returns the availability status of Android Health Connect
  Future<HealthConnectSdkStatus?> getHealthConnectStatus() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _health.getHealthConnectSdkStatus();
    } catch (_) {
      return null;
    }
  }

  /// Opens the Play Store to install Google Health Connect
  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {
      final url = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Opens the Health Connect permission settings screen or general app settings
  Future<bool> openHealthConnectSettings() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final uri = Uri.parse('package:com.google.android.apps.healthdata');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }
      return await openAppSettings();
    } catch (e) {
      debugPrint('[HealthService] openHealthConnectSettings error: $e');
      return await openAppSettings();
    }
  }

  /// Revoke all health permissions granted to the application
  Future<void> revokeAccess() async {
    try {
      await _health.revokePermissions();
      await setPermissionDismissedOrGranted(false);
      debugPrint('[HealthService] Permissions revoked successfully.');
    } catch (e) {
      debugPrint('[HealthService] Failed to revoke permissions: $e');
    }
  }
}
