import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddInquiryScreen extends StatefulWidget {
  @override
  State<AddInquiryScreen> createState() => _AddInquiryScreenState();
}

class _AddInquiryScreenState extends State<AddInquiryScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final referenceController = TextEditingController();
  final vehicleController = TextEditingController();
  final modelController = TextEditingController();
  final notesController = TextEditingController();

  bool loading = false;

  Future<void> saveInquiry() async {
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        vehicleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('inquiries').add({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "reference": referenceController.text.trim(),
        "vehicle": vehicleController.text.trim(),
        "model": modelController.text.trim(),
        "notes": notesController.text.trim(),
        "createdBy": user!.uid,
        "createdAt": Timestamp.now(),
        "source": "offline"
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inquiry Added Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving inquiry")),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Inquiry")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Customer Name"),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(labelText: "Reference"),
            ),
            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(labelText: "Vehicle"),
            ),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: "Model"),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: "Notes"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : saveInquiry,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Inquiry"),
            ),
          ],
        ),
      ),
    );
  }
}