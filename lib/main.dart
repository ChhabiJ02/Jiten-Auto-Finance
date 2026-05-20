import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/cloudinary_service.dart';
import 'widgets/user_session_wrapper.dart';
import 'services/screens/auth/email_otp_verification_screen.dart';
import 'services/screens/auth/login_screen.dart';
import 'services/screens/auth/password_reset_screen.dart';
import 'services/screens/admin/admin_dashboard.dart';
import 'services/screens/staff/staff_dashboard.dart';
import 'services/screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  CloudinaryService.initialize(
    cloudName: 'dzgudsmu8',
    uploadPreset: 'showroom_upload',
    apiKey: '551463428811977',
    apiSecret: '6V9O6AzisHCDLFeQeRqwTeJJUrQ',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jiten Auto',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B1F3F),
          primary: const Color(0xFF7B1F3F),
          secondary: const Color(0xFFF4DBE1),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9EEF2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7B1F3F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B1F3F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFF7B1F3F), width: 1.5),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/passwordReset': (context) => const PasswordResetScreen(),
        '/adminDashboard': (context) =>
            UserSessionWrapper(child: AdminDashboard()),
        '/staffDashboard': (context) =>
            UserSessionWrapper(child: StaffDashboard()),
        '/customerDashboard': (context) =>
            UserSessionWrapper(child: const CustomerHomeScreen()),
      },
    );
  }
}

// ─── ONE Splash Screen — no native splash, no duplicate ──────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _startApp();
  }

  Future<void> _startApp() async {
    if (mounted && _startupError != null) {
      setState(() => _startupError = null);
    }

    final startedAt = DateTime.now();

    try {
      await Firebase.initializeApp();

      final elapsed = DateTime.now().difference(startedAt);

      const minDuration = Duration(seconds: 2);

      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }

      if (!mounted) return;

      // CHECK EXISTING LOGIN
      final user = FirebaseAuth.instance.currentUser;

      // NOT LOGGED IN
      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');

        return;
      }

      // FETCH USER ROLE
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final role = (userData?['role'] ?? '').toString().toLowerCase();

      final firestoreVerified = userData?['emailVerified'] == true;

      if (user.emailVerified && !firestoreVerified && userDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'emailVerified': true, 'verifiedAt': Timestamp.now()});
      }

      final isVerified =
          role == 'admin' || firestoreVerified || user.emailVerified;

      if (!isVerified && user.email != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOtpVerificationScreen(
              email: user.email!,
              uid: user.uid,
              role: role,
            ),
          ),
        );

        return;
      }

      // NAVIGATE BY ROLE
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else if (role == 'staff' || role == 'workshop') {
        Navigator.pushReplacementNamed(context, '/staffDashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/customerDashboard');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _startupError = 'Unable to start the app. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7B1F3F), Color(0xFF4A0E24)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo in rounded square (matches native splash style)
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/appLogo/applogo.png', // exact path, capital L
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // App name
                          const Text(
                            'Jiten Auto Finance',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline
                          const Text(
                            'Multi brand 2 wh. showroom & workshop',
                            style: TextStyle(
                              color: Color(0xFFE8B4C4),
                              fontSize: 13,
                              letterSpacing: 0.4,
                            ),
                          ),

                          const SizedBox(height: 60),

                          if (_startupError == null)
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.white.withOpacity(0.7),
                                strokeWidth: 2.5,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _startupError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _startApp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF7B1F3F),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  "Featured: Rex Solution'S",
                  style: TextStyle(
                    color: Color(0xFFE8B4C4),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
