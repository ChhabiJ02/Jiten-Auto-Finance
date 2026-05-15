import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/cloudinary_service.dart';
import 'widgets/user_session_wrapper.dart';

import 'services/screens/auth/login_screen.dart';
import 'services/screens/admin/admin_dashboard.dart';
import 'services/screens/staff/staff_dashboard.dart';
import 'services/screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: const SplashScreen(), // ← changed
      routes: {
        '/login': (context) => const LoginScreen(),
        '/adminDashboard': (context) => UserSessionWrapper(child: AdminDashboard()),
        '/staffDashboard': (context) => UserSessionWrapper(child: StaffDashboard()),
        '/customerDashboard': (context) => UserSessionWrapper(child: const CustomerHomeScreen()),
      },
    );
  }
}

// ─── Splash Screen ───────────────────────────────────────────
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Navigate to Login after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
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
            colors: [
              Color(0xFF7B1F3F), // dark maroon
              Color(0xFF4A0E24), // deeper maroon
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with white circular background
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/applogo/jitenlogo.jpeg',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 30),

                // App Name
                const Text(
                  'Jiten Auto Finance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Your Trusted Auto Partner',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 60),

                // Loading indicator
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}