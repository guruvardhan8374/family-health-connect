import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = 'User';
  List<dynamic> _members = [];
  bool _isLoading = true;

  double _avgSleep = 0.0;
  double _avgSteps = 0.0;
  double _avgSpO2 = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final username = await AuthService.getUsername();
    final members = await ApiService.getFamilyMembers();
    final healthData = await ApiService.getHealthData();

    if (healthData.isNotEmpty) {
      double totalSleep = 0;
      double totalSteps = 0;
      double totalSpO2 = 0;
      int count = healthData.length;

      for (var record in healthData) {
        totalSleep += (record['sleep_hours'] as num? ?? 0).toDouble();
        totalSteps += (record['steps'] as num? ?? 0).toDouble();
        totalSpO2 += (record['oxygen_level'] as num? ?? 0).toDouble();
      }

      _avgSleep = totalSleep / count;
      _avgSteps = totalSteps / count;
      _avgSpO2 = totalSpO2 / count;
    } else {
      _avgSleep = 0.0;
      _avgSteps = 0.0;
      _avgSpO2 = 0.0;
    }

    if (mounted) {
      setState(() {
        _username = username;
        _members = members;
        _isLoading = false;
      });
    }
  }

  Color _getRoleColor(String label) {
    switch (label.toUpperCase()) {
      case 'PARENT':
        return const Color(0xFF6366F1); // Indigo
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: const Color(0xFF14B8A6),
        onRefresh: _fetchDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF0F172A),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, $_username 👋',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const Text('Family Health Hub',
                            style: TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.bold)),
                        ],
                      ),
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
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // SOS Banner
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Emergency SOS'),
                          content: const Text('Are you sure you want to trigger an emergency alert to all family members and contacts?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () async {
                                Navigator.pop(context);
                                
                                final success = await ApiService.triggerSOS(lat: 17.4065, lng: 78.4772);
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success 
                                          ? '🚨 SOS Alert sent to all family members!' 
                                          : '❌ Failed to send SOS alert.'),
                                      backgroundColor: success ? Colors.red : Colors.grey[800],
                                    ),
                                  );
                                }
                              },
                              child: const Text('SEND SOS'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Emergency SOS',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('All family safe • Tap to alert',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('SOS', style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
  
                  // Section title
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Family Overview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Your Personal Vitals Averages',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF14B8A6))),
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Sleep', '${_avgSleep.toStringAsFixed(1)} hrs', Icons.bedtime_rounded, const Color(0xFF6366F1))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('Steps', _avgSteps >= 1000 ? '${(_avgSteps / 1000.0).toStringAsFixed(1)}k' : '${_avgSteps.toInt()}', Icons.directions_walk_rounded, const Color(0xFF14B8A6))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('SpO2', '${_avgSpO2.toStringAsFixed(0)}%', Icons.water_drop_rounded, const Color(0xFFEF4444))),
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
                const SizedBox(height: 12),
                const Text('More detailed health metrics and location data will appear here once connected to their wearable devices!', textAlign: TextAlign.center),
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
                  Text(isApproved ? '72 bpm' : '-- bpm',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  const Icon(Icons.directions_walk, color: Color(0xFF14B8A6), size: 12),
                  const SizedBox(width: 4),
                  Text(isApproved ? '5.4k' : '-- steps',
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
