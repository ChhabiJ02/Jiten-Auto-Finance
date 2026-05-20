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
  final AuthService _authService = AuthService();

  bool loading = false;
  bool emailSent = false;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      loading = true;
    });

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        emailSent = true;
      });
      _showMessage(
        'Verification email sent. Check your inbox and spam folder.',
        isError: false,
      );
    } catch (e) {
      _showMessage(
        e is Exception
            ? e.toString()
            : 'Failed to send verification email.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() {
      loading = true;
    });

    try {
      final verified = await _authService.checkEmailVerified();

      if (!mounted) return;

      if (verified) {
        _showMessage('Email verified successfully.', isError: false);

        final role = (widget.role ?? await _authService.getUserRole(widget.uid))
            .toLowerCase();

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
      } else {
        _showMessage(
          'Email not verified yet. Please click the link in your email.',
        );
      }
    } catch (e) {
      _showMessage(
        e is Exception
            ? e.toString()
            : 'Failed to verify email status.',
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
                        'A verification link has been sent to ${widget.email}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Click the link in your inbox, then press Confirm below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: loading ? null : _checkVerificationStatus,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Confirm Verification',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: loading ? null : _sendVerificationEmail,
                        child: const Text('Resend verification email'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: loading ? null : _backToLogin,
                        child: const Text('Back to login'),
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
