import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStreamSub;
  static Timer? _periodicTimer;
  static bool _isTracking = false;

  /// Retrieves current position with high accuracy.
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (__) {
        return null;
      }
    }
  }

  /// Request location permissions.
  static Future<bool> requestPermission() async {
    var status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check permission status without prompting.
  static Future<bool> hasPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  /// Start background/foreground periodic location updater (every 5-10s).
  static void startPeriodicTracking({Duration interval = const Duration(seconds: 8)}) {
    if (_isTracking) return;
    _isTracking = true;

    // Send immediately once
    _sendLocationUpdate();

    // Setup periodic timer (5–10 sec)
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => _sendLocationUpdate());

    // Also listen to Geolocator position stream for dynamic updates on significant movement
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5 meters movement threshold
    );

    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        double speedKmh = (position.speed) * 3.6;
        ApiService.updateLocation(
          lat: position.latitude,
          lng: position.longitude,
          speed: speedKmh,
          batteryLevel: 90, // default placeholder or battery level
          isMoving: position.speed > 0.5,
        );
      },
      onError: (_) {},
    );
  }

  /// Stops tracking updates when user turns off location sharing or logs out.
  static void stopPeriodicTracking() {
    _isTracking = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  static Future<void> _sendLocationUpdate() async {
    try {
      final pos = await getCurrentPosition();
      if (pos != null) {
        double speedKmh = pos.speed * 3.6;
        await ApiService.updateLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          speed: speedKmh,
          batteryLevel: 90,
          isMoving: pos.speed > 0.5,
        );
      }
    } catch (_) {}
  }
}
