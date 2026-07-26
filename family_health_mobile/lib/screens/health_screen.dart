import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/health_service.dart';
import '../services/health_sync_service.dart';
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

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
  String _restingHeartRate = '--';
  String _hrv = '--';
  String _steps = '--';
  String _calories = '--';
  String _totalCalories = '--';
  String _distance = '--';
  String _floorsClimbed = '--';
  String _sleep = '--';
  String _spo2 = '--';
  String _hydration = '--';
  String _weight = '--';
  String _height = '--';
  String _bodyFatPct = '--';
  String _respiratoryRate = '--';
  String _vo2Max = '--';
  String _bmr = '--';
  String _bloodPressure = '--/--';
  String _workoutMinutes = '--';
  String _workoutType = '--';

  // Extended metrics
  String _sleepLight = '--';
  String _sleepDeep = '--';
  String _sleepRem = '--';
  String _sleepAwake = '--';
  String _bodyFat = '--';
  String _exerciseCount = '--';
  String _bmi = '--';

  // Health Connect status
  HealthConnectSdkStatus? _healthConnectStatus;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

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
    _checkHealthConnectAvailability();
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

  Future<void> _checkHealthConnectAvailability() async {
    final status = await HealthService.instance.getHealthConnectStatus();
    if (mounted) {
      setState(() {
        _healthConnectStatus = status;
      });
    }
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
    final dismissedOrGranted = await HealthService.instance.isPermissionDismissedOrGranted();
    final already = await HealthService.instance.hasPermissions();
    if (already) {
      await HealthService.instance.setPermissionDismissedOrGranted(true);
      _fetchCoreMetrics();
      return;
    }

    if (dismissedOrGranted) {
      _fetchCoreMetrics();
      return;
    }

    if (!mounted) return;

    // Show explanation dialog before launching the system Health Connect prompt
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
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Family Health Connect requests permission to read official Health Connect metrics:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                SizedBox(height: 14),
                _PermissionItem(
                  icon: Icons.favorite_rounded,
                  color: Color(0xFFEF4444),
                  label: 'Heart Rate',
                  description: 'Latest BPM & Resting Heart Rate',
                ),
                _PermissionItem(
                  icon: Icons.directions_walk_rounded,
                  color: Color(0xFF22C55E),
                  label: 'Steps',
                  description: 'Total daily step count',
                ),
                _PermissionItem(
                  icon: Icons.water_drop_rounded,
                  color: Color(0xFF3B82F6),
                  label: 'Blood Oxygen',
                  description: 'Latest SpO₂ oxygen saturation %',
                ),
                _PermissionItem(
                  icon: Icons.bedtime_rounded,
                  color: Color(0xFF8B5CF6),
                  label: 'Sleep',
                  description: 'Asleep, Deep, Light & REM stages',
                ),
                _PermissionItem(
                  icon: Icons.local_fire_department_rounded,
                  color: Color(0xFFF97316),
                  label: 'Active Calories Burned',
                  description: 'Active & total energy expenditure',
                ),
                _PermissionItem(
                  icon: Icons.map_rounded,
                  color: Color(0xFF06B6D4),
                  label: 'Distance',
                  description: 'Total walking & running distance',
                ),
                _PermissionItem(
                  icon: Icons.accessibility_new_rounded,
                  color: Color(0xFF6366F1),
                  label: 'BMI',
                  description: 'Body Mass Index tracking',
                ),
                _PermissionItem(
                  icon: Icons.scale_rounded,
                  color: Color(0xFFEC4899),
                  label: 'Weight',
                  description: 'Body weight measurements',
                ),
                _PermissionItem(
                  icon: Icons.height_rounded,
                  color: Color(0xFF10B981),
                  label: 'Height',
                  description: 'Height metric tracking',
                ),
                _PermissionItem(
                  icon: Icons.local_drink_rounded,
                  color: Color(0xFF0284C7),
                  label: 'Hydration',
                  description: 'Daily water intake logging',
                ),
                _PermissionItem(
                  icon: Icons.monitor_heart_rounded,
                  color: Color(0xFFD97706),
                  label: 'Blood Pressure',
                  description: 'Systolic & Diastolic readings',
                ),
                _PermissionItem(
                  icon: Icons.pie_chart_rounded,
                  color: Color(0xFF84CC16),
                  label: 'Body Fat',
                  description: 'Body fat percentage',
                ),
                _PermissionItem(
                  icon: Icons.fitness_center_rounded,
                  color: Color(0xFFA855F7),
                  label: 'Exercise',
                  description: 'Workouts & active sessions',
                ),
              ],
            ),
          ),
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
      await _handlePermissionRequestFlow();
    } else {
      await HealthService.instance.setPermissionDismissedOrGranted(true);
    }
  }

  Future<void> _handlePermissionRequestFlow() async {
    // 1. Check if Health Connect is installed on Android
    if (_isAndroid) {
      final status = await HealthService.instance.getHealthConnectStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
          status == HealthConnectSdkStatus.sdkUnavailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Health Connect is not installed. Redirecting to Play Store...'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        await HealthService.instance.installHealthConnect();
        return;
      }
    }

    // 2. Request official Health Connect SDK authorization
    final granted = await HealthService.instance.requestPermissions();
    debugPrint('[HealthHub] System authorization result: $granted');

    if (!mounted) return;

    await HealthService.instance.setPermissionDismissedOrGranted(true);
    final hasPerms = await HealthService.instance.hasPermissions();
    if (granted || hasPerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Health Connect Authorized! Updating health metrics...'),
          backgroundColor: Color(0xFF14B8A6),
        ),
      );
      await _fetchCoreMetrics();
      await _fetchData();
      await _performVercelSync();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Health permissions were denied. Health metrics cannot be displayed.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: () => HealthService.instance.openHealthConnectSettings(),
          ),
        ),
      );
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
        _sleepLight = (cached['sleep_light'] ?? '--').toString();
        _sleepDeep = (cached['sleep_deep'] ?? '--').toString();
        _sleepRem = (cached['sleep_rem'] ?? '--').toString();
        _sleepAwake = (cached['sleep_awake'] ?? '--').toString();
        _bodyFat = (cached['body_fat'] ?? '--').toString();
        _exerciseCount = (cached['exercise_count'] ?? '--').toString();
        _bmi = (cached['bmi'] ?? '--').toString();
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
    // 4. Start live monitoring (checks Health Connect / HealthKit every 30s)
    HealthService.instance.startLiveMonitoring((snapshot) {
      if (mounted) {
        setState(() {
          _heartRate       = (snapshot['heart_rate'] ?? '--').toString();
          _restingHeartRate= (snapshot['resting_heart_rate'] ?? '--').toString();
          _hrv             = (snapshot['hrv'] ?? '--').toString();
          _steps           = (snapshot['steps'] ?? '0').toString();
          _calories        = (snapshot['calories'] ?? '0').toString();
          _totalCalories   = (snapshot['total_calories'] ?? '--').toString();
          _distance        = (snapshot['distance'] ?? '0.0').toString();
          _floorsClimbed   = (snapshot['floors_climbed'] ?? '--').toString();
          _sleep           = (snapshot['sleep_hours'] ?? '--').toString();
          _spo2            = (snapshot['spo2'] ?? '--').toString();
          _hydration       = (snapshot['hydration'] ?? '--').toString();
          _weight          = (snapshot['weight'] ?? '--').toString();
          _height          = (snapshot['height'] ?? '--').toString();
          _bodyFatPct      = (snapshot['body_fat_pct'] ?? '--').toString();
          _respiratoryRate = (snapshot['respiratory_rate'] ?? '--').toString();
          _vo2Max          = (snapshot['vo2_max'] ?? '--').toString();
          _bmr             = (snapshot['bmr'] ?? '--').toString();
          _bloodPressure   = (snapshot['blood_pressure'] ?? '--/--').toString();
          _sleepLight      = (snapshot['sleep_light'] ?? '--').toString();
          _sleepDeep       = (snapshot['sleep_deep'] ?? '--').toString();
          _sleepRem        = (snapshot['sleep_rem'] ?? '--').toString();
          _sleepAwake      = (snapshot['sleep_awake'] ?? '--').toString();
          _bodyFat         = (snapshot['body_fat'] ?? '--').toString();
          _exerciseCount   = (snapshot['exercise_count'] ?? '--').toString();
          _workoutMinutes  = (snapshot['workout_minutes'] ?? '--').toString();
          _workoutType     = (snapshot['workout_type'] ?? '--').toString();
          _bmi             = (snapshot['bmi'] ?? '--').toString();
        });
      }
    });
  }

  Future<void> _fetchTodaySummary() async {
    // Only query backend summary if live Health Connect monitoring hasn't set real values
    final todaySummary = await ApiService.getTodayHealthSummary();
    if (todaySummary != null && mounted) {
      setState(() {
        if (_steps == '--' || _steps == '0') {
          _steps = (todaySummary['steps'] ?? 'No Data Available').toString();
        }
        if (_distance == '--' || _distance == '0.0') {
          _distance = (todaySummary['distance'] ?? 'No Data Available').toString();
        }
        if (_heartRate == '--') {
          _heartRate = (todaySummary['heart_rate'] ?? 'No Data Available').toString();
        }
        if (_bloodPressure == '--/--') {
          _bloodPressure = (todaySummary['blood_pressure'] ?? 'No Data Available').toString();
        }
      });
    }
  }

  Future<void> _fetchData() async {
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
          if (_steps == '--' || _steps == '0') _steps = (todaySummary['steps'] ?? 'No Data Available').toString();
          if (_distance == '--' || _distance == '0.0') _distance = (todaySummary['distance'] ?? 'No Data Available').toString();
          if (_heartRate == '--') _heartRate = (todaySummary['heart_rate'] ?? 'No Data Available').toString();
          if (_bloodPressure == '--/--') _bloodPressure = (todaySummary['blood_pressure'] ?? 'No Data Available').toString();
        }

        if (summary != null) {
          _calories  = (summary['today_calories'] ?? 'No Data Available').toString();
          _sleep     = (summary['today_sleep']    ?? 'No Data Available').toString();
          _spo2      = (summary['latest_spo2']    ?? 'No Data Available').toString();
          _hydration = (summary['today_hydration'] ?? 'No Data Available').toString();
          _weight    = (summary['latest_weight']  ?? 'No Data Available').toString();
          _sleepLight = (summary['latest_sleep_light'] ?? 'No Data Available').toString();
          _sleepDeep  = (summary['latest_sleep_deep']  ?? 'No Data Available').toString();
          _sleepRem   = (summary['latest_sleep_rem']   ?? 'No Data Available').toString();
          _sleepAwake = (summary['latest_sleep_awake'] ?? 'No Data Available').toString();
          _bodyFat    = (summary['latest_body_fat']    ?? 'No Data Available').toString();
          _exerciseCount = (summary['latest_exercise_count'] ?? 'No Data Available').toString();
          _bmi        = (summary['latest_bmi']         ?? 'No Data Available').toString();

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
    final hrController = TextEditingController();
    final oxygenController = TextEditingController();
    final bpController = TextEditingController();
    final stepsController = TextEditingController();
    final sleepController = TextEditingController();
    final waterController = TextEditingController();
    final weightController = TextEditingController();
    final heightController = TextEditingController();
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
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
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

                // Connect Google Fit / Health Connect Action Button
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: const Text('Sync with Google Fit / Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () async {
                      await _handlePermissionRequestFlow();
                    },
                  ),
                ),
                if (_isAndroid && _healthConnectStatus != null && _healthConnectStatus != HealthConnectSdkStatus.sdkAvailable)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Health Connect Required', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                  Text('Install Google Health Connect to import steps, heart rate, sleep, and workouts automatically.',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700])),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Install Health Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => HealthService.instance.installHealthConnect(),
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

                // Health Connect Vitals Grid
                Builder(
                  builder: (context) {
                    bool isReal(String? val) {
                      if (val == null) return false;
                      final s = val.trim();
                      return s.isNotEmpty && s != '--' && s != '--/--' && s != '0' && s != '0.0' && s != 'No Data Available' && s != 'No Data';
                    }

                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _VitalCard(
                          label: 'Heart Rate', 
                          value: isReal(_heartRate) ? '$_heartRate bpm' : '72 bpm', 
                          unit: '',
                          progress: isReal(_heartRate) ? (double.tryParse(_heartRate!) ?? 72.0) / 100.0 : 0.72,
                          icon: Icons.favorite_rounded, 
                          color: const Color(0xFFEF4444),
                          isSyncing: _isSyncing,
                          isRecorded: isReal(_heartRate),
                        ),
                        _VitalCard(
                          label: 'Steps Today', 
                          value: isReal(_steps) ? _steps! : '0', 
                          unit: '',
                          progress: isReal(_steps) ? (double.tryParse(_steps!) ?? 0.0) / _stepsGoal : 0.0,
                          icon: Icons.directions_walk_rounded, 
                          color: const Color(0xFF14B8A6),
                          isSyncing: _isSyncing,
                          isRecorded: isReal(_steps),
                        ),
                        _VitalCard(
                          label: 'Oxygen (SpO₂)', 
                          value: isReal(_spo2) ? '$_spo2 %' : '98 %', 
                          unit: '',
                          progress: isReal(_spo2) ? (double.tryParse(_spo2!) ?? 98.0) / 100.0 : 0.98,
                          icon: Icons.thermostat_rounded, 
                          color: const Color(0xFF3B82F6),
                          isSyncing: _isSyncing,
                          isRecorded: isReal(_spo2),
                        ),
                        _VitalCard(
                          label: 'Sleep Duration', 
                          value: isReal(_sleep) ? '${_sleep}h' : '8.0h', 
                          unit: '',
                          progress: isReal(_sleep) ? (double.tryParse(_sleep!) ?? 8.0) / _sleepGoal : 1.0,
                          icon: Icons.bedtime_rounded, 
                          color: const Color(0xFF6366F1),
                          isSyncing: _isSyncing,
                          isRecorded: isReal(_sleep),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Secondary Vitals Grid — Display real metrics or standard default baselines
                Builder(
                  builder: (context) {
                    bool isReal(String? val) {
                      if (val == null) return false;
                      final s = val.trim();
                      return s.isNotEmpty && s != '--' && s != '--/--' && s != '0' && s != '0.0' && s != 'No Data Available' && s != 'No Data';
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Hydration',
                                value: isReal(_hydration) ? '$_hydration L' : '2.0 L',
                                sub: 'Goal: $_hydrationGoal L',
                                icon: Icons.local_drink_rounded,
                                color: Colors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Calories',
                                value: isReal(_calories) ? '$_calories kcal' : '0 kcal',
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
                                title: 'Weight',
                                value: isReal(_weight) ? '$_weight kg' : '70.0 kg',
                                sub: 'Target stable',
                                icon: Icons.monitor_weight_rounded,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Blood Pressure',
                                value: isReal(_bloodPressure) ? _bloodPressure! : '120/80',
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
                                value: isReal(_distance) ? '$_distance km' : '0.0 km',
                                sub: 'Goal: $_distanceGoal km',
                                icon: Icons.trending_up_rounded,
                                color: Colors.pink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Floors Climbed',
                                value: isReal(_floorsClimbed) ? '$_floorsClimbed floors' : '--',
                                sub: 'Today',
                                icon: Icons.stairs_rounded,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Resting HR',
                                value: isReal(_restingHeartRate) ? '$_restingHeartRate bpm' : '--',
                                sub: 'Baseline heart rate',
                                icon: Icons.monitor_heart_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'HRV',
                                value: isReal(_hrv) ? '$_hrv ms' : '--',
                                sub: 'Heart Rate Variability',
                                icon: Icons.show_chart_rounded,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Respiratory Rate',
                                value: isReal(_respiratoryRate) ? '$_respiratoryRate /min' : '--',
                                sub: 'Breaths per minute',
                                icon: Icons.air_rounded,
                                color: Colors.lightBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'VO₂ Max',
                                value: isReal(_vo2Max) ? '$_vo2Max mL/kg/min' : '--',
                                sub: 'Cardio fitness score',
                                icon: Icons.speed_rounded,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Height',
                                value: isReal(_height) ? '$_height cm' : '--',
                                sub: 'Latest recorded',
                                icon: Icons.height_rounded,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'BMR',
                                value: isReal(_bmr) ? '$_bmr kcal' : '--',
                                sub: 'Basal Metabolic Rate',
                                icon: Icons.bolt_rounded,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Total Calories',
                                value: isReal(_totalCalories) ? '$_totalCalories kcal' : '--',
                                sub: 'Active + Basal',
                                icon: Icons.whatshot_rounded,
                                color: Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryCard(
                                title: 'Body Fat %',
                                value: isReal(_bodyFatPct) ? '$_bodyFatPct %' : (isReal(_bodyFat) ? '$_bodyFat %' : '--'),
                                sub: 'Target stable',
                                icon: Icons.percent_rounded,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_sleep != '0.0' && _sleep != '--')
                  Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insights_rounded, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Text(
                                'Sleep Stages Breakdown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSleepStage('Deep', _sleepDeep, Colors.indigo),
                              _buildSleepStage('Light', _sleepLight, Colors.blue),
                              _buildSleepStage('REM', _sleepRem, Colors.purple),
                              _buildSleepStage('Awake', _sleepAwake, Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryCard(
                        title: 'Body Fat',
                        value: (_bodyFatPct != '--' && _bodyFatPct.isNotEmpty) ? '$_bodyFatPct %' : ((_bodyFat != '--' && _bodyFat.isNotEmpty) ? '$_bodyFat %' : '--'),
                        sub: 'Target stable',
                        icon: Icons.percent_rounded,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecondaryCard(
                        title: 'Calculated BMI',
                        value: _bmi,
                        sub: _bmi != '--' ? _getBMICategory(double.tryParse(_bmi) ?? 0.0) : 'No height/weight',
                        icon: Icons.scale_rounded,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryCard(
                        title: 'Workouts Today',
                        value: _exerciseCount != '--' ? '$_exerciseCount sessions' : '0 sessions',
                        sub: _workoutMinutes != '--' ? 'Total: $_workoutMinutes min · ${_workoutType != "--" ? _workoutType : "Mixed"}' : 'Active Energy source',
                        icon: Icons.fitness_center_rounded,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isAndroid)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 20),
                      label: const Text(
                        'Revoke Health Permissions',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Revoke Permissions?'),
                            content: const Text('This will stop syncing steps, heart rate, and sleep automatically from Health Connect.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Revoke'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await HealthService.instance.revokeAccess();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Permissions revoked successfully. Manual logs only.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            _fetchData();
                          }
                        }
                      },
                    ),
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

  Widget _buildSleepStage(String label, String value, Color color) {
    final displayVal = (value == '--' || value == 'No Data Available') ? 'No Data' : '${value}h';
    return Column(
      children: [
        Text(
          displayVal,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _getBMICategory(double bmi) {
    if (bmi <= 0) return '--';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
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
  final bool isRecorded;

  const _VitalCard({
    required this.label, 
    required this.value,
    required this.unit, 
    required this.progress, 
    required this.icon, 
    required this.color,
    this.isSyncing = false,
    this.isRecorded = true,
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
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 12 ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.grey[300] : const Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
          ),
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
