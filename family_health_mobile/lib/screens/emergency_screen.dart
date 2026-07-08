import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/location_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'emergency.alert') {
        _showIncomingSOSDialog(event['data']);
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _showIncomingSOSDialog(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;
    final triggeredBy = data['triggered_by'] ?? 'Family Member';
    final message = data['message'] ?? 'Emergency! I need help immediately.';
    final lat = data['location_lat'];
    final lng = data['location_lng'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency_share, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('🚨 SOS: $triggeredBy', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (lat != null && lng != null)
              Text('Location: $lat, $lng', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
          ),
          if (lat != null && lng != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                if (await canLaunchUrl(mapUrl)) {
                  await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('View on Map', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Big SOS Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: GestureDetector(
                onTap: () => _showSOSDialog(context),
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        blurRadius: 40, spreadRadius: 10),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text('SOS', style: TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.bold,
                        letterSpacing: 4)),
                      Text('Hold to activate', style: TextStyle(color: Colors.white70,
                        fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Emergency contacts
          const Text('Emergency Contacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...[
            {'name': 'Mom', 'phone': '+919876543210', 'type': 'Family'},
            {'name': 'Dad', 'phone': '+919876543211', 'type': 'Family'},
            {'name': 'Ambulance', 'phone': '108', 'type': 'Emergency'},
            {'name': 'Police', 'phone': '100', 'type': 'Emergency'},
          ].map((contact) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: contact['type'] == 'Emergency'
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : const Color(0xFF14B8A6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    contact['type'] == 'Emergency'
                      ? Icons.emergency_rounded : Icons.person_rounded,
                    color: contact['type'] == 'Emergency'
                      ? const Color(0xFFEF4444) : const Color(0xFF14B8A6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact['name']!,
                        style: TextStyle(fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text(contact['phone']!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call_rounded, color: Color(0xFF14B8A6)),
                  onPressed: () async {
                    final telUrl = Uri.parse('tel:${contact['phone']}');
                    if (await canLaunchUrl(telUrl)) {
                      await launchUrl(telUrl);
                    }
                  },
                ),
              ],
            ),
          )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Send SOS Alert?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will send an emergency alert with your real GPS location to all family members and emergency contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              // Fetch real GPS position
              final position = await LocationService.getCurrentPosition();
              final double lat = position?.latitude ?? 0.0;
              final double lng = position?.longitude ?? 0.0;

              // Also save the current location to the user's history
              if (position != null) {
                await ApiService.updateLocation(lat: lat, lng: lng);
              }

              // Call API with real coordinates
              final success = await ApiService.triggerSOS(lat: lat, lng: lng);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '🚨 SOS Alert sent to all family members!' : '❌ Failed to send SOS alert.'),
                    backgroundColor: success ? const Color(0xFFEF4444) : Colors.grey[800],
                  ),
                );
              }
            },
            child: const Text('Send SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

