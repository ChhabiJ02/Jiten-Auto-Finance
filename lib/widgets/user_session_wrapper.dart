import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSessionWrapper extends StatefulWidget {
  final Widget child;
  const UserSessionWrapper({super.key, required this.child});

  @override
  State<UserSessionWrapper> createState() => _UserSessionWrapperState();
}

class _UserSessionWrapperState extends State<UserSessionWrapper> {
  StreamSubscription<DocumentSnapshot>? _subscription;
  bool _logoutTriggered = false;
  String? _initialRole;
  bool _baselineSet = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (_logoutTriggered) return;

      if (!snapshot.exists) {
        await _forceLogout("Your account has been removed by the admin.");
        return;
      }

      final data = snapshot.data()!;

      if (data['isDisabled'] == true) {
        await _forceLogout("Your account has been disabled by the admin.");
        return;
      }

      final currentRole = data['role'] as String?;

      if (!_baselineSet) {
        _initialRole = currentRole;
        _baselineSet = true;
        return;
      }

      if (currentRole != null && currentRole != _initialRole) {
        await _forceLogout(
          "Your role has been updated by the admin. Please log in again.",
        );
      }
    });
  }

  Future<void> _forceLogout(String reason) async {
    _logoutTriggered = true;
    _subscription?.cancel();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}