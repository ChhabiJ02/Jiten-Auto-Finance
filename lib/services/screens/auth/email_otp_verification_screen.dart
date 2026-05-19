import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:showroom_app/services/auth_service.dart';

class EmailOtpVerificationScreen extends StatefulWidget {
  final String email;
  final String uid;
  final String? role;

  const EmailOtpVerificationScreen({
    super.key,
    required this.email,
    required this.uid,
    this.role,
  });

  @override
  State<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends State<EmailOtpVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  final AuthService _authService = AuthService();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    setState(() {
      loading = true;
    });

    try {
      await _authService.sendUserEmailOtp(
        email: widget.email,
        uid: widget.uid,
      );
      _showMessage(
        'Verification code created. Check your email if delivery is configured.',
        isError: false,
      );
    } catch (e) {
      _showMessage(
        e is FirebaseAuthException
            ? AuthService.getFriendlyAuthErrorMessage(e)
            : 'Failed to send verification code.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      _showMessage('Enter a valid 6-digit OTP.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await _authService.verifyUserEmailOtp(
        uid: widget.uid,
        email: widget.email,
        otp: otp,
      );

      final role = (widget.role ?? await _authService.getUserRole(widget.uid))
          .toLowerCase();

      if (!mounted) return;

      _showMessage('Email verified successfully.', isError: false);

      if (role == 'staff' || role == 'workshop') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/staffDashboard',
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/customerDashboard',
          (route) => false,
        );
      }
    } catch (e) {
      _showMessage(
        e is FirebaseAuthException
            ? AuthService.getFriendlyAuthErrorMessage(e)
            : 'OTP verification failed.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _backToLogin() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7B1F3F), Color(0xFFF4DBE1)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 68,
                        color: Color(0xFF7B1F3F),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Email Verification',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 6-digit verification code for ${widget.email}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Enter OTP',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: loading ? null : _verifyOtp,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Verify OTP',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: loading ? null : _sendOtp,
                        child: const Text('Resend OTP'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: loading ? null : _backToLogin,
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
