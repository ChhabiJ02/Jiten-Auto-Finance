import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../vehicle_model_lookup.dart';

class NewVehicleBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicle;
  final bool isAddingToInquiry;
  final Function(Map<String, dynamic>)? onVehicleSelected;

  const NewVehicleBookingScreen({
    super.key,
    this.vehicle,
    this.isAddingToInquiry = false,
    this.onVehicleSelected,
  });

  @override
  State<NewVehicleBookingScreen> createState() =>
      _NewVehicleBookingScreenState();
}

class _NewVehicleBookingScreenState extends State<NewVehicleBookingScreen> {
  final brandController = TextEditingController();

  final modelController = TextEditingController();

  final variantController = TextEditingController();

  final showroomPriceController = TextEditingController();

  final expectedPriceController = TextEditingController();

  final notesController = TextEditingController();

  bool loading = false;
  bool brandsLoading = true;

  String? selectedBrand;
  String? selectedModel;
  String? selectedVehiclePhotoUrl;
  List<String> selectedVehiclePhotoUrls = [];
  String? selectedVehicleId;

  List<String> brands = [];
  List<String> models = [];

  @override
  void initState() {
    super.initState();

    fetchBrands();

    // Vehicle passed from Book Now
    if (widget.vehicle != null) {
      final vehicle = widget.vehicle!;

      selectedBrand = vehicle['brand'];

      selectedModel = vehicle['model'];

      brandController.text = vehicle['brand']?.toString() ?? '';

      modelController.text = vehicle['model']?.toString() ?? '';

      showroomPriceController.text = vehicle['price']?.toString() ?? '';

      final vehiclePhotos =
          (vehicle['vehiclePhotoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          (vehicle['photos'] as List<dynamic>?)?.whereType<String>().toList() ??
          [];

      selectedVehiclePhotoUrls = vehiclePhotos;
      selectedVehiclePhotoUrl =
          vehicle['vehiclePhotoUrl']?.toString() ??
          (vehiclePhotos.isNotEmpty ? vehiclePhotos.first : null);
      selectedVehicleId = vehicle['vehicleId']?.toString();

      fetchModels(vehicle['brand']).then((_) {
        _loadSelectedModelDetails(
          brand: vehicle['brand']?.toString() ?? '',
          model: vehicle['model']?.toString() ?? '',
        );
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchBrands() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Brand')
          .get();

      setState(() {
        brands = snapshot.docs.map((doc) => doc['Name'].toString()).toList();

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
      models = snapshot.docs.map((doc) => doc['Name'].toString()).toList();

      // ONLY reset if manually selecting
      if (widget.vehicle == null) {
        selectedModel = null;

        modelController.clear();
        variantController.clear();
        showroomPriceController.clear();
        selectedVehiclePhotoUrl = null;
        selectedVehiclePhotoUrls = [];
        selectedVehicleId = null;
      }
    });
  }

  Future<void> _loadSelectedModelDetails({
    required String brand,
    required String model,
  }) async {
    final details = await fetchVehicleModelLookupData(
      firestore: FirebaseFirestore.instance,
      brand: brand,
      model: model,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      showroomPriceController.text = details.price.isNotEmpty
          ? details.price
          : showroomPriceController.text;
      selectedVehiclePhotoUrl =
          details.primaryPhotoUrl ?? selectedVehiclePhotoUrl;
      selectedVehiclePhotoUrls = details.photoUrls.isNotEmpty
          ? details.photoUrls
          : selectedVehiclePhotoUrls;
      selectedVehicleId = details.vehicleId ?? selectedVehicleId;
      variantController.clear();
    });
  }

  Future<void> saveBooking() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (selectedBrand == null) {
      showMessage('Select brand');

      return;
    }

    if (selectedModel == null) {
      showMessage('Select model');

      return;
    }

    // If adding to inquiry, return the vehicle data
    if (widget.isAddingToInquiry) {
      final vehicleData = {
        'brand': brandController.text.trim(),
        'model': modelController.text.trim(),
        'variant': '',
        'price': showroomPriceController.text.trim(),
        'expectedPrice': expectedPriceController.text.trim(),
        'notes': notesController.text.trim(),
        'vehicleId': selectedVehicleId,
        'vehiclePhotoUrl': selectedVehiclePhotoUrl,
        'vehiclePhotoUrls': selectedVehiclePhotoUrls,
      };

      if (widget.onVehicleSelected != null) {
        widget.onVehicleSelected!(vehicleData);
      }

      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // FETCH CUSTOMER INFO
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final customerName = userData['name']?.toString() ?? 'Customer';

      final customerPhone = userData['phone']?.toString() ?? '';

      final customerAddress = userData['address']?.toString() ?? '';

      await FirebaseFirestore.instance.collection('inquiries').add({
        // CUSTOMER
        'name': customerName,

        'phone': customerPhone,

        'address': customerAddress,

        'customerId': user.uid,

        'customerEmail': user.email,

        // VEHICLE
        'brand': brandController.text.trim(),

        'model': modelController.text.trim(),

        'variant': '',

        'price': showroomPriceController.text.trim(),

        'vehicleId': selectedVehicleId,

        'vehiclePhotoUrl': selectedVehiclePhotoUrl,

        'vehiclePhotoUrls': selectedVehiclePhotoUrls,

        'expectedPrice': expectedPriceController.text.trim(),

        // NOTES
        'notes': notesController.text.trim(),

        // LEAD SYSTEM
        'staffId': null,
        'assignedTo': null,

        'acceptedBy': null,
        'acceptedByName': null,

        'isLocked': false,

        // STATUS
        'status': 'New Inquiry',

        // EXTRA
        'createdByCustomer': true,

        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        showMessage('Booking request submitted successfully');

        Navigator.pop(context);
      }
    } catch (e) {
      showMessage('Failed to submit booking');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAddingToInquiry ? "Add Vehicle" : "Vehicle Booking",
        ),
        leading: widget.isAddingToInquiry
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // BRAND
            DropdownButtonFormField<String>(
              value: selectedBrand,

              decoration: fieldDecoration("Vehicle Brand"),

              items: brands
                  .map(
                    (brand) =>
                        DropdownMenuItem(value: brand, child: Text(brand)),
                  )
                  .toList(),

              onChanged: widget.vehicle != null
                  ? null
                  : (value) {
                      setState(() {
                        selectedBrand = value;

                        brandController.text = value ?? '';
                      });

                      if (value != null) {
                        fetchModels(value);
                      }
                    },
            ),

            const SizedBox(height: 14),

            // MODEL
            DropdownButtonFormField<String>(
              value: selectedModel,

              decoration: fieldDecoration("Vehicle Model"),

              items: models
                  .map(
                    (model) =>
                        DropdownMenuItem(value: model, child: Text(model)),
                  )
                  .toList(),

              onChanged: widget.vehicle != null
                  ? null
                  : (value) {
                      setState(() {
                        selectedModel = value;

                        modelController.text = value ?? '';
                        variantController.clear();
                        showroomPriceController.clear();
                        selectedVehiclePhotoUrl = null;
                        selectedVehiclePhotoUrls = [];
                        selectedVehicleId = null;
                      });

                      if (value != null) {
                        _loadSelectedModelDetails(
                          brand: selectedBrand ?? '',
                          model: value,
                        );
                      }
                    },
            ),

            const SizedBox(height: 14),

            if (selectedVehiclePhotoUrl != null &&
                selectedVehiclePhotoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  selectedVehiclePhotoUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Unable to load vehicle photo'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // SHOWROOM PRICE
            TextField(
              controller: showroomPriceController,

              readOnly: true,

              decoration: fieldDecoration("Showroom Price"),
            ),

            const SizedBox(height: 14),

            // EXPECTED PRICE
            TextField(
              controller: expectedPriceController,

              keyboardType: TextInputType.number,

              decoration: fieldDecoration("Expected Price"),
            ),

            const SizedBox(height: 14),

            // NOTES
            TextField(
              controller: notesController,

              maxLines: 4,

              decoration: fieldDecoration("Additional Notes"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: loading ? null : saveBooking,

                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),

                child: loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.isAddingToInquiry
                            ? "Add This Vehicle"
                            : "Submit Booking Request",

                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
