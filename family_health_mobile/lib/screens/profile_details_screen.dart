import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  Uint8List? _localImageBytes;
  String? _localImageName;
  final ImagePicker _picker = ImagePicker();

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

  String? _localImagePath;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        debugPrint('[ProfilePicker] Selected image path: ${pickedFile.path}, name: ${pickedFile.name}, size: ${bytes.length} bytes');
        setState(() {
          _localImageBytes = bytes;
          _localImageName = pickedFile.name;
          _localImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint('[ProfilePicker] Error picking image: $e');
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isSaving = true);
    final success = await ApiService.deleteAvatar();
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Photo removed successfully!' : '❌ Failed to remove photo.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) {
        setState(() {
          _localImageBytes = null;
          _localImageName = null;
          _localImagePath = null;
          _picController.clear();
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Upload avatar if a new one was selected locally
    if (_localImageBytes != null) {
      final fileName = _localImageName ?? 'avatar.jpg';
      final uploadRes = await ApiService.uploadAvatarBytes(
        _localImageBytes!,
        fileName,
        filePath: _localImagePath,
      );
      if (uploadRes != null && uploadRes['profile_picture'] != null) {
        _picController.text = uploadRes['profile_picture'].toString();
      } else {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to upload profile picture.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final String dobText = _dobController.text.trim();
    final Map<String, dynamic> data = {
      'username': _usernameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
      'emergency_contact': _emergencyContactController.text.trim(),
      'emergency_phone': _emergencyPhoneController.text.trim(),
      'date_of_birth': dobText.isEmpty ? null : dobText,
      'gender': _genderController.text.trim(),
      'blood_group': _bloodGroupController.text.trim(),
      'address': _addressController.text.trim(),
      'profile_picture': _picController.text.trim().isEmpty ? null : _picController.text.trim(),
    };

    debugPrint('[ProfileScreen] Invoking updateProfileSettings with payload: $data');
    final result = await ApiService.updateProfileSettings(data);
    setState(() => _isSaving = false);

    final bool success = result['success'] == true;
    final String? errorMsg = result['error'] as String?;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Profile updated successfully!' : '❌ ${errorMsg ?? "Failed to update profile"}'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) {
        setState(() {
          _localImageBytes = null;
          _localImageName = null;
          _localImagePath = null;
        });
        Navigator.pop(context, true);
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
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: const Color(0xFF14B8A6).withOpacity(0.1),
                              backgroundImage: _localImageBytes != null
                                  ? MemoryImage(_localImageBytes!) as ImageProvider
                                  : (_picController.text.isNotEmpty
                                      ? NetworkImage(ApiService.normalizeImageUrl(_picController.text))
                                      : null),
                              child: _localImageBytes == null && _picController.text.isEmpty
                                  ? const Icon(Icons.person_rounded, size: 55, color: Color(0xFF14B8A6))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF14B8A6)),
                                            title: const Text('Take Photo'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.camera);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF14B8A6)),
                                            title: const Text('Choose from Gallery'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.gallery);
                                            },
                                          ),
                                          if (_picController.text.isNotEmpty || _localImageBytes != null)
                                            ListTile(
                                              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                              title: const Text('Remove Current Photo', style: TextStyle(color: Colors.red)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _deleteAvatar();
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },

                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF14B8A6),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
