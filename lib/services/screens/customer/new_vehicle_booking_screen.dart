import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewVehicleBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicle;

  const NewVehicleBookingScreen({
    super.key,
    this.vehicle,
  });

  @override
  State<NewVehicleBookingScreen> createState() =>
      _NewVehicleBookingScreenState();
}

class _NewVehicleBookingScreenState
    extends State<NewVehicleBookingScreen> {

  final brandController =
      TextEditingController();

  final modelController =
      TextEditingController();

  final variantController =
      TextEditingController();

  final showroomPriceController =
      TextEditingController();

  final expectedPriceController =
      TextEditingController();

  final notesController =
      TextEditingController();

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

    // Vehicle passed from Book Now
    if (widget.vehicle != null) {

      final vehicle =
          widget.vehicle!;

      selectedBrand =
          vehicle['brand'];

      selectedModel =
          vehicle['model'];

      selectedVariant =
          vehicle['variant'];

      brandController.text =
          vehicle['brand']
                  ?.toString() ??
              '';

      modelController.text =
          vehicle['model']
                  ?.toString() ??
              '';

      variantController.text =
          vehicle['variant']
                  ?.toString() ??
              '';

      showroomPriceController.text =
          vehicle['price']
                  ?.toString() ??
              '';

      fetchModels(
        vehicle['brand'],
      ).then((_) {

        fetchVariants(
          vehicle['model'],
        );
      });
    }
  }

  void showMessage(String message) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> fetchBrands() async {

    try {

      final snapshot =
          await FirebaseFirestore
              .instance
              .collection('Brand')
              .get();

      setState(() {

        brands = snapshot.docs
            .map(
              (doc) => doc['Name']
                  .toString(),
            )
            .toList();

        brandsLoading = false;
      });

    } catch (e) {

      brandsLoading = false;

      showMessage(
        "Failed to load brands",
      );
    }
  }

  Future<void> fetchModels(
    String brand,
  ) async {

    final snapshot =
        await FirebaseFirestore
            .instance
            .collection('Model')
            .where(
              'ParentBrand',
              isEqualTo: brand,
            )
            .get();

    setState(() {

      models = snapshot.docs
          .map(
            (doc) => doc['Name']
                .toString(),
          )
          .toList();

      // ONLY reset if manually selecting
      if (widget.vehicle == null) {

        selectedModel = null;
        selectedVariant = null;

        modelController.clear();
        variantController.clear();

        showroomPriceController.clear();
      }
    });
  }

  Future<void> fetchVariants(
    String model,
  ) async {

    final snapshot =
        await FirebaseFirestore
            .instance
            .collection('Variant')
            .where(
              'ParentModel',
              isEqualTo: model,
            )
            .get();

    setState(() {

      variants = snapshot.docs
          .map(
            (doc) => doc.data(),
          )
          .toList();

      // ONLY reset if manual booking
      if (widget.vehicle == null) {

        selectedVariant = null;

        variantController.clear();

        showroomPriceController.clear();
      }
    });
  }

  Future<void> saveBooking() async {

    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) return;

    if (selectedBrand == null) {

      showMessage(
        'Select brand',
      );

      return;
    }

    if (selectedModel == null) {

      showMessage(
        'Select model',
      );

      return;
    }

    if (selectedVariant == null) {

      showMessage(
        'Select variant',
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {

      // FETCH CUSTOMER INFO
      final userDoc =
          await FirebaseFirestore
              .instance
              .collection('users')
              .doc(user.uid)
              .get();

      final userData =
          userDoc.data() ?? {};

      final customerName =
          userData['name']
                  ?.toString() ??
              'Customer';

      final customerPhone =
          userData['phone']
                  ?.toString() ??
              '';

      final customerAddress =
          userData['address']
                  ?.toString() ??
              '';

      await FirebaseFirestore
          .instance
          .collection('inquiries')
          .add({

        // CUSTOMER
        'name': customerName,

        'phone': customerPhone,

        'address':
            customerAddress,

        'customerId':
            user.uid,

        'customerEmail':
            user.email,

        // VEHICLE
        'brand':
            brandController.text
                .trim(),

        'model':
            modelController.text
                .trim(),

        'variant':
            variantController.text
                .trim(),

        'price':
            showroomPriceController
                .text
                .trim(),

        'expectedPrice':
            expectedPriceController
                .text
                .trim(),

        // NOTES
        'notes':
            notesController.text
                .trim(),

        // LEAD SYSTEM
        'staffId': null,
        'assignedTo': null,

        'acceptedBy': null,
        'acceptedByName': null,

        'isLocked': false,

        // STATUS
        'status':
            'New Inquiry',

        // EXTRA
        'createdByCustomer':
            true,

        'createdAt':
            Timestamp.now(),
      });

      if (mounted) {

        showMessage(
          'Booking request submitted successfully',
        );

        Navigator.pop(context);
      }

    } catch (e) {

      showMessage(
        'Failed to submit booking',
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }

  InputDecoration fieldDecoration(
      String label) {

    return InputDecoration(

      labelText: label,

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Vehicle Booking",
        ),
      ),

      body: SingleChildScrollView(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          children: [

            // BRAND
            DropdownButtonFormField<
                String>(
              value: selectedBrand,

              decoration:
                  fieldDecoration(
                "Vehicle Brand",
              ),

              items: brands
                  .map(
                    (brand) =>
                        DropdownMenuItem(
                      value: brand,
                      child:
                          Text(brand),
                    ),
                  )
                  .toList(),

              onChanged:
                  widget.vehicle !=
                          null
                      ? null
                      : (value) {

                          setState(() {

                            selectedBrand =
                                value;

                            brandController
                                    .text =
                                value ??
                                    '';
                          });

                          if (value !=
                              null) {

                            fetchModels(
                              value,
                            );
                          }
                        },
            ),

            const SizedBox(
              height: 14,
            ),

            // MODEL
            DropdownButtonFormField<
                String>(
              value: selectedModel,

              decoration:
                  fieldDecoration(
                "Vehicle Model",
              ),

              items: models
                  .map(
                    (model) =>
                        DropdownMenuItem(
                      value: model,
                      child:
                          Text(model),
                    ),
                  )
                  .toList(),

              onChanged:
                  widget.vehicle !=
                          null
                      ? null
                      : (value) {

                          setState(() {

                            selectedModel =
                                value;

                            modelController
                                    .text =
                                value ??
                                    '';
                          });

                          if (value !=
                              null) {

                            fetchVariants(
                              value,
                            );
                          }
                        },
            ),

            const SizedBox(
              height: 14,
            ),

            // VARIANT
            DropdownButtonFormField<
                String>(
              value: selectedVariant,

              decoration:
                  fieldDecoration(
                "Vehicle Variant",
              ),

              items: variants
                  .map((variant) {

                return DropdownMenuItem<
                    String>(

                  value:
                      variant['Name']
                          .toString(),

                  child: Text(
                    variant['Name']
                        .toString(),
                  ),
                );
              }).toList(),

              onChanged:
                  widget.vehicle !=
                          null
                      ? null
                      : (value) {

                          final selected =
                              variants
                                  .firstWhere(
                            (v) =>
                                v['Name'] ==
                                value,
                          );

                          setState(() {

                            selectedVariant =
                                value;

                            variantController
                                    .text =
                                value ??
                                    '';

                            showroomPriceController
                                    .text =
                                selected['Price']
                                        ?.toString() ??
                                    '';
                          });
                        },
            ),

            const SizedBox(
              height: 14,
            ),

            // SHOWROOM PRICE
            TextField(
              controller:
                  showroomPriceController,

              readOnly: true,

              decoration:
                  fieldDecoration(
                "Showroom Price",
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // EXPECTED PRICE
            TextField(
              controller:
                  expectedPriceController,

              keyboardType:
                  TextInputType.number,

              decoration:
                  fieldDecoration(
                "Expected Price",
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // NOTES
            TextField(
              controller:
                  notesController,

              maxLines: 4,

              decoration:
                  fieldDecoration(
                "Additional Notes",
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(

                onPressed:
                    loading
                        ? null
                        : saveBooking,

                style:
                    ElevatedButton
                        .styleFrom(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 16,
                  ),
                ),

                child: loading

                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child:
                            CircularProgressIndicator(
                          color:
                              Colors
                                  .white,
                          strokeWidth:
                              2,
                        ),
                      )

                    : const Text(
                        "Submit Booking Request",

                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
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