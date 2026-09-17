import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/medicine_notification_service.dart';
import 'add_edit_medicine_sheet.dart';

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _todayData;
  List<dynamic> _allMedicines = [];
  final Set<String> _markingTakenSet = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getTodayMedicines(),
      ApiService.getMedicines(),
    ]);

    if (mounted) {
      setState(() {
        _todayData = results[0] as Map<String, dynamic>?;
        _allMedicines = (results[1] as List<dynamic>?) ?? [];
        _isLoading = false;
      });

      // Synchronize notifications with current active medicines
      MedicineNotificationService.instance.syncAllActiveReminders(_allMedicines);
    }
  }

  Future<void> _markDoseTaken(int medicineId, String doseTime) async {
    final key = '${medicineId}_$doseTime';
    if (_markingTakenSet.contains(key)) return;

    setState(() => _markingTakenSet.add(key));

    final res = await ApiService.markMedicineTaken(medicineId, doseTime);

    if (mounted) {
      setState(() => _markingTakenSet.remove(key));

      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(res['message']?.toString() ?? 'Marked as taken!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update status. Check your connection.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _toggleMedicineActive(Map<String, dynamic> med, bool currentStatus) async {
    final int id = med['id'] as int? ?? 0;
    if (id <= 0) return;

    final newStatus = !currentStatus;
    final res = await ApiService.updateMedicine(id, {'is_active': newStatus});

    if (res != null && mounted) {
      if (newStatus) {
        // Reschedule
        final name = med['name']?.toString() ?? 'Medicine';
        final dosage = med['dosage']?.toString() ?? '1';
        final unit = med['dosage_unit']?.toString() ?? 'Tablet';
        final notes = med['notes']?.toString();
        final times = med['reminder_times'] as List<dynamic>? ?? [];
        for (int i = 0; i < times.length; i++) {
          await MedicineNotificationService.instance.scheduleDoseReminder(
            medicineId: id,
            medicineName: name,
            dosage: dosage,
            dosageUnit: unit,
            timeStr: times[i].toString(),
            doseIndex: i,
            notes: notes,
          );
        }
      } else {
        await MedicineNotificationService.instance.cancelMedicineReminders(id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Reminders enabled' : 'Reminders disabled'),
          backgroundColor: newStatus ? const Color(0xFF14B8A6) : const Color(0xFF64748B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _loadData();
    }
  }

  Future<void> _deleteMedicine(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Medicine?'),
        content: Text('Are you sure you want to delete "$name"? All scheduled dose logs and reminders will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteMedicine(id);
      if (success && mounted) {
        await MedicineNotificationService.instance.cancelMedicineReminders(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$name"'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadData();
      }
    }
  }

  void _openAddEditSheet([Map<String, dynamic>? med]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditMedicineSheet(
        medicineToEdit: med,
        onSaved: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Medicine Reminders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: primaryColor, size: 20),
              ),
              tooltip: 'Add Medicine',
              onPressed: () => _openAddEditSheet(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Today's Schedule"),
            Tab(text: "All Medicines"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(isDark),
                _buildAllMedicinesTab(isDark),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openAddEditSheet(),
      ),
    );
  }

  Widget _buildTodayTab(bool isDark) {
    final doses = (_todayData?['doses'] as List<dynamic>?) ?? [];
    final int total = _todayData?['total_doses'] as int? ?? 0;
    final int taken = _todayData?['taken_doses'] as int? ?? 0;
    final int missed = _todayData?['missed_doses'] as int? ?? 0;
    final int upcoming = _todayData?['upcoming_doses'] as int? ?? 0;

    return RefreshIndicator(
      color: const Color(0xFF14B8A6),
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // Top Statistics Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Progress",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$taken / $total Taken',
                        style: const TextStyle(
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (taken / total) : 0.0,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatPill('Total', total.toString(), const Color(0xFF6366F1), isDark),
                    const SizedBox(width: 8),
                    _buildStatPill('Taken', taken.toString(), const Color(0xFF10B981), isDark),
                    const SizedBox(width: 8),
                    _buildStatPill('Upcoming', upcoming.toString(), const Color(0xFF0EA5E9), isDark),
                    const SizedBox(width: 8),
                    _buildStatPill('Missed', missed.toString(), const Color(0xFFEF4444), isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          Text(
            'Scheduled Doses Today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),

          if (doses.isEmpty)
            _buildEmptyTodayCard(isDark)
          else
            ...doses.map((dose) => _buildTodayDoseCard(dose as Map<String, dynamic>, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDoseCard(Map<String, dynamic> dose, bool isDark) {
    final String name = dose['medicine_name']?.toString() ?? 'Medicine';
    final String dosage = dose['dosage']?.toString() ?? '';
    final String unit = dose['dosage_unit']?.toString() ?? '';
    final String doseTime = dose['dose_time']?.toString() ?? '00:00';
    final String status = dose['status']?.toString().toUpperCase() ?? 'UPCOMING';
    final String? notes = dose['notes']?.toString();
    final int medicineId = dose['medicine_id'] as int? ?? 0;
    final key = '${medicineId}_$doseTime';
    final bool isMarking = _markingTakenSet.contains(key);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'TAKEN':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        final takenAtStr = dose['taken_at']?.toString();
        String timeDisplay = doseTime;
        if (takenAtStr != null) {
          try {
            final dt = DateTime.parse(takenAtStr).toLocal();
            timeDisplay = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }
        statusLabel = 'Taken ($timeDisplay)';
        break;
      case 'MISSED':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline_rounded;
        statusLabel = 'Missed';
        break;
      case 'UPCOMING':
      default:
        statusColor = const Color(0xFF0EA5E9);
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Upcoming';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.medication_liquid_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dosage $unit',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Scheduled: $doseTime',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              if (status != 'TAKEN')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isMarking ? null : () => _markDoseTaken(medicineId, doseTime),
                  icon: isMarking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    isMarking ? 'Saving...' : 'Mark as Taken',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Row(
                  children: const [
                    Icon(Icons.done_all_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (notes != null && notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTodayCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF14B8A6), size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'No medicines scheduled for today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All caught up or no active prescriptions. Tap below to add a new medicine reminder.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF14B8A6),
              side: const BorderSide(color: Color(0xFF14B8A6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _openAddEditSheet(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Medicine'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllMedicinesTab(bool isDark) {
    if (_allMedicines.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF14B8A6),
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_rounded, size: 54, color: Color(0xFF14B8A6)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'No Medicines Added Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Keep track of your daily prescriptions, dosages, and get automated device reminders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _openAddEditSheet(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Your First Medicine',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    final activeMeds = _allMedicines.where((m) => (m['is_active'] as bool? ?? true)).toList();
    final inactiveMeds = _allMedicines.where((m) => !(m['is_active'] as bool? ?? true)).toList();

    return RefreshIndicator(
      color: const Color(0xFF14B8A6),
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (activeMeds.isNotEmpty) ...[
            _buildSectionHeader('Active Medicines (${activeMeds.length})', isDark),
            const SizedBox(height: 10),
            ...activeMeds.map((med) => _buildMedicineManageCard(med as Map<String, dynamic>, isDark)),
            const SizedBox(height: 16),
          ],

          if (inactiveMeds.isNotEmpty) ...[
            _buildSectionHeader('Paused / Inactive (${inactiveMeds.length})', isDark),
            const SizedBox(height: 10),
            ...inactiveMeds.map((med) => _buildMedicineManageCard(med as Map<String, dynamic>, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildMedicineManageCard(Map<String, dynamic> med, bool isDark) {
    final int id = med['id'] as int? ?? 0;
    final String name = med['name']?.toString() ?? 'Medicine';
    final String dosage = med['dosage']?.toString() ?? '';
    final String unit = med['dosage_unit']?.toString() ?? '';
    final String freq = med['frequency']?.toString() ?? 'ONCE_DAILY';
    final List<dynamic> times = (med['reminder_times'] as List<dynamic>?) ?? [];
    final bool isActive = med['is_active'] as bool? ?? true;
    final String? notes = med['notes']?.toString();
    final String startDate = med['start_date']?.toString() ?? '';
    final String? endDate = med['end_date']?.toString();

    String freqLabel = freq.replaceAll('_', ' ');
    if (freq == 'ONCE_DAILY') freqLabel = 'Once Daily';
    if (freq == 'TWICE_DAILY') freqLabel = 'Twice Daily';
    if (freq == 'THREE_TIMES_DAILY') freqLabel = '3x Daily';
    if (freq == 'CUSTOM') freqLabel = 'Custom';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: isActive ? const Color(0xFF14B8A6) : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dosage $unit • $freqLabel',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeThumbColor: const Color(0xFF14B8A6),
                onChanged: (val) => _toggleMedicineActive(med, isActive),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Times chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: times.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm_rounded, size: 13, color: Color(0xFF14B8A6)),
                    const SizedBox(width: 4),
                    Text(
                      t.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Duration & Notes
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: isDark ? Colors.white60 : const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                endDate != null && endDate.isNotEmpty
                    ? '$startDate  →  $endDate'
                    : '$startDate  →  Ongoing',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          if (notes != null && notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 8),

          // Action Buttons: Edit and Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF14B8A6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openAddEditSheet(med),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _deleteMedicine(id, name),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
