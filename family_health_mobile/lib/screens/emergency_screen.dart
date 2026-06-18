import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

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
          'This will send an emergency alert with your location to all family members and emergency contacts.'),
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
              
              // Call API
              final success = await ApiService.triggerSOS(lat: 17.4065, lng: 78.4772); // Hyderabad coordinates
              
              if (ctx.mounted) {
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
