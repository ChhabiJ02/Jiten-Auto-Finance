import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'register_screen.dart';

// ── Cloudflare Worker Config ──────────────────────────────────────────────────
// Step 1: Replace with your Worker URL after Cloudflare deployment
const String _workerUrl = "https://jiten-otp-worker.YOUR_SUBDOMAIN.workers.dev";
// Step 2: Set same value in Cloudflare → Worker → Environment Variables → APP_SECRET
const String _appSecret = "jiten-auto-otp-2024-secure";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _obscurePassword = true;
  bool _showOtpPanel = false;
  String? _adminPhone;
  String? _otpSessionId;
  int _resendTimer = 30;
  Timer? _timer;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _slideCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _msg(String text, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFF7B1F3F) : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _setLoading(bool v) => setState(() => _loading = v);

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendTimer == 0) { t.cancel(); }
      else { setState(() => _resendTimer--); }
    });
  }

  // ── Call Cloudflare Worker ────────────────────────────────────────────────
  Future<Map<String, dynamic>> _callWorker(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {
          "Content-Type": "application/json",
          "X-App-Secret": _appSecret,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } on TimeoutException {
      return {"success": false, "message": "Request timed out. Try again."};
    } catch (e) {
      return {"success": false, "message": "Network error. Check connection."};
    }
  }

  // ── Login Button ──────────────────────────────────────────────────────────
  Future<void> _onLoginPressed() async {
<<<<<<< HEAD

    final email =
        _emailCtrl.text.trim();

    final password =
        _passwordCtrl.text.trim();

    if (email.isEmpty &&
        password.isEmpty) {

      _msg(
        "Please enter your email and password.",
      );

      return;
    }

    if (email.isEmpty) {

      _msg(
        "Please enter your email address.",
      );

      return;
    }

    if (password.isEmpty) {

      _msg(
        "Please enter your password.",
      );

      return;
    }
=======
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty && password.isEmpty) { _msg("Please enter your email and password."); return; }
    if (email.isEmpty) { _msg("Please enter your email address."); return; }
    if (password.isEmpty) { _msg("Please enter your password."); return; }
>>>>>>> e06f1bff613f8e5bc6f8b97e2edce5fa19a2997a

    _setLoading(true);
    try {
<<<<<<< HEAD

      // LOGIN
      final credential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid =
          credential.user!.uid;

      // GET USER DATA
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      Map<String, dynamic>? data;

      // IF DOC NOT FOUND
      if (!doc.exists) {

        final snap =
            await FirebaseFirestore.instance
                .collection('users')
                .where(
                  'email',
                  isEqualTo: email,
                )
                .limit(1)
                .get();

        if (snap.docs.isEmpty) {

          _navigateUser(
            'customer',
          );

          return;
        }

        data =
            snap.docs.first.data();

      } else {

        data = doc.data();
      }

      final role =
          (data?['role'] ?? '')
              .toString()
              .toLowerCase();
=======
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = credential.user!.uid;

      Map<String, dynamic>? data;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        data = doc.data();
      } else {
        final snap = await FirebaseFirestore.instance
            .collection('users').where('email', isEqualTo: email).limit(1).get();
        if (snap.docs.isNotEmpty) data = snap.docs.first.data();
      }

      final role = (data?['role'] ?? '').toString().toLowerCase();
      _adminPhone = data?['phone'];
