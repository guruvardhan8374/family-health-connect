import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'profile_details_screen.dart';
import 'privacy_security_screen.dart';
import 'notifications_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'language_settings_screen.dart';
import 'help_center_screen.dart';
import 'about_screen.dart';
import 'wireless_vitals_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSection('Account'),
          _buildSettingsTile(
            context,
            Icons.person_outline,
            'Profile Details',
            'Edit your personal information',
            const ProfileDetailsScreen(),
          ),
          _buildSettingsTile(
            context,
            Icons.security,
            'Privacy & Security',
            'Manage your data and password',
            const PrivacySecurityScreen(),
          ),
          const SizedBox(height: 24),
          
          _buildSettingsSection('Preferences'),
          _buildSettingsTile(
            context,
            Icons.sensors_rounded,
            'Wireless Vitals & IoT',
            'Connect Google Fit, Garmin, and Fitbit',
            const WirelessVitalsScreen(),
          ),
          _buildSettingsTile(
            context,
            Icons.notifications_none,
            'Notifications',
            'Customize alerts and reminders',
            const NotificationsSettingsScreen(),
          ),
          _buildSettingsTile(
            context,
            Icons.dark_mode_outlined,
            'Appearance',
            'Dark mode, themes, and colors',
            const AppearanceSettingsScreen(),
          ),
          _buildSettingsTile(
            context,
            Icons.language,
            'Language',
            'English (US)',
            const LanguageSettingsScreen(),
          ),

          const SizedBox(height: 24),

          _buildSettingsSection('Support'),
          _buildSettingsTile(
            context,
            Icons.help_outline,
            'Help Center',
            'FAQs and contact support',
            const HelpCenterScreen(),
          ),
          _buildSettingsTile(
            context,
            Icons.info_outline,
            'About',
            'App version 1.0.0',
            const AboutScreen(),
          ),
          const SizedBox(height: 32),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50]?.withValues(alpha: isDark ? 0.1 : 0.8) ?? Colors.red,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget targetScreen,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF14B8A6)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        },
      ),
    );
  }
}
