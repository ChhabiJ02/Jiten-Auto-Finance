import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../role_service.dart';
import '../admin/admin_dashboard.dart';
import '../staff/staff_dashboard.dart';
import '../auth/login_screen.dart';
import '../customer/customer_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔹 NOT LOGGED IN
        if (!snapshot.hasData) {
          return LoginScreen();
        }

        final user = snapshot.data!;

        // 🔥 DEBUG
        print("🔥 UID: ${user.uid}");

        return FutureBuilder(
          future: RoleService().getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnap.data;

            // 🔥 DEBUG
            print("🔥 ROLE: $role");

            if (role == 'admin') {
              return AdminDashboard();
            } else if (role == 'staff') {
              return StaffDashboard();
            } else if (role == 'customer') {
              return CustomerHomeScreen();
            } else {
              // 🔥 FALLBACK SCREEN
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("No role assigned ❌"),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                        },
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}