>>>>>>> e06f1bff613f8e5bc6f8b97e2edce5fa19a2997a

      _adminPhone =
          data?['phone'];

      // ADMIN
      if (role == 'admin') {
<<<<<<< HEAD

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdminOtpVerificationScreen(
              adminPhoneNumber:
                  _adminPhone ?? '',
            ),
          ),
        );

      } else {

        // EMAIL VERIFICATION
        await credential.user!
            .reload();

        final updatedUser =
            FirebaseAuth
                .instance
                .currentUser;

        if (updatedUser != null &&
            updatedUser.emailVerified) {

          _navigateUser(role);

        } else {

          await updatedUser
              ?.sendEmailVerification();

          _msg(
            "Please verify your email first. Verification link sent.",
          );

          await FirebaseAuth.instance
              .signOut();
        }
      }

    } on FirebaseAuthException catch (e) {

      debugPrint(
        "🔥 LOGIN ERROR: ${e.code} | ${e.message}",
      );

      _msg(
        _friendlyAuthError(
          e.code,
        ),
      );

    } catch (e) {

      debugPrint(
        "🔥 UNKNOWN ERROR: $e",
      );

      _msg(
        "Something went wrong. Please try again.",
      );

=======
        await _sendAdminOtp();
      } else {
        await credential.user!.reload();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.emailVerified) {
          _navigateUser();
        } else {
          await user?.sendEmailVerification();
          _msg("Please verify your email first. Verification link sent.");
          await FirebaseAuth.instance.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      _msg(_friendlyAuthError(e.code));
    } catch (e) {
      _msg("Something went wrong. Please try again.");
>>>>>>> e06f1bff613f8e5bc6f8b97e2edce5fa19a2997a
    } finally {

      _setLoading(false);
    }
  }
<<<<<<< HEAD
  // ── STEP 2 – Send OTP to admin phone ─────────────────────────────────────
  Future<void> _initiateAdminOtp(User user) async {
=======

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendAdminOtp() async {
>>>>>>> e06f1bff613f8e5bc6f8b97e2edce5fa19a2997a
    if (_adminPhone == null || _adminPhone!.isEmpty) {
      _msg("Admin phone number not configured in database.");
      await FirebaseAuth.instance.signOut();
      return;
    }
    _setLoading(true);
    try {
      String phone = _adminPhone!.replaceAll('+', '').replaceAll(' ', '');
      final result = await _callWorker({"action": "send", "phone": phone});
      if (result['success'] == true) {
        setState(() { _otpSessionId = result['sessionId']; _showOtpPanel = true; });
        _startResendTimer();
        _msg("OTP sent to ${_adminPhone!.replaceRange(3, _adminPhone!.length - 2, '••••••')}", error: false);
      } else {
        _msg(result['message'] ?? "Failed to send OTP.");
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      _msg("Failed to send OTP. Please try again.");
      await FirebaseAuth.instance.signOut();
    } finally {
      _setLoading(false);
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _onVerifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) { _msg("Please enter the complete 6-digit OTP."); return; }
    if (_otpSessionId == null) { _msg("Session expired. Please login again."); return; }
    _setLoading(true);
    try {
      final result = await _callWorker({"action": "verify", "sessionId": _otpSessionId, "otp": otp});
      if (result['success'] == true) {
        _timer?.cancel();
        _navigateAdmin();
      } else {
        _msg(result['message'] ?? "Invalid OTP. Please try again.");
      }
    } catch (e) {
      _msg("Something went wrong.");
    } finally {
      _setLoading(false);
    }
  }

<<<<<<< HEAD
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
    // Replace with your actual admin route
    Navigator.pushReplacementNamed(context, '/adminDashboard');
  }

=======
>>>>>>> e06f1bff613f8e5bc6f8b97e2edce5fa19a2997a
  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;
    for (final c in _otpCtrls) c.clear();
    _otpFocus[0].requestFocus();
    _setLoading(true);
    try {
      String phone = (_adminPhone ?? '').replaceAll('+', '').replaceAll(' ', '');
      final result = await _callWorker({"action": "resend", "phone": phone});
      if (result['success'] == true) {
        setState(() => _otpSessionId = result['sessionId']);
        _startResendTimer();
        _msg("OTP resent successfully.", error: false);
      } else {
        _msg(result['message'] ?? "Failed to resend OTP.");
      }
    } catch (e) {
      _msg("Something went wrong.");
    } finally {
      _setLoading(false);
    }
  }

  void _navigateUser() => Navigator.pushReplacementNamed(context, '/home');
  void _navigateAdmin() => Navigator.pushReplacementNamed(context, '/admin');

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found': return "No account found with this email.";
      case 'wrong-password': return "Incorrect password. Please try again.";
      case 'invalid-email': return "Please enter a valid email address.";
      case 'user-disabled': return "This account has been disabled.";
      case 'too-many-requests': return "Too many attempts. Please wait and try again.";
      case 'network-request-failed': return "Network error. Check your connection.";
      default: return "Login failed. Please try again.";
    }
  }

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
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
                                resendTimer: _resendTimer,
                                onVerify: _onVerifyOtp,
                                onResend: _resendOtp,
                                onBack: () async {
                                  _timer?.cancel();
                                  await FirebaseAuth.instance.signOut();
                                  setState(() {
                                    _showOtpPanel = false;
                                    _otpSessionId = null;
                                    for (final c in _otpCtrls) c.clear();
                                  });
                                },
                              )
                            : _LoginPanel(
                                key: const ValueKey('login'),
                                emailCtrl: _emailCtrl,
                                passwordCtrl: _passwordCtrl,
                                loading: _loading,
                                obscurePassword: _obscurePassword,
                                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
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

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({super.key, required this.emailCtrl, required this.passwordCtrl,
      required this.loading, required this.obscurePassword, required this.onToggleObscure,
      required this.onLogin, required this.theme});
  final TextEditingController emailCtrl, passwordCtrl;
  final bool loading, obscurePassword;
  final VoidCallback onToggleObscure, onLogin;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 80, width: 80,
          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.electric_car_outlined, color: theme.colorScheme.primary, size: 40),
        ),
        const SizedBox(height: 18),
        Text("JitenAuto", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text("Drive leads faster with JitenAuto.", textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        const SizedBox(height: 28),
        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: "Email", prefixIcon: const Icon(Icons.email_outlined),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        TextField(controller: passwordCtrl, obscureText: obscurePassword,
            textInputAction: TextInputAction.done, onSubmitted: (_) => onLogin(),
            decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: onToggleObscure),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onLogin,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: loading ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Login"),
            )),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text("Don't have an account?"),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
              child: const Text("Create Account")),
        ]),
      ],
    );
  }
}

