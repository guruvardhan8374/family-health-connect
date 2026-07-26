import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/health_service.dart';
import '../services/health_sync_service.dart';

class HealthDataSettingsScreen extends StatefulWidget {
  const HealthDataSettingsScreen({super.key});

  @override
  State<HealthDataSettingsScreen> createState() => _HealthDataSettingsScreenState();
}

class _HealthDataSettingsScreenState extends State<HealthDataSettingsScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasPermissions = false;
  DateTime? _lastSyncTime;
  Map<String, dynamic>? _lastSnapshot;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  String get _sourceName => _isIOS ? 'Apple Health (HealthKit)' : 'Android Health Connect';

  @override
  void initState() {
    super.initState();
    _loadHealthStatus();
  }

  Future<void> _loadHealthStatus() async {
    setState(() => _isLoading = true);
    final hasPerm = await HealthService.instance.hasPermissions();
    final snapshot = await HealthService.instance.getLastCachedSnapshot();
    if (mounted) {
      setState(() {
        _hasPermissions = hasPerm;
        _lastSnapshot = snapshot;
        if (snapshot != null && snapshot['timestamp'] != null) {
          _lastSyncTime = DateTime.tryParse(snapshot['timestamp'].toString());
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    try {
      final snapshot = await HealthService.instance.fetchTodaySnapshot();
      await HealthSyncService.instance.syncSnapshot(snapshot);
      if (mounted) {
        setState(() {
          _lastSnapshot = snapshot;
          _lastSyncTime = DateTime.now();
          _hasPermissions = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Health data synchronized from $_sourceName!'),
            backgroundColor: const Color(0xFF14B8A6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await HealthService.instance.requestPermissions();
    if (mounted) {
      final hasPerms = await HealthService.instance.hasPermissions();
      setState(() => _hasPermissions = granted || hasPerms);
      if (granted || hasPerms) {
        _triggerManualSync();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Health permissions were not granted.'),
            backgroundColor: Colors.amber,
            action: SnackBarAction(
              label: 'SETTINGS',
              textColor: Colors.black,
              onPressed: () => HealthService.instance.openHealthConnectSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Health Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Source Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isIOS ? const Color(0xFFFA2F39) : const Color(0xFF14B8A6))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _isIOS ? Icons.favorite_rounded : Icons.health_and_safety_rounded,
                              color: _isIOS ? const Color(0xFFFA2F39) : const Color(0xFF14B8A6),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connected Source',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sourceName,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _hasPermissions ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _hasPermissions ? 'Active' : 'Pending',
                              style: TextStyle(
                                color: _hasPermissions ? Colors.green : Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Permission Status', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                _hasPermissions ? 'Authorized' : 'Action Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _hasPermissions ? Colors.green : Colors.amber[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Last Sync Time', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                _lastSyncTime != null
                                    ? '${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Not synced yet',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _triggerManualSync,
                          icon: _isSyncing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync_rounded),
                          label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Connected Apps Info
                const Text(
                  'Connected Platform Apps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                ),
                const SizedBox(height: 8),
                Text(
                  _isIOS
                      ? 'Health data is automatically synchronized directly from Apple Health (HealthKit), including Apple Watch data.'
                      : 'Reads aggregated health metrics from Google Fit, Samsung Health, Fitbit, and Garmin via Android Health Connect.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),

                // Platform Apps List
                ...(_isIOS
                        ? [
                            {'name': 'Apple Health App', 'desc': 'Native iOS Health storage'},
                            {'name': 'Apple Watch', 'desc': 'Workouts, heart rate & SpO2'},
                            {'name': 'Connected iOS Health Apps', 'desc': 'Third-party workout & sleep logs'},
                          ]
                        : [
                            {'name': 'Google Fit', 'desc': 'Steps, distance & heart rate'},
                            {'name': 'Samsung Health', 'desc': 'Sleep, daily activity & blood oxygen'},
                            {'name': 'Fitbit', 'desc': 'Calories, sleep stages & resting HR'},
                            {'name': 'Garmin Connect', 'desc': 'Workouts, stress & body metrics'},
                          ])
                    .map(
                  (app) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF14B8A6),
                        size: 22,
                      ),
                      title: Text(app['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(app['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Permissions Section Button
                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.security_rounded, color: Color(0xFF14B8A6)),
                    title: const Text('Health Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Manage read access for Steps, Heart Rate, SpO2 & Sleep'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: _requestPermissions,
                  ),
                ),
              ],
            ),
    );
  }
}
