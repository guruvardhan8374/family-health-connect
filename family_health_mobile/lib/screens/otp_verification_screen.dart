import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() {
        _error = 'Please enter the verification code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    final success = await ApiService.verifyOtp(widget.email, otp);

    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _successMessage = '✅ OTP Verified Successfully! You can now log in.';
      });
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context); // Go back to login screen
          }
        });
      }
    } else {
      setState(() {
        _error = 'Invalid or expired OTP code. Please try again.';
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined, color: Color(0xFF14B8A6), size: 36),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit verification code to',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 36),

                // Card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      if (_error != null)
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
                      
                      if (_successMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 13),
                          ),
                        ),

                      // Code field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                          maxLength: 6,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 24, letterSpacing: 8),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onSubmitted: (_) => _verifyOtp(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Verify Code',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A new OTP has been requested.')),
                    );
                  },
                  child: Text(
                    'Didn\'t receive code? Resend OTP',
                    style: TextStyle(color: const Color(0xFF14B8A6).withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
