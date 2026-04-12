import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_inquiry_screen.dart';

class StaffDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),

      // 👇 KEEP BODY SIMPLE FOR NOW
      body: const Center(
        child: Text("Click + to add inquiry"),
      ),

      // 🔥 THIS IS THE BUTTON YOU ASKED "WHERE"
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddInquiryScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}