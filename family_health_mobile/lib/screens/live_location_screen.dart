import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  Position? _currentPosition;
  List<dynamic> _familyMembers = [];
  bool _isLoading = true;
  bool _isLocationSharingEnabled = true;
  bool _hasPermission = true;
  final MapController _mapController = MapController();
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startLiveTracking();
  }

  Future<void> _initializeData() async {
    // Check permission
    final hasPerm = await LocationService.hasPermission();
    if (!hasPerm) {
      final granted = await LocationService.requestPermission();
      setState(() => _hasPermission = granted);
    }

    // 1. Fetch current location
    _currentPosition = await LocationService.getCurrentPosition();

    // 2. Fetch family members' locations via API
    final members = await ApiService.getFamilyMembers(forceRefresh: true);

    // 3. Fetch privacy settings
    try {
      final privacy = await ApiService.getPrivacySettings();
      if (privacy != null && privacy['location_sharing'] != null) {
        _isLocationSharingEnabled = privacy['location_sharing'] == true;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _familyMembers = members;
        _isLoading = false;
      });
    }
  }

  void _startLiveTracking() {
    LocationService.startPeriodicTracking();

    // Listen to real-time WebSocket location updates
    _locationSub = SyncService.instance.stream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'location.update') {
        final data = event['data'] as Map<String, dynamic>?;
        if (data == null) return;

        final int userId = data['user_id'];
        bool isSharing = data['is_sharing_enabled'] ?? true;
        bool isOnline = (data['is_online'] ?? true) && isSharing;

        setState(() {
          int index = _familyMembers.indexWhere(
            (m) => (m['user_details'] != null && m['user_details']['id'] == userId) || m['user'] == userId,
          );

          if (index != -1) {
            _familyMembers[index]['latest_location'] = {
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'speed': data['speed'] ?? 0.0,
              'battery_level': data['battery_level'] ?? 100,
              'timestamp': data['timestamp'],
              'is_online': isOnline,
              'is_sharing_enabled': isSharing,
              'is_last_known': !isOnline,
              'last_seen_formatted': data['last_seen_formatted'] ?? (isSharing ? 'Just now' : 'Sharing disabled'),
            };
          } else {
            // Newly joined member received — refresh list
            _initializeData();
          }
        });
      } else if (event['type'] == 'family.update') {
        _initializeData();
      }
    });
  }

  Future<void> _toggleLocationSharing(bool value) async {
    setState(() => _isLocationSharingEnabled = value);
    if (!value) {
      LocationService.stopPeriodicTracking();
    } else {
      LocationService.startPeriodicTracking();
    }
    await ApiService.updatePrivacySettings({'location_sharing': value});
  }

  /// Calculates Haversine distance in km between two lat/lng points
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _showMemberDetailsModal(Map<String, dynamic> member, Map<String, dynamic>? loc) {
    final user = member['user_details'] ?? {};
    final String name = user['username'] ?? 'Family Member';
    final String? avatar = user['profile_picture'];
    final bool isOnline = loc?['is_online'] == true;
    final bool isSharing = loc?['is_sharing_enabled'] != false;
    final String lastSeen = loc?['last_seen_formatted'] ?? 'Unknown';
    final double speed = (loc?['speed'] as num?)?.toDouble() ?? 0.0;
    final int battery = (loc?['battery_level'] as num?)?.toInt() ?? 100;

    double? distanceKm;
    if (_currentPosition != null && loc != null) {
      distanceKm = _calculateDistanceKm(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        loc['latitude'],
        loc['longitude'],
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                        backgroundImage: (avatar != null && avatar.isNotEmpty)
                            ? NetworkImage(ApiService.normalizeImageUrl(avatar))
                            : null,
                        child: (avatar == null || avatar.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF14B8A6),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOnline
                                    ? '● Live Online'
                                    : (!isSharing ? '● Sharing Disabled' : '● $lastSeen'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline ? Colors.green : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(
                    icon: Icons.navigation_rounded,
                    label: 'Distance',
                    value: distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '--',
                    color: const Color(0xFF3B82F6),
                  ),
                  _statItem(
                    icon: Icons.speed_rounded,
                    label: 'Speed',
                    value: '${speed.toStringAsFixed(0)} km/h',
                    color: const Color(0xFF10B981),
                  ),
                  _statItem(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'Battery',
                    value: '$battery%',
                    color: battery < 20 ? Colors.red : const Color(0xFF8B5CF6),
                  ),
                  _statItem(
                    icon: isSharing ? Icons.location_on_rounded : Icons.location_off_rounded,
                    label: 'Sharing',
                    value: isSharing ? 'ON' : 'OFF',
                    color: isSharing ? const Color(0xFF14B8A6) : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (loc != null)
                Text(
                  'Last Updated: ${loc['last_seen_formatted'] ?? lastSeen}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    LatLng mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(12.9716, 77.5946); // Default fallback

    List<Marker> markers = [];

    // Current user marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 70,
          height: 70,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF14B8A6),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Text('You (Live)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
            ],
          ),
        ),
      );
    }

    // Family members markers
    for (var member in _familyMembers) {
      if (member['latest_location'] != null) {
        final loc = member['latest_location'];
        final user = member['user_details'] ?? {};
        final double lat = (loc['latitude'] as num).toDouble();
        final double lng = (loc['longitude'] as num).toDouble();
        final String username = user['username'] ?? 'Member';
        final String? avatarUrl = user['profile_picture'];
        final bool isOnline = loc['is_online'] == true;
        final bool isSharing = loc['is_sharing_enabled'] != false;

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () => _showMemberDetailsModal(member, loc),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                            width: 3,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(ApiService.normalizeImageUrl(avatarUrl))
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.white : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Text(
                      isSharing ? username : '$username (Last seen)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? const Color(0xFF0F172A) : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Family Location', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text('Share GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isLocationSharingEnabled,
                activeColor: const Color(0xFF14B8A6),
                onChanged: _toggleLocationSharing,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  15.0,
                );
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.familyhealth.family_health_mobile',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (!_hasPermission)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Location permission is denied. Enable location to share live coordinates.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final granted = await LocationService.requestPermission();
                        if (granted) {
                          _initializeData();
                        }
                      },
                      child: const Text('ENABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
