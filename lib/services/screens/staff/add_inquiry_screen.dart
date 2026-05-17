import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Model for a single vehicle quotation block ──────────────
class VehicleQuotation {
  String? selectedBrand;
  String? selectedModel;
  String? selectedVariant;
  List<String> brands = [];
  List<String> models = [];
  List<Map<String, dynamic>> variants = [];
  bool brandsLoading = true;
  String? selectedVariantPhotoUrl;
  List<String> selectedVariantPhotoUrls = [];
  String? selectedVehicleId;
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController variantController = TextEditingController();
  final TextEditingController onRoadPriceController = TextEditingController();
  final TextEditingController offerPriceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController otherController = TextEditingController();

  void dispose() {
    brandController.dispose();
    modelController.dispose();
    variantController.dispose();
    onRoadPriceController.dispose();
    offerPriceController.dispose();
    descriptionController.dispose();
    otherController.dispose();
  }
}

class AddInquiryScreen extends StatefulWidget {
  const AddInquiryScreen({super.key});

  @override
  State<AddInquiryScreen> createState() => _AddInquiryScreenState();
}

class _AddInquiryScreenState extends State<AddInquiryScreen> {
  static const _platform = MethodChannel('whatsapp_pdf_share');

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final referenceNameController = TextEditingController();
  final referencePhoneController = TextEditingController();

  // Exchange vehicle controllers
  final exchangeBrandModelController = TextEditingController();
  final exchangeRegController = TextEditingController();
  final exchangeExpectedPriceController = TextEditingController();
  final exchangeOfferPriceController = TextEditingController();

  String paymentType = 'Loan';
  DateTime selectedDate = DateTime.now();
  DateTime? followUpDate;

  bool loading = false;
  bool inquiryAlreadySaved = false;

  // Eagerness
  String? selectedEagerness;

  // Source
  String? selectedSource;
  final List<String> sourceOptions = [
    'Google',
    'Facebook / Instagram',
    'Sticker',
    'BikeWale',
    'Just Dial',
    'Walking',
    'Reference',
  ];

  // Exchange
  String exchangeOption = 'No';

  // Multiple vehicle quotations
  final List<VehicleQuotation> quotations = [];

  @override
  void initState() {
    super.initState();
    _addQuotation();
  }

  void _addQuotation() {
    final q = VehicleQuotation();
    quotations.add(q);
    _fetchBrandsForQuotation(q);
    if (mounted) setState(() {});
  }

  Future<void> _fetchBrandsForQuotation(VehicleQuotation q) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('Brand').get();
      if (mounted) {
        setState(() {
          q.brands =
              snapshot.docs.map((doc) => doc['Name'].toString()).toList();
          q.brandsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => q.brandsLoading = false);
    }
  }

