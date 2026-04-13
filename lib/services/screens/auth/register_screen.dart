import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String role = "customer";

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // 🔥 VALIDATION
    if (name.isEmpty) {
      showMessage("Please enter your full name.");
      return;
    }
    if (phone.isEmpty) {
      showMessage("Please enter your phone number.");
      return;
    }
    if (email.isEmpty) {
      showMessage("Please enter your email address.");
      return;
    }
    if (password.isEmpty) {
      showMessage("Please enter a password.");
      return;
    }

    setState(() => loading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        "name": name,
        "phone": phone,
        "email": email,
        "role": "customer", // ✅ ONLY CUSTOMER
        "createdAt": Timestamp.now(),
      });

      if (!mounted) return;
      showMessage("Registered Successfully");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      print("🔥 REGISTER ERROR CODE: ${e.code}");
      print("🔥 REGISTER ERROR MESSAGE: ${e.message}");

      showMessage(e.message ?? "Registration failed");
    } catch (e) {
      print("🔥 UNKNOWN ERROR: $e");
      if (mounted) showMessage("Something went wrong. Try again.");
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text("Create your account", style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      "Register and start managing showroom inquiries.",
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone Number"),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: "Select Role"),
                      items: const [
                        DropdownMenuItem(value: "staff", child: Text("Staff")),
                        DropdownMenuItem(value: "customer", child: Text("Customer")),
                      ],
                      onChanged: (val) {
                        setState(() => role = val!);
                      },
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : register,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Register"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}