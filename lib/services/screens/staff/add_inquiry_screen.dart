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
  final variantController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  final referenceController = TextEditingController();
  final otherController = TextEditingController();

  String? selectedVehicleId;
  String paymentType = 'Loan';
  String status = 'New Inquiry';
  DateTime selectedDate = DateTime.now();

  bool loading = false;
  bool lookupLoading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _lookupVehicle() async {
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();

    if (brand.isEmpty || model.isEmpty || variant.isEmpty) {
      showMessage('Enter brand, model and variant to fetch vehicle details.');
      return;
    }

    setState(() => lookupLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('brand', isEqualTo: brand)
          .where('model', isEqualTo: model)
          .where('variant', isEqualTo: variant)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final vehicle = query.docs.first;
        final data = vehicle.data() as Map<String, dynamic>;
        selectedVehicleId = vehicle.id;
        priceController.text = data['price']?.toString() ?? priceController.text;
        descriptionController.text = data['description'] ?? descriptionController.text;
        showMessage('Vehicle details loaded from catalog.');
      } else {
        showMessage('No matching vehicle found in catalog.');
      }
    } catch (_) {
      showMessage('Failed to fetch vehicle details.');
    } finally {
      if (mounted) setState(() => lookupLoading = false);
    }
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
        "Vehicle: $brand ${model.isNotEmpty ? model : ''} ${variantController.text.trim().isNotEmpty ? '(${variantController.text.trim()})' : ''}\n"
        "Price: ₹$price\n"
        "Description: ${descriptionController.text.trim()}\n"
        "Payment: $paymentType\n"
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
        "variant": variantController.text.trim(),
        "vehicleId": selectedVehicleId,
        "price": priceController.text.trim(),
        "description": descriptionController.text.trim(),
        "paymentType": paymentType,
        "otherDescription": otherController.text.trim(),
        "reference": referenceController.text.trim(),
        "status": status,
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
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    brandController.dispose();
    modelController.dispose();
    variantController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    referenceController.dispose();
    otherController.dispose();
    super.dispose();
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
                        controller: variantController,
                        decoration: InputDecoration(
                          labelText: "Variant",
                          prefixIcon: const Icon(Icons.widgets_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: lookupLoading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Fetch price & description'),
                          onPressed: lookupLoading ? null : _lookupVehicle,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        controller: descriptionController,
                        maxLines: 3,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Vehicle Description",
                          prefixIcon: const Icon(Icons.info_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: paymentType,
                        items: const [
                          DropdownMenuItem(value: 'Loan', child: Text('Loan')),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => paymentType = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Payment Option',
                          prefixIcon: const Icon(Icons.payment_outlined),
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
                        controller: otherController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Other Description",
                          prefixIcon: const Icon(Icons.description_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'New Inquiry', child: Text('New Inquiry')),
                          DropdownMenuItem(value: 'Follow Ups', child: Text('Follow Ups')),
                          DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                          DropdownMenuItem(value: 'Booked', child: Text('Booked')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => status = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Inquiry Status',
                          prefixIcon: const Icon(Icons.filter_list_outlined),
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