class _OtpPanel extends StatelessWidget {
  const _OtpPanel({super.key, required this.phone, required this.otpCtrls, required this.otpFocus,
      required this.loading, required this.resendTimer, required this.onVerify,
      required this.onResend, required this.onBack});
  final String phone;
  final List<TextEditingController> otpCtrls;
  final List<FocusNode> otpFocus;
  final bool loading;
  final int resendTimer;
  final VoidCallback onVerify, onResend, onBack;

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
        Align(alignment: Alignment.centerLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: onBack)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF7B1F3F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7B1F3F).withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFF7B1F3F)),
            SizedBox(width: 6),
            Text("Admin Verification", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7B1F3F))),
          ]),
        ),
        const SizedBox(height: 18),
        Container(height: 72, width: 72,
            decoration: BoxDecoration(color: const Color(0xFF7B1F3F).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF7B1F3F), size: 36)),
        const SizedBox(height: 16),
        Text("Enter OTP", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("A 6-digit code was sent to\n$_maskedPhone", textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => SizedBox(
            width: 44,
            child: TextField(
              controller: otpCtrls[i], focusNode: otpFocus[i],
              keyboardType: TextInputType.number, textAlign: TextAlign.center,
              maxLength: 1, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(counterText: '', filled: true, fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7B1F3F), width: 2))),
              onChanged: (val) {
                if (val.isNotEmpty && i < 5) otpFocus[i + 1].requestFocus();
                if (val.isEmpty && i > 0) otpFocus[i - 1].requestFocus();
                if (i == 5 && val.isNotEmpty) {
                  final full = otpCtrls.map((c) => c.text).join();
                  if (full.length == 6) onVerify();
                }
              },
            ),
          )),
        ),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onVerify,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: const Color(0xFF7B1F3F), foregroundColor: Colors.white),
              child: loading ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Verify & Continue", style: TextStyle(fontWeight: FontWeight.w600)),
            )),
        const SizedBox(height: 16),
        resendTimer > 0
            ? Text("Resend OTP in $resendTimer seconds", style: TextStyle(color: Colors.grey.shade500))
            : TextButton.icon(onPressed: loading ? null : onResend,
                icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text("Resend OTP")),
      ],
    );
  }
}