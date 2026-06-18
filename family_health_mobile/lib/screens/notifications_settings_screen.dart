import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _isLoading = true;

  // Toggle values
  bool _pushNotifications = true;
  bool _medicineReminders = true;
  bool _healthReminders = true;
  bool _emergencyAlerts = true;
  bool _familyNotifications = true;
  bool _chatNotifications = true;
  bool _emailNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final data = await ApiService.getNotificationSettings();
    if (data != null) {
      _pushNotifications = data['push_notifications'] ?? true;
      _medicineReminders = data['medicine_reminders'] ?? true;
      _healthReminders = data['health_reminders'] ?? true;
      _emergencyAlerts = data['emergency_alerts'] ?? true;
      _familyNotifications = data['family_notifications'] ?? true;
      _chatNotifications = data['chat_notifications'] ?? true;
      _emailNotifications = data['email_notifications'] ?? true;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleSetting(String key, bool val) async {
    // Optimistic UI state
    setState(() {
      switch (key) {
        case 'push_notifications':
          _pushNotifications = val;
          break;
        case 'medicine_reminders':
          _medicineReminders = val;
          break;
        case 'health_reminders':
          _healthReminders = val;
          break;
        case 'emergency_alerts':
          _emergencyAlerts = val;
          break;
        case 'family_notifications':
          _familyNotifications = val;
          break;
        case 'chat_notifications':
          _chatNotifications = val;
          break;
        case 'email_notifications':
          _emailNotifications = val;
          break;
      }
    });

    final success = await ApiService.updateNotificationSettings({
      'push_notifications': _pushNotifications,
      'medicine_reminders': _medicineReminders,
      'health_reminders': _healthReminders,
      'emergency_alerts': _emergencyAlerts,
      'family_notifications': _familyNotifications,
      'chat_notifications': _chatNotifications,
      'email_notifications': _emailNotifications,
    });

    if (!success && mounted) {
      // Revert state
      setState(() {
        switch (key) {
          case 'push_notifications':
            _pushNotifications = !val;
            break;
          case 'medicine_reminders':
            _medicineReminders = !val;
            break;
          case 'health_reminders':
            _healthReminders = !val;
            break;
          case 'emergency_alerts':
            _emergencyAlerts = !val;
            break;
          case 'family_notifications':
            _familyNotifications = !val;
            break;
          case 'chat_notifications':
            _chatNotifications = !val;
            break;
          case 'email_notifications':
            _emailNotifications = !val;
            break;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to update notification preferences.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('General Alerts'),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Master switch for all system and app alert notifications',
                  value: _pushNotifications,
                  onChanged: (val) => _toggleSetting('push_notifications', val),
                  icon: Icons.notifications_active_outlined,
                ),
                _buildSwitchTile(
                  title: 'Email Digest Notifications',
                  subtitle: 'Receive weekly family health summaries and activity digests in email',
                  value: _emailNotifications,
                  onChanged: (val) => _toggleSetting('email_notifications', val),
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 16),

                _buildSectionHeader('Care & Reminders'),
                _buildSwitchTile(
                  title: 'Medicine Reminders',
                  subtitle: 'Get alerts when family members miss scheduled medicine intakes',
                  value: _medicineReminders,
                  onChanged: (val) => _toggleSetting('medicine_reminders', val),
                  icon: Icons.medication_outlined,
                ),
                _buildSwitchTile(
                  title: 'Daily Health Targets',
                  subtitle: 'Reminders for target step completion, sleep reviews, and vitals checkups',
                  value: _healthReminders,
                  onChanged: (val) => _toggleSetting('health_reminders', val),
                  icon: Icons.run_circle_outlined,
                ),
                const SizedBox(height: 16),

                _buildSectionHeader('Family Activity'),
                _buildSwitchTile(
                  title: 'Emergency SOS Alerts',
                  subtitle: 'IMMEDIATE alerts when a family member triggers their SOS button',
                  value: _emergencyAlerts,
                  onChanged: (val) => _toggleSetting('emergency_alerts', val),
                  icon: Icons.emergency_share_outlined,
                  isCritical: true,
                ),
                _buildSwitchTile(
                  title: 'Family Group Chat Messages',
                  subtitle: 'Alerts when someone posts inside your family circle group chat',
                  value: _chatNotifications,
                  onChanged: (val) => _toggleSetting('chat_notifications', val),
                  icon: Icons.chat_bubble_outline_rounded,
                ),
                _buildSwitchTile(
                  title: 'Safe Zone Warnings',
                  subtitle: 'Notifications when family members enter or leave configured Safe Zones',
                  value: _familyNotifications,
                  onChanged: (val) => _toggleSetting('family_notifications', val),
                  icon: Icons.location_history_rounded,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool isCritical = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF14B8A6),
        title: Row(
          children: [
            Icon(icon, color: isCritical ? Colors.red : const Color(0xFF14B8A6), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isCritical ? Colors.red : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28.0, top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 12)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
