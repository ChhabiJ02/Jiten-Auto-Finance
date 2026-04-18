import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewVehicleBookingScreen extends StatefulWidget {
  const NewVehicleBookingScreen({super.key});

  @override
  State<NewVehicleBookingScreen> createState() => _NewVehicleBookingScreenState();
}

class _NewVehicleBookingScreenState extends State<NewVehicleBookingScreen> {
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final variantController = TextEditingController();
  final priceController = TextEditingController();
  final notesController = TextEditingController();
  bool loading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();
    final price = priceController.text.trim();

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
      await FirebaseFirestore.instance.collection('vehicleBookings').add({
        'userId': user.uid,
        'customerEmail': user.email,
        'brand': brand,
        'model': model,
        'variant': variant,
        'price': price,
        'notes': notesController.text.trim(),
        'status': 'Pending',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        showMessage('Vehicle booking request submitted successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showMessage('Failed to submit booking. Please try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Vehicle Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Book your new vehicle request here. Our team will contact you with pricing and availability.',
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
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Expected Budget / Price'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : saveBooking,
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit Booking Request'),
            ),
          ],
        ),
      ),
    );
  }
}
