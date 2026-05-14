import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/cloudinary_service.dart';
import 'widgets/user_session_wrapper.dart';

import 'services/screens/auth/login_screen.dart';
import 'services/screens/admin/admin_dashboard.dart';
import 'services/screens/staff/staff_dashboard.dart';
import 'services/screens/customer/customer_home_screen.dart';

// ADD THIS if you have workshop dashboard
// import 'services/screens/workshop/workshop_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Initialize Cloudinary
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
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
            borderSide: BorderSide(
              color: Color(0xFF7B1F3F),
              width: 1.5,
            ),
          ),
        ),
      ),

      home: const LoginScreen(),

      routes: {
        '/login': (context) => const LoginScreen(),

        '/adminDashboard': (context) =>
            UserSessionWrapper(
              child: AdminDashboard(),
            ),

        '/staffDashboard': (context) =>
            UserSessionWrapper(
              child: StaffDashboard(),
            ),

        '/customerDashboard': (context) =>
            UserSessionWrapper(
              child: const CustomerHomeScreen(),
            ),

        // ADD THIS ONLY IF YOU HAVE WORKSHOP DASHBOARD
        /*
        '/workshopDashboard': (context) =>
            UserSessionWrapper(
              child: WorkshopDashboard(),
            ),
        */
      },
    );
  }
}