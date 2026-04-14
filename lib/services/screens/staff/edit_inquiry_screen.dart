import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditInquiryScreen extends StatefulWidget {
  final QueryDocumentSnapshot inquiry;

  const EditInquiryScreen({super.key, required this.inquiry});

  @override
  State<EditInquiryScreen> createState() => _EditInquiryScreenState();
}

class _EditInquiryScreenState extends State<EditInquiryScreen> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController brandController;
  late final TextEditingController modelController;
  late final TextEditingController priceController;
  late final TextEditingController referenceController;
  late DateTime selectedDate;
  bool loading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    final data = widget.inquiry.data() as Map<String, dynamic>;
    nameController = TextEditingController(text: data['name'] ?? '');
    phoneController = TextEditingController(text: data['phone'] ?? '');
    brandController = TextEditingController(text: data['brand'] ?? '');
    modelController = TextEditingController(text: data['model'] ?? '');
    priceController = TextEditingController(text: data['price'] ?? '');
    referenceController = TextEditingController(text: data['reference'] ?? '');
    final nextFollowUp = data['nextFollowUp'];
    selectedDate = nextFollowUp is Timestamp
        ? nextFollowUp.toDate()
        : DateTime.now();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    brandController.dispose();
    modelController.dispose();
    priceController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final price = priceController.text.trim();
    final reference = referenceController.text.trim();

    if (name.isEmpty) {
      showMessage('Please enter the customer name.');
      return;
    }
    if (phone.isEmpty) {
      showMessage('Please enter the customer phone number.');
      return;
    }
    if (brand.isEmpty) {
      showMessage('Please enter the vehicle brand.');
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage('Unable to save inquiry: user not signed in.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('inquiries')
          .doc(widget.inquiry.id)
          .update({
        'name': name,
        'phone': phone,
        'brand': brand,
        'model': model,
        'price': price,
        'reference': reference,
        'nextFollowUp': Timestamp.fromDate(selectedDate),
      });

      if (mounted) {
        showMessage('Inquiry updated successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showMessage('Failed to update inquiry. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Lead')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: brandController,
              decoration: const InputDecoration(labelText: 'Vehicle Brand'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(labelText: 'Reference'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Follow up: ${selectedDate.toString().split(' ')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _pickFollowUpDate,
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _saveChanges,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
