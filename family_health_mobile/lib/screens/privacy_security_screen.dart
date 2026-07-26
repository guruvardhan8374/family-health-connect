import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Privacy values
  String _profileVisibility = 'FAMILY';
  String _healthVisibility = 'FAMILY';
  String _emergencyVisibility = 'FAMILY';
  bool _locationSharing = true;

  // Granular health sharing values
  bool _shareHeartRate = true;
  bool _shareSteps = true;
  bool _shareCalories = true;
  bool _shareSleep = true;
  bool _shareSpo2 = true;
  bool _shareWeight = true;
  bool _shareBloodPressure = true;

  // Account values
  bool _twoFactorEnabled = false;

  // Password fields
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadThemeAndSettings();
  }

  Future<void> _loadThemeAndSettings() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final privacy = await ApiService.getPrivacySettings();
    final account = await ApiService.getAccountSettings();

    if (privacy != null) {
      _profileVisibility = privacy['profile_visibility'] ?? 'FAMILY';
      _healthVisibility = privacy['health_data_visibility'] ?? 'FAMILY';
      _emergencyVisibility = privacy['emergency_visibility'] ?? 'FAMILY';
      _locationSharing = privacy['location_sharing'] ?? true;
      _shareHeartRate = privacy['share_heart_rate'] ?? true;
      _shareSteps = privacy['share_steps'] ?? true;
      _shareCalories = privacy['share_calories'] ?? true;
      _shareSleep = privacy['share_sleep'] ?? true;
      _shareSpo2 = privacy['share_spo2'] ?? true;
      _shareWeight = privacy['share_weight'] ?? true;
      _shareBloodPressure = privacy['share_blood_pressure'] ?? true;
    }

    if (account != null) {
      _twoFactorEnabled = account['two_factor_auth_enabled'] ?? false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrivacySettings() async {
    setState(() => _isSaving = true);
    final success = await ApiService.updatePrivacySettings({
      'profile_visibility': _profileVisibility,
      'health_data_visibility': _healthVisibility,
      'emergency_visibility': _emergencyVisibility,
      'location_sharing': _locationSharing,
      'share_heart_rate': _shareHeartRate,
      'share_steps': _shareSteps,
      'share_calories': _shareCalories,
      'share_sleep': _shareSleep,
      'share_spo2': _shareSpo2,
      'share_weight': _shareWeight,
      'share_blood_pressure': _shareBloodPressure,
    });
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Privacy settings saved!' : '❌ Failed to save privacy settings.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggle2FA(bool value) async {
    setState(() => _twoFactorEnabled = value);
    final success = await ApiService.updateAccountSettings({
      'two_factor_auth_enabled': value,
    });
    if (!success && mounted) {
      setState(() => _twoFactorEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to update 2FA settings.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
    );

    final res = await ApiService.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading
      if (res != null && res['success'] == true) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password changed successfully!'), backgroundColor: Colors.green),
        );
      } else {
        String errMsg = 'Failed to change password.';
        if (res != null) {
          if (res.containsKey('old_password')) {
            errMsg = res['old_password'][0];
          } else if (res.containsKey('new_password')) {
            errMsg = res['new_password'][0];
          } else if (res.containsKey('confirm_password')) {
            errMsg = res['confirm_password'][0];
          } else if (res.containsKey('error')) {
            errMsg = res['error'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $errMsg'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteAccountConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'WARNING: This action is permanent! All your health data, family ties, and profile records will be deleted forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.deleteAccount();
              if (success) {
                await AuthService.logout();
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Failed to delete account.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('DELETE PERMANENTLY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        actions: [
          if (!_isLoading)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6)),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check_rounded, color: Color(0xFF14B8A6)),
                    onPressed: _savePrivacySettings,
                  )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Data Sharing & Visibility'),
                _buildDropdownTile(
                  title: 'Profile Visibility',
                  value: _profileVisibility,
                  onChanged: (val) => setState(() => _profileVisibility = val!),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                    DropdownMenuItem(value: 'FAMILY', child: Text('Family Only')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                  ],
                ),
                _buildDropdownTile(
                  title: 'Health Records Visibility',
                  value: _healthVisibility,
                  onChanged: (val) => setState(() => _healthVisibility = val!),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                    DropdownMenuItem(value: 'FAMILY', child: Text('Family Only')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                  ],
                ),
                _buildDropdownTile(
                  title: 'SOS / Emergency Visibility',
                  value: _emergencyVisibility,
                  onChanged: (val) => setState(() => _emergencyVisibility = val!),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                    DropdownMenuItem(value: 'FAMILY', child: Text('Family Only')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                  ],
                ),
                SwitchListTile(
                  value: _locationSharing,
                  onChanged: (val) => setState(() => _locationSharing = val),
                  title: const Text('Real-time Location Sharing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Share your location with your family members during emergencies'),
                  activeThumbColor: const Color(0xFF14B8A6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                if (_healthVisibility != 'PRIVATE') ...[
                  const Divider(height: 32),
                  _buildSectionHeader('Granular Family Health Sharing'),
                  _buildSwitchTile(
                    title: 'Share Heart Rate',
                    subtitle: 'Allow family circle to view your heart rate updates',
                    value: _shareHeartRate,
                    onChanged: (val) => setState(() => _shareHeartRate = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share Steps',
                    subtitle: 'Allow family circle to view your today\'s steps count',
                    value: _shareSteps,
                    onChanged: (val) => setState(() => _shareSteps = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share Calories',
                    subtitle: 'Allow family circle to view calories burned today',
                    value: _shareCalories,
                    onChanged: (val) => setState(() => _shareCalories = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share Sleep',
                    subtitle: 'Allow family circle to view sleep hours & stages',
                    value: _shareSleep,
                    onChanged: (val) => setState(() => _shareSleep = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share SpO₂',
                    subtitle: 'Allow family circle to view blood oxygen levels',
                    value: _shareSpo2,
                    onChanged: (val) => setState(() => _shareSpo2 = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share Weight',
                    subtitle: 'Allow family circle to view weight logs & BMI',
                    value: _shareWeight,
                    onChanged: (val) => setState(() => _shareWeight = val),
                  ),
                  _buildSwitchTile(
                    title: 'Share Blood Pressure',
                    subtitle: 'Allow family circle to view blood pressure readings',
                    value: _shareBloodPressure,
                    onChanged: (val) => setState(() => _shareBloodPressure = val),
                  ),
                ],
                const SizedBox(height: 16),

                _buildSectionHeader('Authentication Settings'),
                SwitchListTile(
                  value: _twoFactorEnabled,
                  onChanged: _toggle2FA,
                  title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Protect your health dashboard with an additional login verification'),
                  activeThumbColor: const Color(0xFF14B8A6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                const SizedBox(height: 16),

                _buildSectionHeader('Security - Change Password'),
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        children: [
                          _buildPasswordField(
                            controller: _oldPasswordController,
                            label: 'Old Password',
                            obscure: _obscureOld,
                            onToggle: () => setState(() => _obscureOld = !_obscureOld),
                          ),
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: 'New Password',
                            obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _changePassword,
                              child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Danger Zone'),
                Card(
                  elevation: 0,
                  color: Colors.red[50]?.withValues(alpha: isDark ? 0.1 : 0.8) ?? Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('Delete My Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: Text('Instantly remove all health ties and history.', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[800])),
                    trailing: const Icon(Icons.chevron_right, color: Colors.red),
                    onTap: _showDeleteAccountConfirm,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
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

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              items: items,
              onChanged: onChanged,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        activeThumbColor: const Color(0xFF14B8A6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: (val) => val == null || val.isEmpty ? 'This field is required' : null,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF14B8A6), size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
