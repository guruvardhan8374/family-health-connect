import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Password login ──
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  // ── Phone OTP ──
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _phoneLoading = false;
  String? _phoneError;
  String? _phoneSuccess;
  bool _otpSent = false; // false = enter phone, true = enter OTP
  String? _phoneSuccess;
  bool _otpSent = false; // false = enter phone, true = enter OTP
  
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────── Password Login ────────────────────────────────────
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    if (result != null && result['access'] != null) {
      await AuthService.saveToken(
        token: result['access'],
        username: _usernameController.text.split('@')[0],
        userId: result['user_id']?.toString() ?? '1',
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } else {
      setState(() {
        _error = 'Invalid username or password. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ─────────────────────── Phone OTP ─────────────────────────────────────────
  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _phoneError = 'Please enter a valid phone number.');
      return;
    }
    setState(() {
      _phoneLoading = true;
      _phoneError = null;
      _phoneSuccess = null;
    });

    final error = await ApiService.sendPhoneOtp(phone);

    if (error == null) {
      setState(() {
        _phoneSuccess = 'OTP sent! Enter the 6-digit code below.';
        _otpSent = true;
        _phoneLoading = false;
      });
      _startResendTimer();
    } else {
      setState(() {
        _phoneError = error;
        _phoneLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) return;

    setState(() {
      _phoneLoading = true;
      _phoneError = null;
    });

    final result = await ApiService.verifyPhoneOtp(
      _phoneController.text.trim(),
      otp,
    );

    if (result != null && result['access'] != null) {
      final username =
          result['username']?.toString() ?? 'user_${_phoneController.text.trim().substring(_phoneController.text.trim().length - 4)}';
      await AuthService.saveToken(
        token: result['access'],
        username: username,
        userId: result['user_id']?.toString() ?? '1',
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } else {
      setState(() {
        _phoneError = 'Invalid or expired OTP. Please try again.';
        _phoneLoading = false;
      });
    }
  }

  void _resetPhoneFlow() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _phoneError = null;
      _phoneSuccess = null;
      _resendTimer?.cancel();
      _resendCountdown = 0;
    });
  }

  // ─────────────────────── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // ── Logo ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Welcome Back',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Sign in to your family health dashboard',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 15)),
                const SizedBox(height: 36),

                // ── Tab bar ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF14B8A6),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        Colors.white.withValues(alpha: 0.4),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.email_outlined, size: 18),
                          text: 'Email / Password'),
                      Tab(
                          icon: Icon(Icons.phone_android_rounded, size: 18),
                          text: 'Phone OTP'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Tab views ──
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPasswordTab(),
                      _buildPhoneOtpTab(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                // ── Google login ──
                _buildGoogleButton(),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen())),
                  child: Text(
                    "Don't have an account? Create one",
                    style: TextStyle(
                        color:
                            const Color(0xFF14B8A6).withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Password Tab ────────────────────────────────────────────────────────────
  Widget _buildPasswordTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (_error != null)
            _buildAlert(_error!, isError: true),
          const SizedBox(height: 8),
          _buildField(
            controller: _usernameController,
            hint: 'Username or Email',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone OTP Tab ───────────────────────────────────────────────────────────
  Widget _buildPhoneOtpTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (_phoneError != null) _buildAlert(_phoneError!, isError: true),
          if (_phoneSuccess != null)
            _buildAlert(_phoneSuccess!, isError: false),
          const SizedBox(height: 4),

          if (!_otpSent) ...[
            // ── Step 1: Enter phone ──
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.phone_android_rounded,
                  color: Color(0xFF14B8A6), size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter your phone number and we'll send a verification code.",
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _phoneController,
              hint: '+91 9876543210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _phoneLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _phoneLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Send OTP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // ── Step 2: Enter OTP ──
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Color(0xFF14B8A6), size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the 6-digit code sent to\n${_phoneController.text.trim()}',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 16),
            // Large OTP input
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '______',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      letterSpacing: 12,
                      fontSize: 28),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_phoneLoading ||
                        _otpController.text.length < 6)
                    ? null
                    : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  disabledBackgroundColor:
                      const Color(0xFF14B8A6).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _phoneLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Verify & Sign In',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resetPhoneFlow,
                  child: Text('← Different number',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13)),
                ),
                TextButton(
                  onPressed: (_resendCountdown > 0 || _phoneLoading) ? null : _sendOtp,
                  child: Text(
                    _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend OTP',
                    style: TextStyle(
                        color: _resendCountdown > 0
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFF14B8A6).withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Google button ───────────────────────────────────────────────────────────
  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Google Sign-In will be available soon!')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            SizedBox(width: 12),
            Text('Sign in with Google',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────
  Widget _buildAlert(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                (isError ? Colors.red : Colors.green).withValues(alpha: 0.3)),
      ),
      child: Text(message,
          style: TextStyle(
              color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
              fontSize: 13)),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20),
                  onPressed: onToggleObscure)
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
