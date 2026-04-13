import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inquiry_list_screen.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text("View All Inquiries"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InquiryListScreen()),
            );
          },
        ),
      ),
    );
  }
}