  Future<void> _fetchModels(VehicleQuotation q, String brand) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Model')
        .where('ParentBrand', isEqualTo: brand)
        .get();
    if (mounted) {
      setState(() {
        q.models =
            snapshot.docs.map((doc) => doc['Name'].toString()).toList();
        q.selectedModel = null;
        q.selectedVariant = null;
        q.variants = [];
        q.modelController.clear();
        q.variantController.clear();
        q.onRoadPriceController.clear();
        q.selectedVariantPhotoUrl = null;
        q.selectedVariantPhotoUrls = [];
        q.selectedVehicleId = null;
      });
    }
  }

  Future<void> _fetchVariants(VehicleQuotation q, String model) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Variant')
        .where('ParentModel', isEqualTo: model)
        .get();

    final fetchedVariants = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final variantData = Map<String, dynamic>.from(doc.data());
      final variantName = (variantData['Name'] ?? '').toString();
      final photoUrls = <String>[];
      final docId =
          (variantData['vehicleImagesDocId'] ?? '').toString().trim();

      try {
        QuerySnapshot<Map<String, dynamic>>? imagesSnap;
        if (docId.isNotEmpty) {
          imagesSnap = await FirebaseFirestore.instance
              .collection('VehicleImages')
              .doc(docId)
              .collection('images')
              .get();
        }
        if (imagesSnap == null || imagesSnap.docs.isEmpty) {
          final imageSearch = await FirebaseFirestore.instance
              .collection('VehicleImages')
              .where('name', isEqualTo: variantName)
              .limit(1)
              .get();
          if (imageSearch.docs.isNotEmpty) {
            imagesSnap = await imageSearch.docs.first.reference
                .collection('images')
                .get();
          }
        }
        if (imagesSnap == null || imagesSnap.docs.isEmpty) {
          imagesSnap = await FirebaseFirestore.instance
              .collection('VehicleImages')
              .doc(variantName)
              .collection('images')
              .get();
        }
        for (final imageDoc in imagesSnap.docs) {
          final url = imageDoc.data()['url']?.toString();
          if (url != null && url.isNotEmpty && !photoUrls.contains(url)) {
            photoUrls.add(url);
          }
        }
      } catch (e) {
        debugPrint("Error fetching images for $variantName: $e");
      }

      final fallbackUrl = variantData['photoUrl']?.toString();
      if (photoUrls.isEmpty &&
          fallbackUrl != null &&
          fallbackUrl.isNotEmpty) {
        photoUrls.add(fallbackUrl);
      }

      variantData['photoUrls'] = photoUrls;
      variantData['photoUrl'] =
          photoUrls.isNotEmpty ? photoUrls.first : null;
      fetchedVariants.add(variantData);
    }

    if (mounted) {
      setState(() {
        q.variants = fetchedVariants;
        q.selectedVariant = null;
        q.variantController.clear();
        q.onRoadPriceController.clear();
        q.selectedVariantPhotoUrl = null;
        q.selectedVariantPhotoUrls = [];
        q.selectedVehicleId = null;
      });
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> saveInquiry() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      showMessage("Please enter customer name.");
      return false;
    }
    if (name.length < 3) {
      showMessage("Name must be at least 3 characters.");
      return false;
    }
    if (phone.isEmpty) {
      showMessage("Please enter phone number.");
      return false;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      showMessage("Enter valid 10-digit phone number.");
      return false;
    }

    final q = quotations.first;
    if (q.selectedBrand == null) {
      showMessage("Please select vehicle brand.");
      return false;
    }
    if (q.selectedModel == null) {
      showMessage("Please select vehicle model.");
      return false;
    }
    if (q.selectedVariant == null) {
      showMessage("Please select vehicle variant.");
      return false;
    }
    final price = q.onRoadPriceController.text.trim();
    if (price.isEmpty) {
      showMessage("Please enter on road price.");
      return false;
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) {
      showMessage("Enter valid price.");
      return false;
    }
    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue < 10000) {
      showMessage("Price must be at least 5 digits.");
      return false;
    }
    if (selectedSource == null) {
      showMessage("Please select a source.");
      return false;
    }
    if (selectedSource == 'Reference' &&
        referenceNameController.text.trim().isEmpty) {
      showMessage("Please enter reference person's name.");
      return false;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage("User not logged in.");
        return false;
      }

      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('inquiryCounter');
      final counterSnapshot = await counterRef.get();
      final currentNumber =
          counterSnapshot.exists ? counterSnapshot['current'] ?? 0 : 0;
      final newInquiryNumber = currentNumber + 1;
      await counterRef.set({'current': newInquiryNumber});

      final additionalQuotations = quotations.skip(1).map((aq) {
        return {
          'brand': aq.brandController.text.trim(),
          'model': aq.modelController.text.trim(),
          'variant': aq.variantController.text.trim(),
          'onRoadPrice': aq.onRoadPriceController.text.trim(),
          'offerPrice': aq.offerPriceController.text.trim(),
          'description': aq.descriptionController.text.trim(),
          'otherDescription': aq.otherController.text.trim(),
          'vehiclePhotoUrl': aq.selectedVariantPhotoUrl,
          'vehiclePhotoUrls': aq.selectedVariantPhotoUrls,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('inquiries').add({
        'inquiryNumber': newInquiryNumber,
        'name': name,
        'phone': phone,
        // Primary vehicle
        'brand': q.brandController.text.trim(),
        'model': q.modelController.text.trim(),
        'variant': q.variantController.text.trim(),
        'vehicleId': q.selectedVehicleId,
        'vehiclePhotoUrl': q.selectedVariantPhotoUrl,
        'vehiclePhotoUrls': q.selectedVariantPhotoUrls,
        'price': q.onRoadPriceController.text.trim(),
        'offerPrice': q.offerPriceController.text.trim(),
        'description': q.descriptionController.text.trim(),
        'otherDescription': q.otherController.text.trim(),
        if (additionalQuotations.isNotEmpty)
          'additionalQuotations': additionalQuotations,
        // Source
        'source': selectedSource,
        if (selectedSource == 'Reference') ...{
          'referenceName': referenceNameController.text.trim(),
          'referencePhone': referencePhoneController.text.trim(),
        },
        // Payment & eagerness
        'paymentType': paymentType,
        'eagerness': selectedEagerness,
        // Exchange
        'exchangeVehicle': exchangeOption == 'Yes',
        if (exchangeOption == 'Yes') ...{
          'exchangeBrandModel': exchangeBrandModelController.text.trim(),
          'exchangeRegNumber': exchangeRegController.text.trim(),
          'exchangeExpectedPrice':
              exchangeExpectedPriceController.text.trim(),
          'exchangeOfferPrice': exchangeOfferPriceController.text.trim(),
        },
        'date': selectedDate,
        'staffId': user.uid,
        'assignedTo': user.uid,
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'status': 'New Inquiry',
        if (followUpDate != null)
          'nextFollowUp': Timestamp.fromDate(followUpDate!),
      });

      return true;
    } catch (e) {
      debugPrint("SAVE INQUIRY ERROR: $e");
      showMessage("Failed to save inquiry: $e");
      return false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendPdfToWhatsApp() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final q = quotations.first;
    final price = q.onRoadPriceController.text.trim();

    if (name.isEmpty) {
      showMessage("Please enter customer name.");
      return;
    }
    if (phone.isEmpty) {
      showMessage("Please enter phone number.");
      return;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      showMessage("Enter valid 10-digit phone number.");
      return;
    }
    if (q.selectedBrand == null) {
      showMessage("Please select vehicle brand.");
      return;
    }
    if (q.selectedModel == null) {
      showMessage("Please select vehicle model.");
      return;
    }
    if (q.selectedVariant == null) {
      showMessage("Please select vehicle variant.");
      return;
    }
    if (price.isEmpty) {
      showMessage("Please enter on road price.");
      return;
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) {
      showMessage("Enter valid price.");
      return;
    }
    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue < 10000) {
      showMessage("Price must be at least 5 digits.");
      return;
    }

    setState(() => loading = true);

    try {
      await Permission.manageExternalStorage.request();
      await Permission.storage.request();

      if (!inquiryAlreadySaved) {
        final saved = await saveInquiry();
        if (!saved) {
          if (mounted) setState(() => loading = false);
          return;
        }
        inquiryAlreadySaved = true;
      }

      final vehicleImages = <pw.MemoryImage>[];
      final imageUrls = <String>[
        ...q.selectedVariantPhotoUrls,
        if (q.selectedVariantPhotoUrl != null &&
            q.selectedVariantPhotoUrl!.isNotEmpty &&
            !q.selectedVariantPhotoUrls
                .contains(q.selectedVariantPhotoUrl))
          q.selectedVariantPhotoUrl!,
      ];
      for (final url in imageUrls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty) {
            vehicleImages.add(pw.MemoryImage(response.bodyBytes));
          }
        } catch (_) {}
      }

      final brand = q.brandController.text.trim();
      final model = q.modelController.text.trim();
      final variant = q.variantController.text.trim();
      final offerPrice = q.offerPriceController.text.trim();
      final date = DateTime.now().toString().split(' ')[0];
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) {
            return pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 30, vertical: 28),
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF7B1F3F)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("JITEN AUTO",
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 30,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text("Vehicle Quotation",
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 16)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    color: PdfColor.fromInt(0xFFF7EEF1),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(18),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius:
                                  pw.BorderRadius.circular(18),
                            ),
                            child: pw.Column(
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Customer Details",
                                    style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromInt(
                                            0xFF7B1F3F))),
                                pw.SizedBox(height: 14),
                                pw.Text("Name: $name",
                                    style: const pw.TextStyle(
                                        fontSize: 14)),
                                pw.SizedBox(height: 6),
                                pw.Text("Phone: $phone",
                                    style: const pw.TextStyle(
                                        fontSize: 14)),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                    "Source: ${selectedSource ?? ''}",
                                    style: const pw.TextStyle(
                                        fontSize: 14)),
                                if (selectedSource == 'Reference') ...[
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                      "Reference: ${referenceNameController.text.trim()} ${referencePhoneController.text.trim()}",
                                      style: const pw.TextStyle(
                                          fontSize: 14)),
                                ],
                                pw.SizedBox(height: 6),
                                pw.Text("Date: $date",
                                    style: const pw.TextStyle(
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 20),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(18),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius:
                                  pw.BorderRadius.circular(18),
                            ),
                            child: pw.Column(
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Vehicle Details",
                                    style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromInt(
                                            0xFF7B1F3F))),
                                pw.SizedBox(height: 14),
                                pw.Text("Brand: $brand"),
                                pw.SizedBox(height: 6),
                                pw.Text("Model: $model"),
                                pw.SizedBox(height: 6),
                                pw.Text("Variant: $variant"),
                                if (vehicleImages.isNotEmpty)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                        top: 16),
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text("Available Colours",
                                            style: pw.TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    pw.FontWeight.bold,
                                                color: PdfColor.fromInt(
                                                    0xFF7B1F3F))),
                                        pw.SizedBox(height: 10),
                                        pw.Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: vehicleImages
                                              .map((img) =>
                                                  pw.Container(
                                                    width: 120,
                                                    height: 90,
                                                    decoration: pw.BoxDecoration(
                                                        borderRadius:
                                                            pw.BorderRadius.circular(
                                                                10)),
                                                    child: pw.ClipRRect(
                                                      horizontalRadius:
                                                          10,
                                                      verticalRadius: 10,
                                                      child: pw.Image(
                                                          img,
                                                          fit: pw.BoxFit
                                                              .cover),
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 22),
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF7B1F3F),
                              borderRadius:
                                  pw.BorderRadius.circular(20),
                            ),
                            child: pw.Column(
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("On Road Price",
                                    style: const pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 13)),
                                pw.SizedBox(height: 6),
                                pw.Text("Rs. $price",
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 26,
                                        fontWeight:
                                            pw.FontWeight.bold)),
                                if (offerPrice.isNotEmpty) ...[
                                  pw.SizedBox(height: 10),
                                  pw.Text("Offer Price",
                                      style: const pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 13)),
                                  pw.SizedBox(height: 6),
                                  pw.Text("Rs. $offerPrice",
                                      style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 22,
                                          fontWeight:
                                              pw.FontWeight.bold)),
                                ],
                              ],
                            ),
                          ),
                          pw.Spacer(),
                          pw.Center(
                            child: pw.Column(
                              children: [
                                pw.Text(
                                    "Thank you for choosing Jiten Auto",
                                    style: pw.TextStyle(
                                        color: PdfColor.fromInt(
                                            0xFF7B1F3F),
                                        fontSize: 14,
                                        fontWeight:
                                            pw.FontWeight.bold)),
                                pw.SizedBox(height: 8),
                                pw.Text("We appreciate your inquiry.",
                                    style: const pw.TextStyle(
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final cacheDir = await getTemporaryDirectory();
      final filePath = '${cacheDir.path}/quotation.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      final message =
          "Hello $name,\n\nPlease find attached the quotation for the vehicle you inquired about.\n\nRegards,\nJiten Auto Team";

      await _platform.invokeMethod('shareToWhatsApp', {
        'filePath': filePath,
        'phone': phone,
        'message': message,
      });

      if (mounted) {
        showMessage("Quotation sent successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      showMessage('Failed to send PDF: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    referenceNameController.dispose();
    referencePhoneController.dispose();
    exchangeBrandModelController.dispose();
    exchangeRegController.dispose();
    exchangeExpectedPriceController.dispose();
    exchangeOfferPriceController.dispose();
    for (final q in quotations) {
      q.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon,
      {bool disabled = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: disabled ? Colors.grey.shade200 : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildQuotationBlock(
      BuildContext context, VehicleQuotation q, int index) {
    final theme = Theme.of(context);
    final isFirst = index == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Divider(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    thickness: 1.5),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Vehicle ${index + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    thickness: 1.5),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () =>
                    setState(() => quotations.removeAt(index)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Brand
        DropdownButtonFormField<String>(
          value: q.selectedBrand,
          isExpanded: true,
          hint: q.brandsLoading
              ? const Text("Loading brands...")
              : const Text("Select Brand"),
          items: q.brands
              .map((b) =>
                  DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: q.brands.isEmpty
              ? null
              : (value) {
                  setState(() {
                    q.selectedBrand = value;
                    q.brandController.text = value ?? '';
                  });
                  if (value != null) _fetchModels(q, value);
                },
          decoration:
              _dec('Vehicle Brand', Icons.directions_car_outlined),
        ),
        const SizedBox(height: 16),

        // Model
        DropdownButtonFormField<String>(
          key: ValueKey('model_${index}_${q.selectedBrand}'),
          value: q.selectedModel,
          isExpanded: true,
          hint: const Text("Select Model"),
          disabledHint: const Text("Select a brand first"),
          items: q.models
              .map((m) =>
                  DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: q.selectedBrand == null || q.models.isEmpty
              ? null
              : (value) {
                  setState(() {
                    q.selectedModel = value;
                    q.modelController.text = value ?? '';
                  });
                  if (value != null) _fetchVariants(q, value);
                },
          decoration: _dec(
            'Model',
            Icons.precision_manufacturing,
            disabled: q.selectedBrand == null,
          ),
        ),
        const SizedBox(height: 16),

        // Variant
        DropdownButtonFormField<String>(
          key: ValueKey(
              'variant_${index}_${q.selectedBrand}_${q.selectedModel}'),
          value: q.selectedVariant,
          isExpanded: true,
          hint: const Text("Select Variant"),
          disabledHint: const Text("Select a model first"),
          items: q.variants
              .map((v) => DropdownMenuItem<String>(
                    value: v['Name']?.toString(),
                    child: Text(v['Name']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: q.selectedModel == null || q.variants.isEmpty
              ? null
              : (value) {
                  final selected = q.variants
                      .firstWhere((v) => v['Name'] == value);
                  setState(() {
                    q.selectedVariant = value;
                    q.selectedVariantPhotoUrl =
                        selected['photoUrl']?.toString();
                    q.selectedVariantPhotoUrls =
                        List<String>.from(
                            selected['photoUrls'] ?? const []);
                    q.variantController.text = value ?? '';
                    q.onRoadPriceController.text =
                        selected['Price']?.toString() ?? '';
                  });
                },
          decoration: _dec(
            'Variant',
            Icons.widgets_outlined,
            disabled: q.selectedModel == null,
          ),
        ),
        const SizedBox(height: 16),

        // Photo preview
        if (q.selectedVariantPhotoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              q.selectedVariantPhotoUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child:
                    const Text("Unable to load vehicle photo"),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Colour thumbnails
        if (q.selectedVariantPhotoUrls.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text("Available Colours",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: q.selectedVariantPhotoUrls.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    q.selectedVariantPhotoUrls[i],
                    width: 140,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 140,
                      height: 100,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text("Unavailable"),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // On Road Price
        TextField(
          controller: q.onRoadPriceController,
          keyboardType: TextInputType.number,
          decoration: _dec('On Road Price', Icons.currency_rupee),
        ),
        const SizedBox(height: 16),

        // Offer Price
        TextField(
          controller: q.offerPriceController,
          keyboardType: TextInputType.number,
          decoration: _dec(
              'Offer Price (optional)', Icons.local_offer_outlined),
        ),
        const SizedBox(height: 16),

        // Vehicle description
        TextField(
          controller: q.descriptionController,
          minLines: 1,
          maxLines: 5,
          decoration: _dec('Vehicle Description', Icons.info_outline),
        ),
        const SizedBox(height: 16),

        // Other description
        TextField(
          controller: q.otherController,
          minLines: 1,
          maxLines: 5,
          decoration:
              _dec('Other Description', Icons.description_outlined),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Add Inquiry")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.message_outlined,
                          color: theme.colorScheme.primary,
                          size: 40),
                    ),
                    const SizedBox(height: 18),
                    Text("New Inquiry",
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      "Capture the lead details and send a WhatsApp confirmation.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // ── Customer Name ────────────────────────
                    TextField(
                      controller: nameController,
                      decoration:
                          _dec('Customer Name', Icons.person_outline),
                    ),
                    const SizedBox(height: 16),

                    // ── Phone ────────────────────────────────
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          _dec('Phone Number', Icons.phone_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── Vehicle Quotation blocks ─────────────
                    for (int i = 0; i < quotations.length; i++)
                      _buildQuotationBlock(
                          context, quotations[i], i),

                    const SizedBox(height: 16),

                    // ── + Add Another Vehicle ────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label:
                            const Text('+ Add Another Vehicle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              theme.colorScheme.primary,
                          side: BorderSide(
                              color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _addQuotation,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ════════════════════════════════════════
                    // SOURCE, PAYMENT, EAGERNESS, EXCHANGE
                    // (appear after vehicle details)
                    // ════════════════════════════════════════

                    // ── Source ───────────────────────────────
                    DropdownButtonFormField<String>(
                      value: selectedSource,
                      isExpanded: true,
                      hint: const Text('Select Source'),
                      items: sourceOptions
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedSource = value),
                      decoration:
                          _dec('Source', Icons.source_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── Reference fields ─────────────────────
                    if (selectedSource == 'Reference') ...[
                      TextField(
                        controller: referenceNameController,
                        decoration: _dec(
                            "Reference Person's Name",
                            Icons.person_outline),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: referencePhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(
                            "Reference Person's Phone",
                            Icons.phone_outlined),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Payment Type ─────────────────────────
                    DropdownButtonFormField<String>(
                      value: paymentType,
                      items: const [
                        DropdownMenuItem(
                            value: 'Loan', child: Text('Loan')),
                        DropdownMenuItem(
                            value: 'Cash', child: Text('Cash')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => paymentType = value);
                        }
                      },
                      decoration: _dec(
                          'Payment Option', Icons.payment_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── Eagerness ────────────────────────────
                    DropdownButtonFormField<String>(
                      value: selectedEagerness,
                      isExpanded: true,
                      hint: const Text('Select Eagerness'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Hot',
                          child: Text('🔥  Hot'),
                        ),
                        DropdownMenuItem(
                          value: 'Warm',
                          child: Text('☀️  Warm'),
                        ),
                        DropdownMenuItem(
                          value: 'Cold',
                          child: Text('❄️  Cold'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedEagerness = value),
                      decoration: _dec('Eagerness',
                          Icons.local_fire_department_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── Exchange Vehicle ─────────────────────
                    DropdownButtonFormField<String>(
                      value: exchangeOption,
                      items: const [
                        DropdownMenuItem(
                            value: 'No',
                            child: Text('No Exchange')),
                        DropdownMenuItem(
                            value: 'Yes',
                            child:
                                Text('Yes, Exchange Vehicle')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => exchangeOption = value);
                        }
                      },
                      decoration: _dec('Exchange Vehicle?',
                          Icons.swap_horiz_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ── Exchange fields ──────────────────────
                    if (exchangeOption == 'Yes') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exchange Vehicle Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller:
                                  exchangeBrandModelController,
                              decoration: _dec('Brand / Model',
                                  Icons.directions_bike_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exchangeRegController,
                              decoration: _dec(
                                  'Registration Number',
                                  Icons.confirmation_number_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller:
                                  exchangeExpectedPriceController,
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                  "Customer's Expected Price",
                                  Icons.currency_rupee),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller:
                                  exchangeOfferPriceController,
                              keyboardType: TextInputType.number,
                              decoration: _dec('Our Offer Price',
                                  Icons.local_offer_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Follow-up date ───────────────────────
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: followUpDate ??
                              DateTime.now()
                                  .add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => followUpDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.calendar_today_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                followUpDate != null
                                    ? 'Follow-up: ${followUpDate!.toString().split(' ')[0]}'
                                    : 'Set follow-up date (optional)',
                                style: TextStyle(
                                  color: followUpDate != null
                                      ? Colors.black
                                      : Colors.black54,
                                ),
                              ),
                            ),
                            if (followUpDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(
                                    () => followUpDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Send PDF via WhatsApp ────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                            Icons.picture_as_pdf_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF7B1F3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        onPressed:
                            loading ? null : sendPdfToWhatsApp,
                        label: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Send PDF via WhatsApp",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}