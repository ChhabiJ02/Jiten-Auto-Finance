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

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> sendWhatsAppAndSave() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final price = priceController.text.trim();

    if (name.isEmpty) {
      showMessage("Please enter the customer name.");
      return;
    }
    if (phone.isEmpty) {
      showMessage("Please enter the customer phone number.");
      return;
    }
    if (brand.isEmpty) {
      showMessage("Please enter the vehicle brand.");
      return;
    }

    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappNumber = sanitizedPhone.startsWith('91')
        ? sanitizedPhone
        : sanitizedPhone.length == 10
            ? '91$sanitizedPhone'
            : sanitizedPhone;

    if (whatsappNumber.length < 10) {
      showMessage("Please enter a valid phone number for WhatsApp.");
      return;
    }

    final message = "Thank you $name 🙏\n"
        "For your inquiry at Jiten Auto.\n"
        "Vehicle: $brand $model\n"
        "Price: ₹$price\n"
        "Date: ${selectedDate.toString().split(' ')[0]}";

    final whatsappUri = Uri.parse(
      "whatsapp://send?phone=$whatsappNumber&text=${Uri.encodeComponent(message)}",
    );
    final webUri = Uri.parse(
      "https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}",
    );

    var launched = false;

    try {
      launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      showMessage("WhatsApp is not available on this device.");
      return;
    }

    await saveInquiry();
  }

  Future<bool> saveInquiry() async {
    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage("Unable to save inquiry: user not signed in.");
        return false;
      }

      await FirebaseFirestore.instance.collection('inquiries').add({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "brand": brandController.text.trim(),
        "model": modelController.text.trim(),
        "price": priceController.text.trim(),
        "reference": referenceController.text.trim(),
        "date": selectedDate,
        "createdBy": user.uid,
        "createdAt": Timestamp.now(),
        "nextFollowUp": Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 2)),
        )
      });

      if (mounted) {
        showMessage("WhatsApp launched and inquiry saved.");
        Navigator.pop(context);
      }
      return true;
    } catch (e) {
      if (mounted) {
        showMessage("Failed to save inquiry. Please try again.");
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
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