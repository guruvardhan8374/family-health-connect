import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class PedometerService {
  static final PedometerService instance = PedometerService._internal();
  PedometerService._internal();

  StreamSubscription<StepCount>? _subscription;
  int? _initialSteps;
  int _lastSentSteps = 0;
  bool _isSimulating = false;
  Timer? _simulationTimer;

  /// Request permissions and initialize step listener
  Future<void> init() async {
    try {
      // Request Activity Recognition permissions on Android
      final status = await Permission.activityRecognition.request();
      if (status.isGranted) {
        _startListening();
      } else {
        debugPrint('[PedometerService] Permissions denied. Starting fallback simulator.');
        _startSimulation();
      }
    } catch (e) {
      debugPrint('[PedometerService] Error requesting permissions: $e. Starting fallback simulator.');
      _startSimulation();
    }
  }

  void _startListening() {
    _subscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );
  }

  void _onStepCount(StepCount event) {
    debugPrint('[PedometerService] Pedometer step event: ${event.steps}');
    final steps = event.steps;
    
    if (_initialSteps == null) {
      _initialSteps = steps;
      _lastSentSteps = steps;
      return;
    }

    final delta = steps - _lastSentSteps;
    if (delta > 0) {
      _lastSentSteps = steps;
      _logMetrics(delta);
    }
  }

  void _onStepCountError(error) {
    debugPrint('[PedometerService] Pedometer error: $error. Starting fallback simulator.');
    _startSimulation();
  }

  /// Start background step count simulation (ideal for emulators/dev)
  void _startSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;
    _simulationTimer?.cancel();

    debugPrint('[PedometerService] Step simulation active.');
    _simulationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      // Simulate random walking: 10-30 steps
      final increment = 10 + (DateTime.now().second % 21);
      debugPrint('[PedometerService] Simulating steps increment: +$increment');
      _logMetrics(increment);
    });
  }

  /// Log steps and distance metrics to server
  Future<void> _logMetrics(int stepsDelta) async {
    try {
      // Calculate distance delta (average stride length is ~0.75m -> 0.00075km)
      final double distanceDelta = stepsDelta * 0.00075;

      // Post both metrics to backend
      await Future.wait([
        ApiService.logHealthMetric('STEPS', stepsDelta.toDouble()),
        ApiService.logHealthMetric('DISTANCE', distanceDelta),
      ]);
      debugPrint('[PedometerService] Successfully logged metrics: $stepsDelta steps, $distanceDelta km');
    } catch (e) {
      debugPrint('[PedometerService] Failed to log step metrics: $e');
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
  }
}
