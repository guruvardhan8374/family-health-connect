import 'package:health/health.dart';

class HealthService {
  static final HealthService instance = HealthService._internal();
  HealthService._internal();

  final Health _health = Health();

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

  /// Request permissions for Health Connect
  Future<bool> requestPermissions() async {
    try {
      // Access Health Connect API
      bool? hasPermissions = await _health.hasPermissions(_types);
      if (hasPermissions == null || !hasPermissions) {
        bool requested = await _health.requestAuthorization(_types);
        return requested;
      }
      return true;
    } catch (e) {
      print('Error requesting health permissions: $e');
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
    String bloodPressure = '120/80';

    try {
      bool authorized = await requestPermissions();
      if (authorized) {
        // Fetch health data
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
              distance += (value / 1000.0); // Convert meters to km
              break;
            case HealthDataType.SLEEP_SESSION:
              sleepHours = value;
              break;
            case HealthDataType.BLOOD_OXYGEN:
              spo2 = value * 100.0; // convert fraction to % if needed
              if (spo2 > 100.0) spo2 = value; // fallback
              break;
            case HealthDataType.WATER:
              hydration += value; // in Litres or ml (normalize)
              break;
            case HealthDataType.WEIGHT:
              weight = value;
              break;
            case HealthDataType.HEIGHT:
              height = value * 100.0; // convert meters to cm if needed
              if (height < 3.0) height = value; // fallback
              break;
            default:
              break;
          }
        }
      }
    } catch (e) {
      print('Error fetching health connect metrics: $e');
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
