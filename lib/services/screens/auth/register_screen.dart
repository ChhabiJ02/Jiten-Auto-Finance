import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool otpSent = false;
  String _generatedOtp = '';

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Generate 6-digit OTP
  String _generateOTP() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString();
  }

  // STEP 1: Send OTP via WhatsApp
  Future<void> sendOTP() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Please fill all fields.');
      return;
    }

    if (phone.length != 10) {
      showMessage('Enter valid 10-digit phone number.');
      return;
    }

    setState(() => loading = true);

    try {
      _generatedOtp = _generateOTP();

      final message =
          "Hello $name 👋\n\n"
          "Your OTP for Jiten Auto registration is:\n\n"
          "🔐 *$_generatedOtp*\n\n"
          "This OTP is valid for 5 minutes.\n"
          "Do not share this with anyone.\n\n"
          "Regards,\nJiten Auto Team";

      final url = Uri.parse(
        "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}",
      );

      await launchUrl(url, mode: LaunchMode.externalApplication);

      setState(() {
        otpSent = true;
        loading = false;
      });

      showMessage('OTP sent via WhatsApp. Enter it below.');
    } catch (e) {
      setState(() => loading = false);
      showMessage('Failed to open WhatsApp.');
    }
  }

  // STEP 2: Verify OTP and Register
  Future<void> verifyAndRegister() async {
    final enteredOtp = otpController.text.trim();

    if (enteredOtp.isEmpty) {
      showMessage('Please enter OTP.');
      return;
    }

    if (enteredOtp != _generatedOtp) {
      showMessage('Invalid OTP. Please try again.');
      return;
    }

    setState(() => loading = true);

    try {
      // Create Firebase Email/Password account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "email": emailController.text.trim(),
        "role": "customer",
        "createdAt": Timestamp.now(),
      });

      if (!mounted) return;
      showMessage('Registered Successfully!');
      Navigator.pop(context);
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
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
                    borderRadius: BorderRadius.circular(28)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_outlined,
                          size: 60, color: Color(0xFF7B1F3F)),
                      const SizedBox(height: 16),
                      const Text("Create Account",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        "Verify your phone via WhatsApp OTP",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),

                      // Name
                      TextField(
                        controller: nameController,
                        enabled: !otpSent,
                        decoration: _inputStyle("Full Name", Icons.person_outline),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        enabled: !otpSent,
                        decoration: _inputStyle("Phone Number (10 digits)", Icons.phone_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !otpSent,
                        decoration: _inputStyle("Email", Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        enabled: !otpSent,
                        decoration: _inputStyle("Password", Icons.lock_outline),
                      ),
                      const SizedBox(height: 16),

                      // OTP Field (shown after OTP sent)
                      if (otpSent) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.chat, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'OTP sent via WhatsApp. Check your messages.',
                                  style: TextStyle(color: Colors.green, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: _inputStyle("Enter 6-digit OTP", Icons.lock_clock_outlined),
                        ),
                        const SizedBox(height: 8),
                        // Resend OTP
                        TextButton.icon(
                          onPressed: () {
                            setState(() => otpSent = false);
                            otpController.clear();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Resend OTP"),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : otpSent
                                  ? verifyAndRegister
                                  : sendOTP,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(otpSent
                                  ? "Verify & Register"
                                  : "Send OTP via WhatsApp"),
                        ),
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

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}