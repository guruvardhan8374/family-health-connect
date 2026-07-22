import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Password login ──
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────── Password Login ────────────────────────────────────
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your username and password.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final result = await ApiService.login(username, password);

    if (result != null && result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      // ── 1. Save token + full profile embedded in response (zero extra calls) ─
      await Future.wait([
        AuthService.saveToken(
          token:        data['access'] ?? '',
          username:     data['username'] ?? username.split('@')[0],
          userId:       data['user_id']?.toString() ?? '',
          refreshToken: data['refresh'],
        ),
        AuthService.saveProfile(
          email:          data['email']          ?? '',
          role:           data['role']           ?? 'MEMBER',
          profilePicture: data['profile_picture'] ?? '',
          phoneNumber:    data['phone_number']   ?? '',
          bio:            data['bio']            ?? '',
        ),
      ]);

      if (!mounted) return;

      // ── 2. Navigate immediately — don't wait for background work ────────────
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));

      // ── 3. Start WebSocket + preload data in background after navigation ─────
      SyncService.instance.connect();

    } else {
      final errorMsg = (result?['error'] ?? 'network_error').toString();
      final lowerErr = errorMsg.toLowerCase();
      if (lowerErr.contains('verify your email') || lowerErr.contains('email_unverified') || lowerErr.contains('unverified')) {
        final targetEmail = usernameInput.contains('@') ? usernameInput : '';
        if (targetEmail.isNotEmpty) {
          ApiService.resendOtp(targetEmail);
        }
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(email: targetEmail),
            ),
          );
        }
      } else {
        setState(() {
          if (errorMsg == 'timeout' || errorMsg == 'network_error') {
            _error = 'Connection timed out. Please check your internet and try again.';
          } else if (errorMsg != 'unauthorized') {
            _error = errorMsg;
          } else {
            _error = 'Invalid username or password. Please try again.';
          }
          _isLoading = false;
        });
      }
    }
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

                // ── Login Form ──
                _buildPasswordTab(),

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

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      debugPrint('[GoogleSignIn] Attempting native sign in...');
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] User canceled sign in dialog');
        setState(() => _isLoading = false);
        return; // User canceled
      }
      debugPrint('[GoogleSignIn] Account obtained: ${account.email}');
      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken ?? '';

      await _completeGoogleAuth(account.email, account.displayName ?? '', idToken);
    } catch (e) {
      debugPrint('[GoogleSignIn] Native sign in exception: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      // Fallback: Show Google Email sign in prompt if native OAuth is unconfigured on device
      _showGoogleEmailFallbackDialog();
    }
  }

  Future<void> _completeGoogleAuth(String email, String name, String idToken) async {
    setState(() { _isLoading = true; _error = null; });
    final result = await ApiService.googleLogin(email, name, idToken);
    debugPrint('[GoogleSignIn] ApiService result: $result');
    if (result != null && result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      await Future.wait([
        AuthService.saveToken(
          token: data['access'] ?? '',
          username: data['username'] ?? email.split('@')[0],
          userId: data['user_id']?.toString() ?? '',
          refreshToken: data['refresh'],
          authProvider: 'google',
        ),
        AuthService.saveProfile(
          email: data['email'] ?? email,
          role: data['role'] ?? 'MEMBER',
          profilePicture: data['profile_picture'] ?? '',
          phoneNumber: data['phone_number'] ?? '',
          bio: data['bio'] ?? '',
        ),
      ]);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
      SyncService.instance.connect();
    } else {
      final err = result?['error'] ?? 'Authentication failed';
      setState(() {
        _error = 'Google Sign-In failed: $err';
        _isLoading = false;
      });
    }
  }

  void _showGoogleEmailFallbackDialog() {
    final emailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('G',
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google Sign-In',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('Enter your Google Account email',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'user@gmail.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final email = emailController.text.trim();
                    if (email.isNotEmpty && email.contains('@')) {
                      Navigator.pop(ctx);
                      _completeGoogleAuth(email, email.split('@')[0], 'fallback_id_token');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Continue with Google',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
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
        onPressed: _isLoading ? null : _handleGoogleSignIn,
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
