import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  Position? _currentPosition;
  List<dynamic> _familyMembers = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Fetch current location
    _currentPosition = await LocationService.getCurrentPosition();
    
    // 2. Fetch family members' latest locations
    final members = await ApiService.getFamilyMembers();
    
    if (mounted) {
      setState(() {
        _familyMembers = members;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Default center if location is not available
    LatLng mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(0, 0);

    List<Marker> markers = [];
    
    // Add current user's marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 80,
          height: 80,
          child: const Column(
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 40),
              Text('You', style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Add family members' markers
    for (var member in _familyMembers) {
      if (member['latest_location'] != null) {
        final loc = member['latest_location'];
        markers.add(
          Marker(
            point: LatLng(loc['latitude'], loc['longitude']),
            width: 80,
            height: 80,
            child: Column(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 40),
                Text(
                  member['user_details']['username'] ?? 'Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Family Location'),
        actions: [
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
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: mapCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.familyhealth.family_health_mobile',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
