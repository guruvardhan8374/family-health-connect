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

class _HealthScreenState extends State<HealthScreen> with WidgetsBindingObserver {
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
  Timer? _pollingTimer;

  // ── Core metrics & Vercel sync state ──────────────────────────────────────
  double _hubHeartRate   = 0.0;
  int    _hubSteps       = 0;
  double _hubBloodOxygen = 0.0;
  double _hubSleepHours  = 0.0;
  bool   _hubLoading     = false;

  Timer?    _fifteenMinSyncTimer;
  DateTime? _lastSyncedAt;
  bool      _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHealthSync();
    _startPeriodic15MinSync();

    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'health.update') {
        _fetchData();
      }
    });
    // Poll today's summary every 20 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _fetchTodaySummary();
    });
    // Ask for permissions then trigger initial Vercel sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestHealthPermissionsWithDialog();
      _performVercelSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fifteenMinSyncTimer?.cancel();
    _syncSubscription?.cancel();
    _pollingTimer?.cancel();
    HealthService.instance.stopLiveMonitoring();
    HealthSyncService.instance.disconnect();
    super.dispose();
  }

  // ── App Lifecycle: Sync when app comes to foreground ─────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HealthHub] App resumed to foreground — triggering sync');
      _performVercelSync();
    }
  }

  // ── Periodic 15-Minute Sync ───────────────────────────────────────────────
  void _startPeriodic15MinSync() {
    _fifteenMinSyncTimer?.cancel();
    _fifteenMinSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      debugPrint('[HealthHub] 15-minute periodic timer — triggering sync');
      _performVercelSync();
    });
  }

  // ── Core Sync Handler (Foreground / 15-Min Timer / Pull-to-Refresh) ───────
  Future<void> _performVercelSync() async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);
    try {
      await _fetchCoreMetrics();
      final success = await HealthService.instance.syncMetricsToVercel();
      debugPrint('[HealthHub] Vercel sync result: $success');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncedAt = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('[HealthHub] Sync error: $e');
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _formatSyncedTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // ── Health permission dialog + core metric fetch ─────────────────────────

  /// Shows a friendly explanation dialog then triggers the OS permission sheet.
  /// Called once when the Health Hub screen opens for the first time.
  Future<void> _requestHealthPermissionsWithDialog() async {
    // Skip if we already have permissions
    final already = await HealthService.instance.hasPermissions();
    if (already) {
      _fetchCoreMetrics();
      return;
    }

    if (!mounted) return;

    // Show explanation dialog before the system prompt
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Color(0xFF14B8A6), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Health Data Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Health Connect would like to read the following from your device:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            SizedBox(height: 16),
            _PermissionItem(
              icon: Icons.favorite_rounded,
              color: Color(0xFFEF4444),
              label: 'Heart Rate',
              description: 'Latest BPM reading',
            ),
            _PermissionItem(
              icon: Icons.directions_walk_rounded,
              color: Color(0xFF22C55E),
              label: 'Step Count',
              description: 'Total steps today',
            ),
            _PermissionItem(
              icon: Icons.water_drop_rounded,
              color: Color(0xFF3B82F6),
              label: 'Blood Oxygen',
              description: 'Latest SpO₂ reading',
            ),
            _PermissionItem(
              icon: Icons.bedtime_rounded,
              color: Color(0xFF8B5CF6),
              label: 'Sleep',
              description: 'Hours slept last night',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Allow Access',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      final granted = await HealthService.instance.requestPermissions();
      debugPrint('[HealthHub] Permissions granted: $granted');
      if (granted) _fetchCoreMetrics();
    }
  }

  /// Fetches today's four core metrics and updates the Hub summary card.
  Future<void> _fetchCoreMetrics() async {
    if (!mounted) return;
    setState(() => _hubLoading = true);
    try {
      final metrics = await HealthService.instance.fetchTodayMetrics();
      if (mounted) {
        setState(() {
          _hubHeartRate   = (metrics['heart_rate']   as num).toDouble();
          _hubSteps       = (metrics['steps']        as num).toInt();
          _hubBloodOxygen = (metrics['blood_oxygen'] as num).toDouble();
          _hubSleepHours  = (metrics['sleep_hours']  as num).toDouble();
          _hubLoading     = false;

          if (_hubHeartRate > 0) _heartRate = _hubHeartRate.toStringAsFixed(0);
          if (_hubSteps > 0) _steps = _hubSteps.toString();
          if (_hubBloodOxygen > 0) _spo2 = _hubBloodOxygen.toStringAsFixed(1);
          if (_hubSleepHours > 0) _sleep = _hubSleepHours.toStringAsFixed(1);
        });
      }
    } catch (e) {
      debugPrint('[HealthHub] fetchCoreMetrics error: $e');
      if (mounted) setState(() => _hubLoading = false);
    }
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

  Future<void> _fetchTodaySummary() async {
    final todaySummary = await ApiService.getTodayHealthSummary();
    if (todaySummary != null && mounted) {
      setState(() {
        _steps = (todaySummary['steps'] ?? '0').toString();
        _distance = (todaySummary['distance'] ?? '0.0').toString();
        _heartRate = (todaySummary['heart_rate'] ?? '--').toString();
        _bloodPressure = (todaySummary['blood_pressure'] ?? '--/--').toString();
      });
    }
  }

  Future<void> _fetchData() async {
    // ── Run all 3 calls in PARALLEL — was sequential (3× slower) ──────────
    final results = await Future.wait([
      ApiService.getHealthData(),
      ApiService.getHealthSummary(range: 'daily'),
      ApiService.getTodayHealthSummary(),
    ]);

    final records     = results[0] as List<dynamic>;
    final summary     = results[1] as Map<String, dynamic>?;
    final todaySummary = results[2] as Map<String, dynamic>?;

    if (mounted) {
      setState(() {
        _records  = records;
        _isLoading = false;

        if (todaySummary != null) {
          _steps         = (todaySummary['steps']          ?? '0').toString();
          _distance      = (todaySummary['distance']       ?? '0.0').toString();
          _heartRate     = (todaySummary['heart_rate']     ?? '--').toString();
          _bloodPressure = (todaySummary['blood_pressure'] ?? '--/--').toString();
        }

        if (summary != null) {
          _calories  = (summary['today_calories'] ?? '0').toString();
          _sleep     = (summary['today_sleep']    ?? '--').toString();
          _spo2      = (summary['latest_spo2']    ?? '--').toString();
          _hydration = (summary['today_hydration'] ?? '--').toString();
          _weight    = (summary['latest_weight']  ?? '--').toString();

          final goal = summary['goal'];
          if (goal != null) {
            _stepsGoal     = goal['steps_goal']     ?? 10000;
            _caloriesGoal  = (goal['calories_goal']  ?? 2000.0).toDouble();
            _hydrationGoal = (goal['hydration_goal'] ?? 2.0).toDouble();
            _sleepGoal     = (goal['sleep_goal']     ?? 8.0).toDouble();
            _distanceGoal  = (goal['distance_goal']  ?? 5.0).toDouble();
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

                              if (success) {
                                // Log to the new metrics endpoint in parallel
                                double? systolic;
                                double? diastolic;
                                if (bp.contains('/')) {
                                  final parts = bp.split('/');
                                  if (parts.length == 2) {
                                    systolic = double.tryParse(parts[0].trim());
                                    diastolic = double.tryParse(parts[1].trim());
                                  }
                                }
                                
                                final List<Future<bool>> metricsLog = [
                                  ApiService.logHealthMetric('HEART_RATE', hr.toDouble()),
                                  if (systolic != null) ApiService.logHealthMetric('BLOOD_PRESSURE_SYSTOLIC', systolic),
                                  if (diastolic != null) ApiService.logHealthMetric('BLOOD_PRESSURE_DIASTOLIC', diastolic),
                                  ApiService.logHealthMetric('WEIGHT', weight.toDouble()),
                                ];
                                await Future.wait(metricsLog);
                              }

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
        color: Colors.white.withValues(alpha: dark ? 0.05 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          if (_hubLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF14B8A6),
                ),
              ),
            ),
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
        : RefreshIndicator(
            onRefresh: _performVercelSync,
            color: const Color(0xFF14B8A6),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Last Synced Status Label
                if (_lastSyncedAt != null || _isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded,
                          size: 14,
                          color: const Color(0xFF14B8A6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSyncing
                              ? 'Syncing metrics to cloud...'
                              : 'Last synced at ${_formatSyncedTime(_lastSyncedAt!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Emergency Vital Alert
                if (hasEmergency)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: alertColor.withValues(alpha: 0.3)),
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
                      color: const Color(0xFFEF4444),
                      isSyncing: _isSyncing,
                    ),
                    _VitalCard(
                      label: 'Steps Today', 
                      value: _steps, 
                      unit: 'steps',
                      progress: _steps != '--' ? (double.tryParse(_steps) ?? 0.0) / _stepsGoal : 0.0,
                      icon: Icons.directions_walk_rounded, 
                      color: const Color(0xFF14B8A6),
                      isSyncing: _isSyncing,
                    ),
                    _VitalCard(
                      label: 'Oxygen (SpO₂)', 
                      value: _spo2, 
                      unit: '%',
                      progress: _spo2 != '--' ? (double.tryParse(_spo2) ?? 0.0) / 100.0 : 0.0,
                      icon: Icons.thermostat_rounded, 
                      color: const Color(0xFF3B82F6),
                      isSyncing: _isSyncing,
                    ),
                    _VitalCard(
                      label: 'Sleep Duration', 
                      value: _sleep, 
                      unit: 'hrs',
                      progress: _sleep != '--' ? (double.tryParse(_sleep) ?? 0.0) / _sleepGoal : 0.0,
                      icon: Icons.bedtime_rounded, 
                      color: const Color(0xFF6366F1),
                      isSyncing: _isSyncing,
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
                        title: 'Blood Pressure',
                        value: _bloodPressure,
                        sub: 'Target: 120/80',
                        icon: Icons.favorite_border_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
  final bool isSyncing;

  const _VitalCard({
    required this.label, 
    required this.value,
    required this.unit, 
    required this.progress, 
    required this.icon, 
    required this.color,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
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
                child: isSyncing
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF14B8A6),
                      )
                    : CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
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

// ── _PermissionItem ───────────────────────────────────────────────────────────
// Small row widget used inside the health permission explanation dialog.
// Shows an icon + label + description for a single health data type.
class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
