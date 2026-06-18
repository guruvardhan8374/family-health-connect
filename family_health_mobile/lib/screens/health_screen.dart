import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;

  String _heartRate = '--';
  String _bloodPressure = '--/--';
  String _steps = '--';
  String _sleep = '--';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final records = await ApiService.getHealthData();
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
        
        if (records.isNotEmpty) {
          final latest = records.first;
          _heartRate = (latest['heart_rate'] ?? '--').toString();
          _bloodPressure = (latest['blood_pressure'] ?? '--/--').toString();
          
          final stepsNum = latest['steps'];
          if (stepsNum != null) {
            _steps = stepsNum >= 1000 
                ? '${(stepsNum / 1000.0).toStringAsFixed(1)}k' 
                : stepsNum.toString();
          } else {
            _steps = '--';
          }
          
          _sleep = (latest['sleep_hours'] ?? '--').toString();
        } else {
          _heartRate = '--';
          _bloodPressure = '--/--';
          _steps = '--';
          _sleep = '--';
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
                  
                  // Two-column fields
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

                              final success = await ApiService.createHealthRecord({
                                'heart_rate': hr,
                                'oxygen_level': oxy,
                                'blood_pressure': bp,
                                'steps': steps,
                                'sleep_hours': sleep,
                                'water_intake': water,
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Health Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF14B8A6)),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchData();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
        : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vitals Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _VitalCard(label: 'Heart Rate', value: _heartRate, unit: 'bpm',
                icon: Icons.favorite_rounded, color: const Color(0xFFEF4444)),
              _VitalCard(label: 'Blood Pressure', value: _bloodPressure, unit: 'mmHg',
                icon: Icons.water_drop_rounded, color: const Color(0xFF6366F1)),
              _VitalCard(label: 'Steps Today', value: _steps, unit: 'steps',
                icon: Icons.directions_walk_rounded, color: const Color(0xFF14B8A6)),
              _VitalCard(label: 'Sleep', value: _sleep, unit: 'hrs',
                icon: Icons.bedtime_rounded, color: const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Records',
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
                     'No health records found in database. Tap the "+" button to log your first entry!',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRecordBottomSheet,
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  const _VitalCard({required this.label, required this.value,
    required this.unit, required this.icon, required this.color});

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
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          Text('$unit • $label', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}
