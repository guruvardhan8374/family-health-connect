import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class WirelessVitalsScreen extends StatefulWidget {
  const WirelessVitalsScreen({super.key});

  @override
  State<WirelessVitalsScreen> createState() => _WirelessVitalsScreenState();
}

class _WirelessVitalsScreenState extends State<WirelessVitalsScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncingPlatform;
  StreamSubscription? _syncSubscription;

  final List<Map<String, dynamic>> _platforms = [
    {
      'id': 'GOOGLE_FIT',
      'name': 'Google Fit',
      'icon': Icons.fit_screen_rounded,
      'color': const Color(0xFFEA4335),
      'description': 'Sync heart rate, steps, and activity metrics.',
    },
    {
      'id': 'APPLE_HEALTH',
      'name': 'Apple Health',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFFA2F39),
      'description': 'Import fitness and health logs directly.',
    },
    {
      'id': 'FITBIT',
      'name': 'Fitbit Wearable',
      'icon': Icons.watch_rounded,
      'color': const Color(0xFF00B0B9),
      'description': 'Track sleep quality and daily calorie burns.',
    },
    {
      'id': 'GARMIN',
      'name': 'Garmin Connect',
      'icon': Icons.speed_rounded,
      'color': const Color(0xFF4A90E2),
      'description': 'Aggregate running workouts and stress indexes.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Refresh history when any sync occurs in the background
    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'health.update') {
        _fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final history = await ApiService.getIoTSyncHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerSync(String platformId, String platformName) async {
    setState(() {
      _isSyncing = true;
      _syncingPlatform = platformId;
    });

    final success = await ApiService.syncIoTData(platformId);

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncingPlatform = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Successfully synced vitals from $platformName!'
                : '❌ Failed to sync from $platformName.',
          ),
          backgroundColor: success ? const Color(0xFF14B8A6) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Wireless Vitals & IoT'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sensors_rounded, color: Colors.white, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Connect IoT Health Devices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Synchronize steps, heart rate, and sleep data automatically from your wireless devices and health apps.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const Text(
                  'Available Health Platforms',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Grid of platforms
                ..._platforms.map((platform) {
                  final isPlatformSyncing = _isSyncing && _syncingPlatform == platform['id'];
                  final lastSyncEntry = _history.firstWhere(
                    (h) => h['platform'] == platform['id'],
                    orElse: () => null,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (platform['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            platform['icon'] as IconData,
                            color: platform['color'] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                platform['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                platform['description'] as String,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                              if (lastSyncEntry != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.sync_rounded, color: Color(0xFF14B8A6), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Synced ${lastSyncEntry['data_points_synced']} points',
                                      style: const TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF14B8A6),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isSyncing
                              ? null
                              : () => _triggerSync(platform['id'] as String, platform['name'] as String),
                          child: isPlatformSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2),
                                )
                              : const Text(
                                  'Sync',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),
                const Text(
                  'Recent Sync Activity Logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (_history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'No device sync history found.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._history.map((log) {
                    final platformName = _platforms.firstWhere(
                      (p) => p['id'] == log['platform'],
                      orElse: () => {'name': log['platform']},
                    )['name'];

                    final rawSyncDate = log['last_sync'] ?? '';
                    final syncDateStr = rawSyncDate.isNotEmpty
                        ? rawSyncDate.substring(0, 19).replaceAll('T', ' ')
                        : 'Recent';

                    final isSuccess = log['status'] == 'SUCCESS';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isSuccess ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$platformName Sync Log',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$syncDateStr • Synced ${log['data_points_synced']} items',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            log['status'] as String,
                            style: TextStyle(
                              color: isSuccess ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
