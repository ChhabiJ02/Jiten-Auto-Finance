import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AddInquiryScreen extends StatefulWidget {
  @override
  State<AddInquiryScreen> createState() => _AddInquiryScreenState();
}

class _AddInquiryScreenState extends State<AddInquiryScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final priceController = TextEditingController();
  final referenceController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  bool loading = false;

  // 🔥 WHATSAPP FUNCTION
  Future<void> sendWhatsAppAndSave() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final price = priceController.text.trim();

    if (name.isEmpty || phone.isEmpty || brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill required fields")),
      );
      return;
    }

    final message = "Thank you $name 🙏\n"
        "For your inquiry at Jiten Auto.\n"
        "Vehicle: $brand $model\n"
        "Price: ₹$price\n"
        "Date: ${selectedDate.toString().split(' ')[0]}";

    final url = Uri.parse("https://wa.me/91$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      await saveInquiry(); // 🔥 SAVE AFTER WHATSAPP
    }
  }

  Future<void> saveInquiry() async {
    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('inquiries').add({
      "name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "brand": brandController.text.trim(),
      "model": modelController.text.trim(),
      "price": priceController.text.trim(),
      "reference": referenceController.text.trim(),
      "date": selectedDate,
      "createdBy": user!.uid,
      "createdAt": Timestamp.now(),
      "nextFollowUp": Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 2)),
      )
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lead Saved")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Inquiry")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
            TextField(controller: brandController, decoration: const InputDecoration(labelText: "Vehicle Brand")),
            TextField(controller: modelController, decoration: const InputDecoration(labelText: "Model")),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: "Price")),
            TextField(controller: referenceController, decoration: const InputDecoration(labelText: "Reference")),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: sendWhatsAppAndSave,
              icon: const Icon(Icons.message),
              label: const Text("Send WhatsApp & Save"),
            )
          ],
        ),
      ),
    );
  }
}