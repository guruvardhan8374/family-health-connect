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
      final errorType = result?['error'] ?? 'network_error';
      setState(() {
        if (errorType.contains('verify your email') || errorType.contains('email_unverified')) {
          _error = 'Please verify your email before logging in.';
        } else if (errorType == 'timeout' || errorType == 'network_error') {
          _error = 'Connection timed out. Please check your internet and try again.';
        } else if (errorType != 'unauthorized') {
          _error = errorType;
        } else {
          _error = 'Invalid username or password. Please try again.';
        }
        _isLoading = false;
      });
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
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken ?? auth.accessToken ?? '';

      final result = await ApiService.googleLogin(account.email, account.displayName ?? '', idToken);
      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        await Future.wait([
          AuthService.saveToken(
            token: data['access'] ?? '',
            username: data['username'] ?? account.email.split('@')[0],
            userId: data['user_id']?.toString() ?? '',
            refreshToken: data['refresh'],
          ),
          AuthService.saveProfile(
            email: data['email'] ?? account.email,
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
        setState(() {
          _error = 'Google Sign-In authentication failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Google Sign-In failed. Please try email login.';
        _isLoading = false;
      });
    }
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
