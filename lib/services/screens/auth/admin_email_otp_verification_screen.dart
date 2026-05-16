import 'package:flutter/material.dart';
import 'package:showroom_app/services/auth_service.dart';

class AdminEmailOtpVerificationScreen extends StatefulWidget {
  final String adminEmail;

  const AdminEmailOtpVerificationScreen({
    super.key,
    required this.adminEmail,
  });

  @override
  State<AdminEmailOtpVerificationScreen> createState() =>
      _AdminEmailOtpVerificationScreenState();
}

class _AdminEmailOtpVerificationScreenState
    extends State<AdminEmailOtpVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  final AuthService _authService = AuthService();

  bool loading = false;
  bool otpSent = false;

  @override
  void initState() {
    super.initState();
    sendOtp();
  }

  Future<void> sendOtp() async {
    setState(() {
      loading = true;
    });

    try {
      await _authService.sendAdminEmailOtp(email: widget.adminEmail);
      setState(() {
        otpSent = true;
      });
      _showMessage(
        'OTP sent to ${widget.adminEmail}. Check your email.',
        isError: false,
      );
    } catch (e) {
      _showMessage(e is Exception ? e.toString() : 'Failed to send OTP.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showMessage('Enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await _authService.verifyAdminEmailOtp(
        email: widget.adminEmail,
        otp: otp,
      );
      _showMessage('OTP verified. Signing you in...', isError: false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/adminDashboard');
    } catch (e) {
      _showMessage(e is Exception ? e.toString() : 'OTP verification failed.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
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
      appBar: AppBar(
        title: const Text('Admin Email OTP'),
      ),
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
                        Icons.email_outlined,
                        size: 68,
                        color: Color(0xFF7B1F3F),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Email OTP Verification',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'An OTP has been sent to ${widget.adminEmail}. Enter it below to complete admin login.',
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
                          onPressed: loading ? null : verifyOtp,
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
                        onPressed: loading ? null : sendOtp,
                        child: const Text('Resend OTP'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
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
