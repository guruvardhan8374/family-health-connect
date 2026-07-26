import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../services/health_service.dart';
import '../services/translation_service.dart';
import 'settings_screen.dart';
import 'live_location_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = 'User';
  List<dynamic> _members = [];
  bool _isLoading = true;
  int _unreadNotifCount = 0;
  StreamSubscription? _syncSub;
  Map<String, dynamic>? _activeSOS; // active SOS from a family member

  double _avgSleep = 0.0;
  double _avgSteps = 0.0;
  double _avgSpO2 = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCachedUsername();
    _fetchDashboardData();
    _listenToRealtimeEvents();
    _checkActiveSOS();
    LocationService.startPeriodicTracking();
  }

  void _listenToRealtimeEvents() {
    _syncSub = SyncService.instance.stream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'notification.new') {
        setState(() => _unreadNotifCount++);
      }
      if (event['type'] == 'health.update') {
        _fetchDashboardData();
      }
      // Real-time SOS from a family member
      if (event['type'] == 'emergency.alert') {
        final data = event['data'] as Map<String, dynamic>? ?? {};
        final isResolved = data['is_resolved'] == true ||
            data['status'] == 'RESOLVED' || data['status'] == 'FALSE_ALARM';
        if (isResolved) {
          setState(() => _activeSOS = null);
        } else {
          setState(() => _activeSOS = data);
        }
      }
    });
  }

  /// Poll for active SOS alerts on startup (in case one was already active)
  Future<void> _checkActiveSOS() async {
    try {
      final alerts = await ApiService.getActiveSOSAlerts();
      if (mounted && alerts.isNotEmpty) {
        setState(() => _activeSOS = alerts.first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  /// Reads username from in-memory cache — returns almost instantly.
  Future<void> _loadCachedUsername() async {
    final username = await AuthService.getUsername();
    if (mounted) setState(() => _username = username);
  }

  Future<void> _fetchDashboardData() async {
    // 1. Immediately load today's Health Connect snapshot for live vitals
    final cachedSnapshot = await HealthService.instance.getLastCachedSnapshot();
    if (cachedSnapshot != null && mounted) {
      setState(() {
        final steps = (cachedSnapshot['steps'] as num?)?.toDouble() ?? 0;
        final sleep = (cachedSnapshot['sleep_hours'] as num?)?.toDouble() ?? 0;
        final spo2  = (cachedSnapshot['spo2'] as num?)?.toDouble() ?? 0;
        if (steps > 0) _avgSteps = steps;
        if (sleep > 0) _avgSleep = sleep;
        if (spo2  > 0) _avgSpO2  = spo2;
      });
    }

    // 2. Trigger a fresh Health Connect fetch in background
    HealthService.instance.fetchTodaySnapshot().then((snapshot) {
      if (mounted) {
        setState(() {
          final steps = (snapshot['steps'] as num?)?.toDouble() ?? 0;
          final sleep = (snapshot['sleep_hours'] as num?)?.toDouble() ?? 0;
          final spo2  = (snapshot['spo2'] as num?)?.toDouble() ?? 0;
          if (steps > 0) _avgSteps = steps;
          if (sleep > 0) _avgSleep = sleep;
          if (spo2  > 0) _avgSpO2  = spo2;
        });
      }
    }).catchError((e) => debugPrint('[Dashboard] Health snapshot error: $e'));

    // 3. Fetch backend data (family members, history) in parallel
    final results = await Future.wait([
      ApiService.getFamilyMembers(),
      ApiService.getHealthData(),
      ApiService.getUnreadNotificationCount(),
    ]);

    final List<dynamic> members    = results[0] as List<dynamic>;
    final List<dynamic> healthData = results[1] as List<dynamic>;
    final int unreadCount          = results[2] as int;

    // Only use backend history averages if Health Connect gave us nothing
    if (healthData.isNotEmpty && _avgSteps == 0 && _avgSleep == 0 && _avgSpO2 == 0) {
      double totalSleep = 0, totalSteps = 0, totalSpO2 = 0;
      final count = healthData.length;
      for (var record in healthData) {
        totalSleep += (record['sleep_hours'] as num? ?? 0).toDouble();
        totalSteps += (record['steps']       as num? ?? 0).toDouble();
        totalSpO2  += (record['oxygen_level'] as num? ?? 0).toDouble();
      }
      if (mounted) {
        setState(() {
          if (totalSteps > 0) _avgSteps = totalSteps / count;
          if (totalSleep > 0) _avgSleep = totalSleep / count;
          if (totalSpO2  > 0) _avgSpO2  = totalSpO2  / count;
        });
      }
    }

    if (mounted) {
      setState(() {
        _members          = members;
        _unreadNotifCount = unreadCount;
        _isLoading        = false;
      });
    }
  }



  Color _getRoleColor(String label) {
    switch (label.toUpperCase()) {
      case 'PARENT':
        return const Color(0xFF6366F1); // Indigo
      case 'ELDER':
      case 'ELDERLY':
        return const Color(0xFF14B8A6); // Emerald
      case 'CHILD':
        return const Color(0xFFF59E0B); // Orange
      case 'SPOUSE':
        return const Color(0xFFF43F5E); // Rose
      default:
        return const Color(0xFF8B5CF6); // Violet
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          color: const Color(0xFF14B8A6),
          onRefresh: _fetchDashboardData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF000000), Color(0xFF070D18), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    20,
                    24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${TranslationService.translate('hello')}, $_username 👋',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(TranslationService.translate('family_health_hub'),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                       Row(
                        children: [
                          Semantics(
                            label: 'Settings',
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
                                _fetchDashboardData();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_activeSOS != null && (_activeSOS!['triggered_by'] ?? _activeSOS!['username']) != _username)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade300, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '🚨 ${TranslationService.translate('emergency_alert')}',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_activeSOS!['triggered_by'] ?? _activeSOS!['username'] ?? 'A family member'} ${TranslationService.translate('needs_help')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Message: "${_activeSOS!['message'] ?? 'I need help immediately.'}"',
                          style: TextStyle(color: Colors.grey[800], fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_activeSOS!['location_lat'] != null && _activeSOS!['location_lng'] != null)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.map_outlined, size: 16),
                                  label: Text(TranslationService.translate('track'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final lat = _activeSOS!['location_lat'];
                                    final lng = _activeSOS!['location_lng'];
                                    final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                    if (await canLaunchUrl(mapsUrl)) {
                                      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              ),
                            if (_activeSOS!['location_lat'] != null && _activeSOS!['location_lng'] != null)
                              const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(TranslationService.translate('dismiss'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final alertId = _activeSOS!['id'];
                                  setState(() {
                                    _activeSOS = null;
                                  });
                                  if (alertId != null) {
                                    await ApiService.resolveSOSAlert(alertId is int ? alertId : int.parse(alertId.toString()));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Family Map Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: const Color(0xFF3B82F6), // Blue
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.map_rounded, color: Colors.white),
                        label: Text(TranslationService.translate('live_family_map'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveLocationScreen()));
                        },
                      ),
                    ),
                  ),
                  
                  // Section title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(TranslationService.translate('family_overview'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6))),
                  ),
  
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
                    )
                  else if (_members.isEmpty)
                    Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline_rounded, color: Color(0xFF64748B), size: 36),
                            SizedBox(height: 8),
                            Text('No active family directory found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('Add family members in the Family tab.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._members.map((member) => _buildFamilyCard(member)),
  
                  const SizedBox(height: 24),
  
                  // Stats Row
                  if (!_isLoading) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(TranslationService.translate('personal_vitals'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF14B8A6))),
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard(TranslationService.translate('sleep'), '${_avgSleep.toStringAsFixed(1)} hrs', Icons.bedtime_rounded, const Color(0xFF6366F1))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard(TranslationService.translate('steps'), _avgSteps >= 1000 ? '${(_avgSteps / 1000.0).toStringAsFixed(1)}k' : '${_avgSteps.toInt()}', Icons.directions_walk_rounded, const Color(0xFF14B8A6))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard(TranslationService.translate('oxygen'), '${_avgSpO2.toStringAsFixed(0)}%', Icons.water_drop_rounded, const Color(0xFFEF4444))),
                      ],
                    ),
                  ],
  
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFamilyCard(dynamic member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userDetails = member['user_details'] as Map<String, dynamic>?;
    final username = userDetails != null ? (userDetails['username'] ?? '') : (member['name'] ?? 'Unknown');
    final email = userDetails != null ? (userDetails['email'] ?? '') : '';
    final role = (member['label'] ?? 'Member').toString();
    final isApproved = member['is_approved'] == true;
    final statusText = isApproved ? 'Active' : 'Pending';
    final roleColor = _getRoleColor(role);

    // Extract real health metrics synced from Google Fit / Health Connect
    final healthRecord = member['latest_health_record'] as Map<String, dynamic>?;
    final int hr = healthRecord?['heart_rate'] != null ? (healthRecord!['heart_rate'] as num).toInt() : 0;
    final int steps = healthRecord?['steps'] != null ? (healthRecord!['steps'] as num).toInt() : 0;
    final double spo2 = healthRecord?['oxygen_level'] != null ? (healthRecord!['oxygen_level'] as num).toDouble() : 0.0;
    final double sleep = healthRecord?['sleep_hours'] != null ? (healthRecord!['sleep_hours'] as num).toDouble() : 0.0;

    final String hrText = hr > 0 ? '$hr bpm' : '-- bpm';
    final String stepsText = steps >= 1000 ? '${(steps / 1000.0).toStringAsFixed(1)}k' : (steps > 0 ? '$steps' : '-- steps');

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).cardColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, color: roleColor, size: 48),
                const SizedBox(height: 16),
                Text('$username\'s Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Text('Role: $role', style: const TextStyle(fontWeight: FontWeight.w500)),
                if (email.isNotEmpty) Text('Email: $email', style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(height: 4),
                          Text(hrText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Heart Rate', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.directions_walk, color: Color(0xFF14B8A6), size: 20),
                          const SizedBox(height: 4),
                          Text(stepsText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Steps Today', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.water_drop, color: Color(0xFF3B82F6), size: 20),
                          const SizedBox(height: 4),
                          Text(spo2 > 0 ? '${spo2.toStringAsFixed(0)}%' : '--%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('SpO2', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.bedtime, color: Color(0xFF6366F1), size: 20),
                          const SizedBox(height: 4),
                          Text(sleep > 0 ? '${sleep.toStringAsFixed(1)}h' : '--h', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Sleep', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded,
              color: roleColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username.toString(), style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(role, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusText,
                  style: TextStyle(color: isApproved ? Colors.green : Colors.amber, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 12),
                  const SizedBox(width: 4),
                  Text(hrText,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  const Icon(Icons.directions_walk, color: Color(0xFF14B8A6), size: 12),
                  const SizedBox(width: 4),
                  Text(stepsText,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold,
            fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
