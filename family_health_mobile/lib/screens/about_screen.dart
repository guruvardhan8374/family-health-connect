import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checkingStatus = true;
  bool _serverOnline = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    try {
      // Perform a light check
      await ApiService.getHealthData();
      setState(() {
        _serverOnline = true;
        _checkingStatus = false;
      });
    } catch (_) {
      setState(() {
        _serverOnline = false;
        _checkingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const SizedBox(height: 24),
          // App Logo
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Family Health Connect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Center(
            child: Text(
              'Smart Personal & Family Health System',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Version Card
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildAboutRow('App Version', '1.0.0'),
                  const Divider(height: 20),
                  _buildAboutRow('Build Identifier', 'Release v1.0.260609'),
                  const Divider(height: 20),
                  _buildAboutRow('Backend API URL', ApiService.baseUrl.replaceFirst('/api/v1', '')),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Server Connection', style: TextStyle(fontWeight: FontWeight.w500)),
                      _checkingStatus
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6)),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _serverOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _serverOnline ? 'Connected' : 'Offline / Error',
                                style: TextStyle(
                                  color: _serverOnline ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Description info
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Family Health Connect is a production-ready caregiving ecosystem designed to aggregate and share wearable health metrics, coordinate smart safe zones, send instant SOS distress warnings, and enable family group chats.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 60),

          const Center(
            child: Text(
              '© 2026 Family Health Connect Inc.\nAll Rights Reserved.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      ],
    );
  }
}
