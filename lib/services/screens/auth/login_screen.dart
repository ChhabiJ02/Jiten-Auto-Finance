import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLOW OVERVIEW
//
//  1. User enters email + password → taps Login
//  2. Check Firestore: users/{uid} or users collection where email == input
//     • If doc has  role == "admin"  →  trigger SMS OTP panel
//       - signInWithEmailAndPassword first (to verify password via Firebase)
//       - Then send OTP to admin's phone (stored in Firestore doc)
//       - Verify OTP panel shown
//       - On success → navigate to AdminDashboard (replace route name below)
//     • Otherwise → normal Firebase email/password sign-in
//       - On success → navigate to HomeScreen (replace route name below)
//
//  Firestore user document shape expected:
//  {
//    "email": "admin@example.com",
//    "role": "admin",           // "admin" | "user"
//    "phone": "+919876543210"   // required for admin SMS OTP
//  }
// ─────────────────────────────────────────────────────────────────────────────

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
  final List<TextEditingController> _otpCtrls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  // ── state ────────────────────────────────────────────────────────────────
  bool _loading = false;
  bool _obscurePassword = true;
  bool _showOtpPanel = false;

  String? _verificationId;
  String? _adminPhone;
  int? _resendToken;

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
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
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

  void _setLoading(bool v) => setState(() => _loading = v);

  // ── STEP 1 – Login button ─────────────────────────────────────────────────
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
      // ── Authenticate with Firebase first ──────────────────────────────
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // ── Check role in Firestore ───────────────────────────────────────
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        // Fallback: query by email field if doc keyed differently
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          // No Firestore record → treat as regular user, already signed in
          _navigateUser();
          return;
        }

        final data = snap.docs.first.data();
        final role = (data['role'] ?? '').toString().toLowerCase();
        _adminPhone = data['phone'];
        if (role == 'admin') {
          await _initiateAdminOtp(credential.user!);
        } else {
          _navigateUser();
        }
        return;
      }

      final data = doc.data()!;
      final role = (data['role'] ?? '').toString().toLowerCase();
      _adminPhone = data['phone'];

      // if (role == 'admin') {
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (_) =>
      //           AdminOtpVerificationScreen(adminPhoneNumber: _adminPhone ?? ''),
      //     ),
      //   );
      // }
      if (role == 'admin') {
        await _initiateAdminOtp(credential.user!);
      }
      else {
        // EMAIL VERIFICATION FOR STAFF/CUSTOMER

        await credential.user!.reload();

        final updatedUser = FirebaseAuth.instance.currentUser;

        if (updatedUser != null && updatedUser.emailVerified) {
          _navigateUser();
        } else {
          await updatedUser?.sendEmailVerification();

          _msg("Please verify your email first. Verification link sent.");

          await FirebaseAuth.instance.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 LOGIN ERROR: ${e.code} | ${e.message}");
      _msg(_friendlyAuthError(e.code));
    } catch (e) {
      debugPrint("🔥 UNKNOWN ERROR: $e");
      _msg("Something went wrong. Please try again.");
    } finally {
      _setLoading(false);
    }
  }

  // ── STEP 2 – Send OTP to admin phone ─────────────────────────────────────
  Future<void> _initiateAdminOtp(User user) async {
    if (_adminPhone == null || _adminPhone!.isEmpty) {
      _msg("Admin phone number not configured in database.");
      await FirebaseAuth.instance.signOut();
      return;
    }

    _setLoading(true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _adminPhone!,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        // Auto-retrieval on Android
        await _completeAdminLogin(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint("📵 OTP send failed: ${e.code} | ${e.message}");
        _msg("Failed to send OTP: ${e.message ?? e.code}");
        _setLoading(false);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _showOtpPanel = true;
          _loading = false;
        });
        _msg(
          "OTP sent to ${_adminPhone!.replaceRange(3, _adminPhone!.length - 2, '••••••')}",
          error: false,
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── STEP 3 – Verify OTP ───────────────────────────────────────────────────
  Future<void> _onVerifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      _msg("Please enter the complete 6-digit OTP.");
      return;
    }
    if (_verificationId == null) {
      _msg("Verification session expired. Please try again.");
      return;
    }

    _setLoading(true);

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _completeAdminLogin(cred);
    } on FirebaseAuthException catch (e) {
      debugPrint("📵 OTP verify error: ${e.code}");
      _msg(
        e.code == 'invalid-verification-code'
            ? "Invalid OTP. Please check and try again."
            : (e.message ?? "OTP verification failed."),
      );
    } catch (e) {
      _msg("Something went wrong.");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _completeAdminLogin(PhoneAuthCredential cred) async {
    // Link phone credential to the already-signed-in admin account
    try {
      await FirebaseAuth.instance.currentUser?.linkWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      // credential-already-in-use is fine – already linked
      if (e.code != 'credential-already-in-use' &&
          e.code != 'provider-already-linked') {
        rethrow;
      }
    }
    _navigateAdmin();
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _navigateUser() {
    // Replace with your actual route
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _navigateAdmin() {
    // Replace with your actual admin route
    Navigator.pushReplacementNamed(context, '/admin');
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() {
      for (final c in _otpCtrls) {
        c.clear();
      }
    });
    await _initiateAdminOtp(FirebaseAuth.instance.currentUser!);
  }

  // ── Auth error → human text ───────────────────────────────────────────────
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
                        child: _showOtpPanel
                            ? _OtpPanel(
                                key: const ValueKey('otp'),
                                phone: _adminPhone ?? '',
                                otpCtrls: _otpCtrls,
                                otpFocus: _otpFocus,
                                loading: _loading,
                                onVerify: _onVerifyOtp,
                                onResend: _resendOtp,
                                onBack: () async {
                                  await FirebaseAuth.instance.signOut();
                                  setState(() {
                                    _showOtpPanel = false;
                                    for (final c in _otpCtrls) {
                                      c.clear();
                                    }
                                  });
                                },
                              )
                            : _LoginPanel(
                                key: const ValueKey('login'),
                                emailCtrl: _emailCtrl,
                                passwordCtrl: _passwordCtrl,
                                loading: _loading,
                                obscurePassword: _obscurePassword,
                                onToggleObscure: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
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
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.electric_car_outlined,
            color: theme.colorScheme.primary,
            size: 40,
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

// ─────────────────────────────────────────────────────────────────────────────
// OTP PANEL WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _OtpPanel extends StatelessWidget {
  const _OtpPanel({
    super.key,
    required this.phone,
    required this.otpCtrls,
    required this.otpFocus,
    required this.loading,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  final String phone;
  final List<TextEditingController> otpCtrls;
  final List<FocusNode> otpFocus;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  String get _maskedPhone {
    if (phone.length < 5) return phone;
    return '${phone.substring(0, 3)}••••${phone.substring(phone.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Back button ───────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: onBack,
            tooltip: "Back to login",
          ),
        ),
        const SizedBox(height: 4),

        // ── Admin badge ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7B1F3F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7B1F3F).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 16,
                color: const Color(0xFF7B1F3F),
              ),
              const SizedBox(width: 6),
              Text(
                "Admin Verification",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7B1F3F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Shield icon ───────────────────────────────────────────────────
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF7B1F3F).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Color(0xFF7B1F3F),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "Enter OTP",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "A 6-digit code was sent to\n$_maskedPhone",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // ── OTP boxes ─────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 44,
              child: TextField(
                controller: otpCtrls[i],
                focusNode: otpFocus[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF7B1F3F),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) {
                    otpFocus[i + 1].requestFocus();
                  }
                  if (val.isEmpty && i > 0) {
                    otpFocus[i - 1].requestFocus();
                  }
                  // Auto-submit when last digit filled
                  if (i == 5 && val.isNotEmpty) {
                    final full = otpCtrls.map((c) => c.text).join();
                    if (full.length == 6) onVerify();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // ── Verify button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onVerify,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF7B1F3F),
              foregroundColor: Colors.white,
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
                : const Text(
                    "Verify & Continue",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Resend ────────────────────────────────────────────────────────
        TextButton.icon(
          onPressed: loading ? null : onResend,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text("Resend OTP"),
        ),
      ],
    );
  }
}
