import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:showroom_app/services/role_service.dart';
import 'package:showroom_app/services/screens/admin/admin_dashboard.dart';
import 'package:showroom_app/services/screens/auth/login_screen.dart';
import 'package:showroom_app/services/screens/customer/customer_home_screen.dart';
import 'package:showroom_app/services/screens/staff/staff_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final RoleService _roleService = RoleService();
  User? _user;
  String? _role;
  bool _loading = true;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        setState(() {
          _user = user;
          _role = null;
          _loading = user != null;
        });
        if (user != null) {
          _loadUserRole(user.uid);
        }
      },
    );
  }

  Future<void> _loadUserRole(String uid) async {
    final role = await _roleService.getUserRole(uid);
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const LoginScreen();
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_role) {
      case 'admin':
        return const AdminDashboard();
      case 'staff':
        return StaffDashboard();
      default:
        return const CustomerHomeScreen();
    }
  }
}
