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

  bool loading = false;
  bool emailVerificationSent = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // STEP 1: Register and send email verification
  Future<void> registerAndSendVerification() async {
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
      // Create Firebase Email/Password account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Save to Firestore (pending verification)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        "uid": userCredential.user!.uid,
        "name": name,
        "phone": phone,
        "email": email,
        "role": "customer",
        "emailVerified": false,
        "createdAt": Timestamp.now(),
      });

      setState(() {
        emailVerificationSent = true;
        loading = false;
      });

      showMessage('Verification email sent! Please check your inbox.');
    } catch (e) {
      setState(() => loading = false);
      showMessage(e.toString());
    }
  }

  // STEP 2: Check if email is verified
  Future<void> checkEmailVerified() async {
    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage('No user found. Please register again.');
        setState(() => loading = false);
        return;
      }

      // Reload user to get latest verification status
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // Update Firestore emailVerified flag
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .update({"emailVerified": true});

        if (!mounted) return;
        showMessage('Email verified! Registration complete.');
        Navigator.pop(context);
      } else {
        showMessage('Email not verified yet. Please check your inbox.');
      }
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        showMessage('Verification email resent!');
      }
    } catch (e) {
      showMessage('Failed to resend: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
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
                      Text(
                        emailVerificationSent
                            ? "A verification link has been sent to your email"
                            : "Register with your email address",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),

                      if (!emailVerificationSent) ...[
                        // Name
                        TextField(
                          controller: nameController,
                          decoration:
                              _inputStyle("Full Name", Icons.person_outline),
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: _inputStyle(
                              "Phone Number (10 digits)", Icons.phone_outlined),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              _inputStyle("Email", Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration:
                              _inputStyle("Password", Icons.lock_outline),
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                loading ? null : registerAndSendVerification,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("Register"),
                          ),
                        ),
                      ] else ...[
                        // Email verification pending UI
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.mark_email_unread_outlined,
                                  color: Colors.blue),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Check your inbox and click the verification link, then tap "I have Verified" below.',
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // I've Verified Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: loading ? null : checkEmailVerified,
                            icon: const Icon(Icons.verified_outlined),
                            label: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("I've Verified My Email"),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Resend email
                        TextButton.icon(
                          onPressed: resendVerificationEmail,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Resend Verification Email"),
                        ),
                      ],
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