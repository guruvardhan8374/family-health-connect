import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/health_service.dart';
import '../services/health_sync_service.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;

  // Real-time Vitals from Health Connect
  String _heartRate = '--';
  String _steps = '--';
  String _calories = '--';
  String _distance = '--';
  String _sleep = '--';
  String _spo2 = '--';
  String _hydration = '--';
  String _weight = '--';
  String _bloodPressure = '--/--';

  // Goals
  int _stepsGoal = 10000;
  double _caloriesGoal = 2000.0;
  double _hydrationGoal = 2.0;
  double _sleepGoal = 8.0;
  double _distanceGoal = 5.0;

  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _initHealthSync();
    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'health.update') {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    HealthService.instance.stopLiveMonitoring();
    HealthSyncService.instance.disconnect();
    super.dispose();
  }

  Future<void> _loadCachedVitals() async {
    final cached = await HealthService.instance.getLastCachedSnapshot();
    if (cached != null && mounted) {
      setState(() {
        _heartRate = (cached['heart_rate'] ?? '--').toString();
        _steps = (cached['steps'] ?? '0').toString();
        _calories = (cached['calories'] ?? '0').toString();
        _distance = (cached['distance'] ?? '0.0').toString();
        _sleep = (cached['sleep_hours'] ?? '--').toString();
        _spo2 = (cached['spo2'] ?? '--').toString();
        _hydration = (cached['hydration'] ?? '--').toString();
        _weight = (cached['weight'] ?? '--').toString();
        _bloodPressure = (cached['blood_pressure'] ?? '--/--').toString();
      });
    }
  }

  Future<void> _initHealthSync() async {
    // 1. Fetch current health records and goals
    await _fetchData();
    // 2. Load cached vitals first for offline support
    await _loadCachedVitals();
    // 3. Connect WebSocket for live sync
    await HealthSyncService.instance.connect();
    // 4. Start live monitoring (checks Google Fit every 30s)
    HealthService.instance.startLiveMonitoring((snapshot) {
      if (mounted) {
        setState(() {
          _heartRate = (snapshot['heart_rate'] ?? '--').toString();
          _steps = (snapshot['steps'] ?? '0').toString();
          _calories = (snapshot['calories'] ?? '0').toString();
          _distance = (snapshot['distance'] ?? '0.0').toString();
          _sleep = (snapshot['sleep_hours'] ?? '--').toString();
          _spo2 = (snapshot['spo2'] ?? '--').toString();
          _hydration = (snapshot['hydration'] ?? '--').toString();
          _weight = (snapshot['weight'] ?? '--').toString();
          _bloodPressure = (snapshot['blood_pressure'] ?? '--/--').toString();
        });
      }
    });
  }

  Future<void> _fetchData() async {
    final records = await ApiService.getHealthData();
    final summary = await ApiService.getHealthSummary(range: 'daily');

    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;

        if (summary != null) {
          _heartRate = (summary['latest_heart_rate'] ?? '--').toString();
          _steps = (summary['today_steps'] ?? '0').toString();
          _calories = (summary['today_calories'] ?? '0').toString();
          _distance = (summary['today_distance'] ?? '0.0').toString();
          _sleep = (summary['today_sleep'] ?? '--').toString();
          _spo2 = (summary['latest_spo2'] ?? '--').toString();
          _hydration = (summary['today_hydration'] ?? '--').toString();
          _weight = (summary['latest_weight'] ?? '--').toString();

          final goal = summary['goal'];
          if (goal != null) {
            _stepsGoal = goal['steps_goal'] ?? 10000;
            _caloriesGoal = (goal['calories_goal'] ?? 2000.0).toDouble();
            _hydrationGoal = (goal['hydration_goal'] ?? 2.0).toDouble();
            _sleepGoal = (goal['sleep_goal'] ?? 8.0).toDouble();
            _distanceGoal = (goal['distance_goal'] ?? 5.0).toDouble();
          }
        }
      });
    }
  }

  void _showAddRecordBottomSheet() {
    final hrController = TextEditingController(text: '72');
    final oxygenController = TextEditingController(text: '98');
    final bpController = TextEditingController(text: '120/80');
    final stepsController = TextEditingController(text: '8000');
    final sleepController = TextEditingController(text: '8.0');
    final waterController = TextEditingController(text: '2.5');
    final weightController = TextEditingController(text: '70.0');
    final heightController = TextEditingController(text: '175.0');
    final notesController = TextEditingController();

    bool dialogSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          final sheetDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Log Daily Vitals',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: sheetDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildSheetField(
                          controller: hrController,
                          label: 'Heart Rate (bpm)',
                          icon: Icons.favorite_rounded,
                          keyboardType: TextInputType.number,
                          dark: sheetDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSheetField(
                          controller: oxygenController,
                          label: 'Oxygen Level (%)',
                          icon: Icons.thermostat_rounded,
                          keyboardType: TextInputType.number,
                          dark: sheetDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSheetField(
                          controller: bpController,
                          label: 'Blood Pressure',
                          icon: Icons.water_drop_rounded,
                          keyboardType: TextInputType.text,
                          dark: sheetDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSheetField(
                          controller: stepsController,
                          label: 'Steps Today',
                          icon: Icons.directions_walk_rounded,
                          keyboardType: TextInputType.number,
                          dark: sheetDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSheetField(
                          controller: sleepController,
                          label: 'Sleep Hours',
                          icon: Icons.bedtime_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          dark: sheetDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSheetField(
                          controller: waterController,
                          label: 'Water Intake (L)',
                          icon: Icons.local_drink_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          dark: sheetDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSheetField(
                          controller: weightController,
                          label: 'Weight (kg)',
                          icon: Icons.monitor_weight_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          dark: sheetDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSheetField(
                          controller: heightController,
                          label: 'Height (cm)',
                          icon: Icons.height_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          dark: sheetDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildSheetField(
                    controller: notesController,
                    label: 'Notes / Symptoms',
                    icon: Icons.description_rounded,
                    keyboardType: TextInputType.text,
                    dark: sheetDark,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: dialogSaving
                          ? null
                          : () async {
                              setStateSheet(() => dialogSaving = true);
                              
                              final hr = int.tryParse(hrController.text) ?? 72;
                              final oxy = int.tryParse(oxygenController.text) ?? 98;
                              final bp = bpController.text.trim();
                              final steps = int.tryParse(stepsController.text) ?? 0;
                              final sleep = double.tryParse(sleepController.text) ?? 8.0;
                              final water = double.tryParse(waterController.text) ?? 2.0;
                              final weight = double.tryParse(weightController.text) ?? 70.0;
                              final height = double.tryParse(heightController.text) ?? 170.0;
                              final notes = notesController.text.trim();

                              final success = await ApiService.syncHealthSnapshot({
                                'source': 'MANUAL',
                                'heart_rate': hr,
                                'spo2': oxy,
                                'blood_pressure': bp,
                                'steps': steps,
                                'sleep_hours': sleep,
                                'hydration': water,
                                'weight': weight,
                                'height': height,
                                'notes': notes,
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? '✅ Vitals logged successfully!' : '❌ Failed to log vitals.'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                                setState(() => _isLoading = true);
                                _fetchData();
                              }
                            },
                      child: dialogSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Save Vitals',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheetField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    required bool dark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(dark ? 0.05 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: dark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          prefixIcon: Icon(icon, color: const Color(0xFF14B8A6), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertColor = const Color(0xFFEF4444);

    // Check emergency thresholds
    double? currentHr = double.tryParse(_heartRate);
    double? currentOxygen = double.tryParse(_spo2);
    bool hasEmergency = (currentHr != null && (currentHr > 120 || currentHr < 45)) || 
                        (currentOxygen != null && currentOxygen < 90);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Google Fit Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF14B8A6)),
            onPressed: () {
              setState(() => _isLoading = true);
              HealthService.instance.stopLiveMonitoring();
              HealthSyncService.instance.disconnect();
              _initHealthSync();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
        : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency Vital Alert
          if (hasEmergency)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: alertColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: alertColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Abnormal Vitals Detected!', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: alertColor)),
                        const Text('Please rest and check your notifications or contact your doctor.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Vitals Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _VitalCard(
                label: 'Heart Rate', 
                value: _heartRate, 
                unit: 'bpm',
                progress: _heartRate != '--' ? (double.tryParse(_heartRate) ?? 0.0) / 100.0 : 0.0,
                icon: Icons.favorite_rounded, 
                color: const Color(0xFFEF4444)
              ),
              _VitalCard(
                label: 'Steps Today', 
                value: _steps, 
                unit: 'steps',
                progress: _steps != '--' ? (double.tryParse(_steps) ?? 0.0) / _stepsGoal : 0.0,
                icon: Icons.directions_walk_rounded, 
                color: const Color(0xFF14B8A6)
              ),
              _VitalCard(
                label: 'Oxygen (SpO₂)', 
                value: _spo2, 
                unit: '%',
                progress: _spo2 != '--' ? (double.tryParse(_spo2) ?? 0.0) / 100.0 : 0.0,
                icon: Icons.thermostat_rounded, 
                color: const Color(0xFF3B82F6)
              ),
              _VitalCard(
                label: 'Sleep Duration', 
                value: _sleep, 
                unit: 'hrs',
                progress: _sleep != '--' ? (double.tryParse(_sleep) ?? 0.0) / _sleepGoal : 0.0,
                icon: Icons.bedtime_rounded, 
                color: const Color(0xFF6366F1)
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Secondary Vitals Cards
          Row(
            children: [
              Expanded(
                child: _buildSecondaryCard(
                  title: 'Hydration',
                  value: '$_hydration L',
                  sub: 'Goal: $_hydrationGoal L',
                  icon: Icons.local_drink_rounded,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSecondaryCard(
                  title: 'Calories',
                  value: '$_calories kcal',
                  sub: 'Goal: ${_caloriesGoal.toInt()} kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryCard(
                  title: 'Weight Trends',
                  value: '$_weight kg',
                  sub: 'Target stable',
                  icon: Icons.monitor_weight_rounded,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSecondaryCard(
                  title: 'Distance',
                  value: '$_distance km',
                  sub: 'Goal: $_distanceGoal km',
                  icon: Icons.trending_up_rounded,
                  color: Colors.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Vitals History Logs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: Color(0xFF14B8A6))),
          const SizedBox(height: 12),
          if (_records.isEmpty)
             Card(
               elevation: 0,
               color: Theme.of(context).cardColor,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               child: const Padding(
                 padding: EdgeInsets.all(24.0),
                 child: Center(
                   child: Text(
                     'No health records found in database. Vitals synced from Health Connect or logged manually will appear here.',
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Color(0xFF64748B)),
                   ),
                 ),
               ),
             )
          else
            ..._records.map((record) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                      color: Color(0xFF14B8A6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((record['title'] ?? record['record_type'] ?? 'Health Log').toString(),
                          style: TextStyle(fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text('${record['recorded_date']?.toString() ?? 'Recent'} • ${record['notes'] ?? 'No notes'}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            )),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRecordBottomSheet,
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double progress;
  final IconData icon;
  final Color color;

  const _VitalCard({
    required this.label, 
    required this.value,
    required this.unit, 
    required this.progress, 
    required this.icon, 
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          Text('$unit • $label', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}
