import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'register_screen.dart';

// ── Cloudflare Worker Config ──────────────────────────────────────────────────
// Step 1: Replace with your Worker URL after Cloudflare deployment

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── controllers ──────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ── state ────────────────────────────────────────────────────────────────
  bool _loading = false;
  bool _obscurePassword = true;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // ── lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _msg(String text, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFF7B1F3F)
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _setLoading(bool value) {

    if (!mounted) return;

    setState(() {
      _loading = value;
    });
  }

  String _normalizeRole(String role) {
    final normalizedRole =
        role.trim().toLowerCase();

    if (normalizedRole == 'workshop') {
      return 'staff';
    }

    return normalizedRole;
  }

  // ── Login Button ──────────────────────────────────────────────────────────
  Future<void> _onLoginPressed() async {
  final email = _emailCtrl.text.trim();
  final password = _passwordCtrl.text.trim();

  if (email.isEmpty && password.isEmpty) {
    _msg("Please enter your email and password.");
    return;
  }

  if (email.isEmpty) {
    _msg("Please enter your email address.");
    return;
  }

  if (password.isEmpty) {
    _msg("Please enter your password.");
    return;
  }

  _setLoading(true);

  try {
    final credential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    Map<String, dynamic>? data;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      data = doc.data();
    } else {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        data = snap.docs.first.data();
      }
    }

    final role = _normalizeRole(
      (data?['role'] ?? '').toString(),
    );

    // _adminPhone = data?['phone'];

    // ADMIN LOGIN
    if (role == 'admin') {

      _navigateAdmin();

    } else {

      await credential.user!.reload();

      final updatedUser =
          FirebaseAuth.instance.currentUser;

      if (updatedUser != null &&
          updatedUser.emailVerified) {

        _navigateUser(role);

      } else {

        await updatedUser?.sendEmailVerification();

        _msg(
          "Please verify your email first. Verification link sent.",
        );

        await FirebaseAuth.instance.signOut();
      }
    }

  } on FirebaseAuthException catch (e) {

    _msg(_friendlyAuthError(e.code));

  } catch (e) {

    debugPrint("LOGIN ERROR: $e");

    _msg(
      "Something went wrong. Please try again.",
    );

  } finally {

    _setLoading(false);
  }
}

// ── Navigation ────────────────────────────────────────────────────────────
void _navigateUser(String role) {

  if (role == 'staff') {
    Navigator.pushReplacementNamed(
      context,
      '/staffDashboard',
    );

  } else if (role == 'customer') {

    Navigator.pushReplacementNamed(
      context,
      '/customerDashboard',
    );

  } else {

    Navigator.pushReplacementNamed(
      context,
      '/',
    );
  }
}

void _navigateAdmin() {

  Navigator.pushReplacementNamed(
    context,
    '/adminDashboard',
  );
} 

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'invalid-email':
        return "Please enter a valid email address.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'too-many-requests':
        return "Too many attempts. Please wait and try again.";
      case 'network-request-failed':
        return "Network error. Check your connection.";
      default:
        return "Login failed. Please try again.";
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
              constraints: const BoxConstraints(maxWidth: 500),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _slideCtrl,
                  child: Card(
                    elevation: 16,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _LoginPanel(
                          key: const ValueKey('login'),
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          loading: _loading,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () => setState(() =>
                              _obscurePassword = !_obscurePassword),
                          onLogin: _onLoginPressed,
                          theme: theme,
                        ),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PANEL WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onLogin,
    required this.theme,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Logo ──────────────────────────────────────────────────────────
        Container(
          height: 100, width: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/appLogo/applogo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/appLogo/applogo.jpeg',
                fit: BoxFit.contain,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "JitenAuto",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Drive leads faster with JitenAuto.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 28),

        // ── Email ─────────────────────────────────────────────────────────
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: "Email",
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Password ──────────────────────────────────────────────────────
        TextField(
          controller: passwordCtrl,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onLogin(),
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onToggleObscure,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Login button ──────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text("Login"),
          ),
        ),
        const SizedBox(height: 16),

        // ── Register link ─────────────────────────────────────────────────
       // WITH:
Wrap(
  alignment: WrapAlignment.center,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    const Text("Don't have an account?"),
    TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RegisterScreen()),
      ),
      child: const Text("Create Account"),
    ),
  ],
),
      ],
    );
  }
}
