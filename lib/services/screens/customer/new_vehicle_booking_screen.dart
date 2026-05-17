import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewVehicleBookingScreen extends StatefulWidget {
  const NewVehicleBookingScreen({super.key});

  @override
  State<NewVehicleBookingScreen> createState() =>
      _NewVehicleBookingScreenState();
}

class _NewVehicleBookingScreenState
    extends State<NewVehicleBookingScreen> {
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final variantController = TextEditingController();
  final priceController = TextEditingController();
  final notesController = TextEditingController();

  bool loading = false;
  bool brandsLoading = true;

  String? selectedBrand;
  String? selectedModel;
  String? selectedVariant;

  List<String> brands = [];
  List<String> models = [];
  List<Map<String, dynamic>> variants = [];

  @override
  void initState() {
    super.initState();
    fetchBrands();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchBrands() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('Brand').get();

      setState(() {
        brands = snapshot.docs
            .map((doc) => doc['Name'].toString())
            .toList();

        brandsLoading = false;
      });
    } catch (e) {
      brandsLoading = false;
      showMessage("Failed to load brands");
    }
  }

  Future<void> fetchModels(String brand) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Model')
        .where('ParentBrand', isEqualTo: brand)
        .get();

    setState(() {
      models = snapshot.docs
          .map((doc) => doc['Name'].toString())
          .toList();

      selectedModel = null;
      selectedVariant = null;
      variants = [];

      modelController.clear();
      variantController.clear();
      priceController.clear();
    });
  }

  Future<void> fetchVariants(String model) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Variant')
        .where('ParentModel', isEqualTo: model)
        .get();

    setState(() {
      variants = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      selectedVariant = null;

      variantController.clear();
      priceController.clear();
    });
  }

  Future<void> saveBooking() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (selectedBrand == null) {
      showMessage('Please select vehicle brand.');
      return;
    }

    if (selectedModel == null) {
      showMessage('Please select vehicle model.');
      return;
    }

    if (selectedVariant == null) {
      showMessage('Please select vehicle variant.');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('vehicleBookings')
          .add({
        'userId': user.uid,
        'customerEmail': user.email,
        'brand': brandController.text.trim(),
        'model': modelController.text.trim(),
        'variant': variantController.text.trim(),
        'price': priceController.text.trim().isEmpty
            ? 'Not Specified'
            : priceController.text.trim(),
        'notes': notesController.text.trim(),
        'status': 'Pending',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        showMessage(
            'Vehicle booking request submitted successfully.');

        Navigator.pop(context);
      }
    } catch (e) {
      showMessage('Failed to submit booking.');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Vehicle Booking"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            DropdownButtonFormField<String>(
              value: selectedBrand,
              hint: brandsLoading
                  ? const Text("Loading brands...")
                  : const Text("Select Brand"),
              items: brands
                  .map(
                    (brand) => DropdownMenuItem(
                      value: brand,
                      child: Text(brand),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedBrand = value;
                  brandController.text = value ?? '';
                });

                if (value != null) {
                  fetchModels(value);
                }
              },
              decoration: const InputDecoration(
                labelText: "Vehicle Brand",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedModel,
              hint: const Text("Select Model"),
              items: models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text(model),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedModel = value;
                  modelController.text = value ?? '';
                });

                if (value != null) {
                  fetchVariants(value);
                }
              },
              decoration: const InputDecoration(
                labelText: "Vehicle Model",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedVariant,
              hint: const Text("Select Variant"),
              items: variants.map((variant) {
                return DropdownMenuItem<String>(
                  value: variant['Name'].toString(),
                  child: Text(variant['Name'].toString()),
                );
              }).toList(),
              onChanged: (value) {
                final selected = variants.firstWhere(
                  (v) => v['Name'] == value,
                );

                setState(() {
                  selectedVariant = value;

                  variantController.text = value ?? '';

                  priceController.text =
                      selected['Price']?.toString() ?? '';
                });
              },
              decoration: const InputDecoration(
                labelText: "Variant",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: "Expected Budget / Price",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Additional Notes",
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: loading ? null : saveBooking,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Submit Booking Request"),
            ),
          ],
        ),
      ),
    );
  }
}