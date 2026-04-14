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
        "For your inquiry at JitenAuto.\n"
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("New Inquiry")),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7B1F3F), Color(0xFFF4DBE1)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.message_outlined,
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "New Inquiry",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Capture the lead details and send a WhatsApp confirmation.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Customer Name",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Phone Number",
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: brandController,
                        decoration: InputDecoration(
                          labelText: "Vehicle Brand",
                          prefixIcon: const Icon(Icons.directions_car_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: modelController,
                        decoration: InputDecoration(
                          labelText: "Model",
                          prefixIcon: const Icon(Icons.precision_manufacturing),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Price",
                          prefixIcon: const Icon(Icons.currency_rupee),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: referenceController,
                        decoration: InputDecoration(
                          labelText: "Reference",
                          prefixIcon: const Icon(Icons.note_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.message),
                          label: const Text("Send WhatsApp & Save"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: sendWhatsAppAndSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}