import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen({super.key});

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final variantController = TextEditingController();
  final registrationController = TextEditingController();
  final notesController = TextEditingController();
  final servicePackageController = TextEditingController();
  final remainingServicesController = TextEditingController();

  String serviceType = 'Regular Service';
  bool boughtFromUs = false;
  DateTime preferredDate = DateTime.now().add(const Duration(days: 1));
  bool loading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => preferredDate = picked);
    }
  }

  Future<void> saveServiceRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final brand = brandController.text.trim();
    final model = modelController.text.trim();

    if (brand.isEmpty) {
      showMessage('Please enter the vehicle brand.');
      return;
    }
    if (model.isEmpty) {
      showMessage('Please enter the vehicle model.');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'userId': user.uid,
        'customerEmail': user.email,
        'vehicleBrand': brand,
        'vehicleModel': model,
        'variant': variantController.text.trim(),
        'registrationNumber': registrationController.text.trim(),
        'serviceType': serviceType,
        'boughtFromUs': boughtFromUs,
        'servicePackage': boughtFromUs ? servicePackageController.text.trim() : null,
        'remainingServices': boughtFromUs ? int.tryParse(remainingServicesController.text.trim()) ?? 0 : null,
        'preferredDate': Timestamp.fromDate(preferredDate),
        'notes': notesController.text.trim(),
        'status': 'Pending',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        showMessage('Service request submitted successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage('Failed to submit service request. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Book Service Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Book service for your two-wheeler. You can request service even if the vehicle was not purchased from us.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: brandController,
              decoration: const InputDecoration(labelText: 'Vehicle Brand'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: 'Vehicle Model'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: variantController,
              decoration: const InputDecoration(labelText: 'Variant'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: registrationController,
              decoration: const InputDecoration(labelText: 'Registration Number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: serviceType,
              items: const [
                DropdownMenuItem(value: 'Regular Service', child: Text('Regular Service')),
                DropdownMenuItem(value: 'Repair', child: Text('Repair')),
                DropdownMenuItem(value: 'Renew Service', child: Text('Renew Service')),
                DropdownMenuItem(value: 'Inspection', child: Text('Inspection')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => serviceType = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Service Type'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Bought vehicle from JitenAuto?'),
              value: boughtFromUs,
              onChanged: (value) => setState(() => boughtFromUs = value),
            ),
            if (boughtFromUs) ...[
              TextField(
                controller: servicePackageController,
                decoration: const InputDecoration(labelText: 'Service Package (e.g. 5 services)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remainingServicesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Left Services'),
              ),
              const SizedBox(height: 12),
            ],
            InkWell(
              onTap: pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Preferred Service Date'),
                child: Text(preferredDate.toString().split(' ')[0]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional Instructions',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : saveServiceRequest,
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit Service Request'),
            ),
          ],
        ),
      ),
    );
  }
}
