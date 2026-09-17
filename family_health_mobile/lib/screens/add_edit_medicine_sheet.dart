import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/medicine_notification_service.dart';

class AddEditMedicineSheet extends StatefulWidget {
  final Map<String, dynamic>? medicineToEdit;
  final VoidCallback onSaved;

  const AddEditMedicineSheet({
    super.key,
    this.medicineToEdit,
    required this.onSaved,
  });

  @override
  State<AddEditMedicineSheet> createState() => _AddEditMedicineSheetState();
}

class _AddEditMedicineSheetState extends State<AddEditMedicineSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _notesController;

  String _dosageUnit = 'Tablet';
  String _frequency = 'ONCE_DAILY';
  List<TimeOfDay> _reminderTimes = [const TimeOfDay(hour: 8, minute: 0)];

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isOngoing = true;
  bool _isActive = true;

  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _units = [
    'Tablet',
    'Capsule',
    'mL',
    'Drops',
    'Injection',
    'Puff',
    'Sachet',
    'Other'
  ];

  static const Map<String, String> _frequencyLabels = {
    'ONCE_DAILY': 'Once Daily',
    'TWICE_DAILY': 'Twice Daily',
    'THREE_TIMES_DAILY': 'Three Times Daily',
    'CUSTOM': 'Custom Times',
  };

  @override
  void initState() {
    super.initState();
    final med = widget.medicineToEdit;

    _nameController = TextEditingController(text: med?['name']?.toString() ?? '');
    _dosageController = TextEditingController(text: med?['dosage']?.toString() ?? '');
    _notesController = TextEditingController(text: med?['notes']?.toString() ?? '');

    if (med != null) {
      _dosageUnit = med['dosage_unit']?.toString() ?? 'Tablet';
      _frequency = med['frequency']?.toString() ?? 'ONCE_DAILY';
      _isActive = med['is_active'] as bool? ?? true;

      // Parse reminder times
      final timesList = med['reminder_times'] as List<dynamic>? ?? [];
      if (timesList.isNotEmpty) {
        _reminderTimes = timesList.map((t) {
          final parts = t.toString().split(':');
          final h = int.tryParse(parts[0]) ?? 8;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          return TimeOfDay(hour: h, minute: m);
        }).toList();
      }

      // Parse start date
      if (med['start_date'] != null) {
        try {
          _startDate = DateTime.parse(med['start_date'].toString());
        } catch (_) {}
      }

      // Parse end date
      if (med['end_date'] != null) {
        try {
          _endDate = DateTime.parse(med['end_date'].toString());
          _isOngoing = false;
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(String? newFreq) {
    if (newFreq == null) return;
    setState(() {
      _frequency = newFreq;
      if (newFreq == 'ONCE_DAILY') {
        _reminderTimes = [const TimeOfDay(hour: 8, minute: 0)];
      } else if (newFreq == 'TWICE_DAILY') {
        _reminderTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
      } else if (newFreq == 'THREE_TIMES_DAILY') {
        _reminderTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTimes[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF14B8A6),
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _reminderTimes[index] = picked;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _isOngoing = false;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderTimes.isEmpty) {
      setState(() => _errorMessage = 'Please set at least one reminder time.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final formattedTimes = _reminderTimes.map(_formatTimeOfDay).toList();

    final payload = {
      'name': _nameController.text.trim(),
      'dosage': _dosageController.text.trim(),
      'dosage_unit': _dosageUnit,
      'frequency': _frequency,
      'reminder_times': formattedTimes,
      'start_date': _formatDate(_startDate),
      'end_date': _isOngoing || _endDate == null ? null : _formatDate(_endDate!),
      'notes': _notesController.text.trim(),
      'is_active': _isActive,
    };

    Map<String, dynamic>? result;
    final editId = widget.medicineToEdit?['id'] as int?;

    if (editId != null) {
      result = await ApiService.updateMedicine(editId, payload);
    } else {
      result = await ApiService.createMedicine(payload);
    }

    if (!mounted) return;

    if (result != null) {
      final savedId = (result['id'] as int?) ?? editId ?? 0;

      // Update local notifications
      if (savedId > 0) {
        await MedicineNotificationService.instance.cancelMedicineReminders(savedId);
        if (_isActive) {
          for (int i = 0; i < formattedTimes.length; i++) {
            await MedicineNotificationService.instance.scheduleDoseReminder(
              medicineId: savedId,
              medicineName: _nameController.text.trim(),
              dosage: _dosageController.text.trim(),
              dosageUnit: _dosageUnit,
              timeStr: formattedTimes[i],
              doseIndex: i,
              notes: _notesController.text.trim(),
            );
          }
        }
      }

      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save medicine. Please check your network connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.medicineToEdit != null;
    final primaryColor = const Color(0xFF14B8A6);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.medication_rounded, color: primaryColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEditing ? 'Edit Medicine' : 'Add Medicine',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Medicine Name Field
                  _buildSectionLabel('Medicine Name *', isDark),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      hint: 'e.g. Paracetamol, Amoxicillin, Metformin',
                      icon: Icons.title_rounded,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dosage & Unit Row
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Dosage *', isDark),
                            TextFormField(
                              controller: _dosageController,
                              keyboardType: TextInputType.text,
                              decoration: _inputDecoration(
                                hint: 'e.g. 500, 1, 10',
                                icon: Icons.scale_rounded,
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter dosage';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Dosage Unit', isDark),
                            Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _dosageUnit,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                  items: _units.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(u, style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      )),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _dosageUnit = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Frequency Selector
                  _buildSectionLabel('Frequency', isDark),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _frequency,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: _frequencyLabels.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value, style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            )),
                          );
                        }).toList(),
                        onChanged: _onFrequencyChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reminder Times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('Reminder Time(s)', isDark),
                      if (_frequency == 'CUSTOM')
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _reminderTimes.add(const TimeOfDay(hour: 12, minute: 0));
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Time', style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_reminderTimes.length, (idx) {
                      final tod = _reminderTimes[idx];
                      return InkWell(
                        onTap: () => _pickTime(idx),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm_rounded, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                tod.format(context),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (_frequency == 'CUSTOM' && _reminderTimes.length > 1) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _reminderTimes.removeAt(idx));
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Dates: Start & End Date
                  _buildSectionLabel('Schedule Duration', isDark),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          onPressed: _pickStartDate,
                          icon: Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(_formatDate(_startDate), style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          onPressed: _pickEndDate,
                          icon: Icon(Icons.event_available_rounded, size: 16, color: primaryColor),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                _isOngoing || _endDate == null ? 'Ongoing' : _formatDate(_endDate!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _isOngoing,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          setState(() {
                            _isOngoing = val ?? true;
                            if (_isOngoing) _endDate = null;
                          });
                        },
                      ),
                      const Text('Ongoing / No end date', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Notes / Instructions
                  _buildSectionLabel('Notes / Instructions', isDark),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _inputDecoration(
                      hint: 'e.g. Take after food with a full glass of water',
                      icon: Icons.notes_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active / Inactive switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isActive ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                              color: _isActive ? primaryColor : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Reminders Active',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isActive,
                          activeThumbColor: primaryColor,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : _saveMedicine,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add Medicine',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF14B8A6), size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
      ),
    );
  }
}
