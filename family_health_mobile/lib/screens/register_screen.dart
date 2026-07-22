import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'MEMBER';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  String? _error;
  Map<String, dynamic> _fieldErrors = {};

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _error = 'Please fill in all required fields.';
        _fieldErrors = {};
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match.';
        _fieldErrors = {};
      });
      return;
    }

    final passErrors = <String>[];
    if (password.length < 8) passErrors.add('8+ characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) passErrors.add('1 uppercase letter');
    if (!RegExp(r'[a-z]').hasMatch(password)) passErrors.add('1 lowercase letter');
    if (!RegExp(r'[0-9]').hasMatch(password)) passErrors.add('1 number');
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) passErrors.add('1 special character');

    if (passErrors.isNotEmpty) {
      setState(() {
        _error = 'Password must contain: ${passErrors.join(', ')}.';
        _fieldErrors = {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _fieldErrors = {};
    });

    final res = await ApiService.register(
      username: username,
      email: email,
      password: password,
      passwordConfirm: confirmPassword,
      phoneNumber: phone,
      role: _selectedRole,
    );

    setState(() => _isLoading = false);

    if (res != null) {
      if (res.containsKey('user')) {
        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Registration successful! Verification code sent.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(email: email),
            ),
          );
        }
      } else {
        // Validation errors returned
        setState(() {
          _fieldErrors = res;
          if (res.containsKey('non_field_errors')) {
            _error = (res['non_field_errors'] as List).join('\n');
          } else if (res.containsKey('detail')) {
            _error = res['detail'].toString();
          } else {
            _error = 'Registration failed. Please check the fields below.';
          }
        });
      }
    } else {
      setState(() {
        _error = 'Network error or server unavailable. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // Logo or title
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join the family health platform',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          ),
                        ),
                      ],

                      _buildField(
                        controller: _usernameController,
                        hint: 'Username *',
                        icon: Icons.person_outline_rounded,
                        errorKey: 'username',
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _emailController,
                        hint: 'Email Address *',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        errorKey: 'email',
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _phoneController,
                        hint: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        errorKey: 'phone_number',
                      ),
                      const SizedBox(height: 14),

                      // Role Select
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'Account Type / Role',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard('MEMBER', 'Family Member', Icons.family_restroom_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleCard('HEAD', 'Family Head', Icons.admin_panel_settings_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _passwordController,
                        hint: 'Password *',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscure: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                        errorKey: 'password',
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm Password *',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscure: _obscureConfirmPassword,
                        onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        errorKey: 'password_confirm',
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Text(
                                  'Register Account',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(color: Colors.white70)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String roleVal, String roleLabel, IconData icon) {
    final isSelected = _selectedRole == roleVal;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14B8A6).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF14B8A6) : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF14B8A6) : Colors.white54, size: 22),
            const SizedBox(height: 6),
            Text(
              roleLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    required String errorKey,
  }) {
    final hasFieldError = _fieldErrors.containsKey(errorKey);
    String? errorText;
    if (hasFieldError) {
      final val = _fieldErrors[errorKey];
      if (val is List) {
        errorText = val.join('\n');
      } else {
        errorText = val.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasFieldError ? Colors.red.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && obscure,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 18),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white.withValues(alpha: 0.4), size: 18),
                      onPressed: onToggleObscure,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (errorText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
