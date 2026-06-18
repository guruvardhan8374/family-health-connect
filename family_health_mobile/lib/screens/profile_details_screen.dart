import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _addressController = TextEditingController();
  final _picController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await ApiService.getProfileSettings();
    if (data != null) {
      _usernameController.text = (data['username'] ?? '').toString();
      _phoneController.text = (data['phone_number'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
      _emergencyContactController.text = (data['emergency_contact'] ?? '').toString();
      _emergencyPhoneController.text = (data['emergency_phone'] ?? '').toString();
      _dobController.text = (data['date_of_birth'] ?? '').toString();
      _genderController.text = (data['gender'] ?? '').toString();
      _bloodGroupController.text = (data['blood_group'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
      _picController.text = (data['profile_picture'] ?? '').toString();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final Map<String, dynamic> data = {
      'username': _usernameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
      'emergency_contact': _emergencyContactController.text.trim(),
      'emergency_phone': _emergencyPhoneController.text.trim(),
      'date_of_birth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
      'gender': _genderController.text.trim(),
      'blood_group': _bloodGroupController.text.trim(),
      'address': _addressController.text.trim(),
      'profile_picture': _picController.text.trim().isEmpty ? null : _picController.text.trim(),
    };

    final success = await ApiService.updateProfileSettings(data);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Profile updated successfully!' : '❌ Failed to update profile settings.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
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
                    onPressed: _saveProfile,
                  )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile image placeholder or dynamic URL
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                          backgroundImage: _picController.text.isNotEmpty
                              ? NetworkImage(_picController.text)
                              : null,
                          child: _picController.text.isEmpty
                              ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF14B8A6))
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Account Identity'),
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person_outline_rounded,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Username is required' : null,
                  ),
                  _buildTextField(
                    controller: _picController,
                    label: 'Profile Picture URL',
                    icon: Icons.image_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Contact Details'),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Home Address',
                    icon: Icons.home_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Personal Info'),
                  _buildTextField(
                    controller: _bioController,
                    label: 'Short Bio',
                    icon: Icons.info_outline_rounded,
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _dobController,
                          label: 'DOB (YYYY-MM-DD)',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _genderController,
                          label: 'Gender',
                          icon: Icons.wc_outlined,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _bloodGroupController,
                    label: 'Blood Group',
                    icon: Icons.bloodtype_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Emergency Support'),
                  _buildTextField(
                    controller: _emergencyContactController,
                    label: 'Emergency Contact Name',
                    icon: Icons.contact_emergency_outlined,
                  ),
                  _buildTextField(
                    controller: _emergencyPhoneController,
                    label: 'Emergency Contact Phone',
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF14B8A6), size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
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
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _bloodGroupController.dispose();
    _addressController.dispose();
    _picController.dispose();
    super.dispose();
  }
}
