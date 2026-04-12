import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../role_service.dart';
import '../admin/admin_dashboard.dart';
import '../staff/staff_dashboard.dart';
import '../auth/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // ✅ IMPORTANT
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return LoginScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder(
          future: RoleService().getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnap.data;

            if (role == 'admin') {
              return AdminDashboard();
            } else if (role == 'staff') {
              return StaffDashboard();
            } else {
              return Scaffold(
                body: Center(child: Text("No role assigned")),
              );
            }
          },
        );
      },
    );
  }
}