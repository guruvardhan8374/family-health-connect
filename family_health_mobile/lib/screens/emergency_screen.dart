import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  List<Map<String, dynamic>> _policeStations = [];
  bool _isLoadingPolice = true;

  // Emergency contacts added by user (name + phone)
  final List<Map<String, String>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyPolice();
    _loadFamilyAsContacts();
  }

  Future<void> _loadNearbyPolice() async {
    final pos = await LocationService.getCurrentPosition();
    final lat = pos?.latitude ?? 12.9716;
    final lng = pos?.longitude ?? 77.5946;
    final stations = await ApiService.getNearbyPolice(lat: lat, lng: lng);
    if (mounted) {
      setState(() {
        _policeStations = stations;
        _isLoadingPolice = false;
      });
    }
  }

  /// Pre-populate with family members fetched from API
  Future<void> _loadFamilyAsContacts() async {
    try {
      final members = await ApiService.getFamilyMembers();
      if (mounted) {
        setState(() {
          for (final m in members) {
            final name = (m['full_name'] ?? m['username'] ?? '').toString().trim();
            final phone = (m['phone'] ?? '').toString().trim();
            if (name.isNotEmpty && !_emergencyContacts.any((c) => c['name'] == name)) {
              _emergencyContacts.add({'name': name, 'phone': phone.isNotEmpty ? phone : '—'});
            }
          }
        });
      }
    } catch (_) {}
  }

  void _showAddContactDialog() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF14B8A6)),
            SizedBox(width: 8),
            Text('Add Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a phone number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _emergencyContacts.add({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  void _removeContact(int index) {
    setState(() => _emergencyContacts.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Emergency Assistance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Big SOS Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () => _showSOSDialog(context),
                child: Container(
                  width: 170, height: 170,
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
                      Icon(Icons.shield_rounded, color: Colors.white, size: 44),
                      SizedBox(height: 6),
                      Text('SOS', style: TextStyle(color: Colors.white,
                        fontSize: 26, fontWeight: FontWeight.bold,
                        letterSpacing: 4)),
                      Text('Tap to activate', style: TextStyle(color: Colors.white70,
                        fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- NEARBY POLICE STATIONS SECTION ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nearby Police Stations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_isLoadingPolice)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Sorted by distance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isLoadingPolice && _policeStations.isEmpty)
            const Text('No police stations located nearby.', style: TextStyle(color: Colors.grey, fontSize: 13))
          else
            ..._policeStations.map((station) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_police_rounded, color: Color(0xFF3B82F6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(station['name'] ?? 'Police Station',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                            Text(station['address'] ?? '',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(station['distance_formatted'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: Text('Call (${station['phone_number'] ?? '100'})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final telUrl = Uri.parse('tel:${station['phone_number'] ?? '100'}');
                            if (await canLaunchUrl(telUrl)) {
                              await launchUrl(telUrl);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text('Navigate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final mapsUrl = Uri.parse(station['google_maps_link'] ?? '');
                            if (await canLaunchUrl(mapsUrl)) {
                              await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),

          const SizedBox(height: 16),

          // ─── EMERGENCY CONTACTS (user-managed) ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Emergency Contacts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_emergencyContacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.group_add_rounded, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No emergency contacts added yet.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Tap "Add User" to add someone.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            )
          else
            ...List.generate(_emergencyContacts.length, (index) {
              final contact = _emergencyContacts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
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
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF14B8A6), size: 20),
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
                    // Call button
                    IconButton(
                      icon: const Icon(Icons.call_rounded, color: Color(0xFF14B8A6)),
                      tooltip: 'Call',
                      onPressed: () async {
                        final phone = contact['phone']!;
                        if (phone == '—') return;
                        final telUrl = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(telUrl)) {
                          await launchUrl(telUrl);
                        }
                      },
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Remove',
                      onPressed: () => _removeContact(index),
                    ),
                  ],
                ),
              );
            }),

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

              // Fetch real GPS position with timeout fallback so it never hangs
              Position? position;
              try {
                position = await LocationService.getCurrentPosition().timeout(
                  const Duration(seconds: 4),
                  onTimeout: () => null,
                );
              } catch (_) {
                position = null;
              }

              final double? lat = position?.latitude;
              final double? lng = position?.longitude;

              // Save current location to the user's history if obtained
              if (lat != null && lng != null) {
                ApiService.updateLocation(lat: lat, lng: lng);
              }

              // Call API with coordinates (or nulls if unavailable)
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
