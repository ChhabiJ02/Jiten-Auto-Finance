import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final otpController = TextEditingController(); // New controller for OTP

  bool loading = false;
  String _verificationId = ""; // To store Firebase verification ID

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // --- STEP 1: SEND OTP ---
  Future<void> sendOTP() async {
    final phone = phoneController.text.trim();
    
    // Simple validation for India (+91). Ensure user adds country code.
    if (!phone.startsWith('+')) {
      showMessage("Please include country code (e.g. +91)");
      return;
    }

    setState(() => loading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval (Android only)
        await registerWithEmailAndPhone(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => loading = false);
        showMessage(e.message ?? "Verification failed");
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          loading = false;
        });
        _showOTPDialog(); // Show the popup to enter OTP
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // --- STEP 2: SHOW OTP POPUP ---
  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter OTP"),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "6-digit code"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              PhoneAuthCredential credential = PhoneAuthProvider.credential(
                verificationId: _verificationId,
                smsCode: otpController.text.trim(),
              );
              Navigator.pop(context); // Close dialog
              await registerWithEmailAndPhone(credential);
            },
            child: const Text("Verify & Register"),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: FINAL REGISTRATION ---
  Future<void> registerWithEmailAndPhone(PhoneAuthCredential phoneCredential) async {
    setState(() => loading = true);
    try {
      // 1. Create Email/Password Account
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Link the Phone Number to this account (Optional but recommended)
      await userCredential.user!.linkWithCredential(phoneCredential);

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "email": emailController.text.trim(),
        "role": "customer",
        "createdAt": Timestamp.now(),
      });

      if (!mounted) return;
      showMessage("Registered Successfully");
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
    // final theme = Theme.of(context);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ... (Your existing Icon and Header Widgets here) ...

                      const SizedBox(height: 28),
                      TextField(
                        controller: nameController,
                        decoration: _inputStyle("Full Name", Icons.person_outline),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputStyle("Phone (e.g. +91...)", Icons.phone_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputStyle("Email", Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: _inputStyle("Password", Icons.lock_outline),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : sendOTP, // Now triggers OTP
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Send OTP & Register"),
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