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
import '../../vehicle_model_lookup.dart';
import '../customer/new_vehicle_booking_screen.dart';

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

  final exchangeBrandModelController = TextEditingController();
  final exchangeRegController = TextEditingController();
  final exchangeExpectedPriceController = TextEditingController();
  final exchangeOfferPriceController = TextEditingController();
  String? selectedAssignedStaffId;
  List<Map<String, String>> staffList = [];

  String paymentType = 'Loan';
  DateTime selectedDate = DateTime.now();
  DateTime? followUpDate;

  bool loading = false;
  bool inquiryAlreadySaved = false;

  String? selectedEagerness;

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

  String exchangeOption = 'No';

  final List<VehicleQuotation> quotations = [];

  @override
  void initState() {
    super.initState();
    _addQuotation();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? data['email'] ?? 'Staff').toString(),
        };
      }).toList();

      if (mounted) setState(() => staffList = list);
    } catch (_) {}
  }

  void _addQuotation() {
    final q = VehicleQuotation();
    quotations.add(q);
    _fetchBrandsForQuotation(q);
    if (mounted) setState(() {});
  }

  Future<void> _addVehicleFromCatalog() async {
    final vehicleData = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => NewVehicleBookingScreen(
          isAddingToInquiry: true,
          onVehicleSelected: (data) {
            Navigator.pop(context, data);
          },
        ),
      ),
    );

    if (vehicleData != null && mounted) {
      final q = VehicleQuotation();
      quotations.add(q);

      // Pre-fill the quotation with the selected vehicle data
      q.brandController.text = vehicleData['brand'] ?? '';
      q.modelController.text = vehicleData['model'] ?? '';
      q.variantController.text = vehicleData['variant'] ?? '';
      q.onRoadPriceController.text = vehicleData['price'] ?? '';
      q.offerPriceController.text = vehicleData['expectedPrice'] ?? '';
      q.descriptionController.text = vehicleData['notes'] ?? '';

      q.selectedBrand = vehicleData['brand'];
      q.selectedModel = vehicleData['model'];
      q.selectedVariant = vehicleData['variant'];
      q.selectedVehicleId = vehicleData['vehicleId']?.toString();
      q.selectedVariantPhotoUrl = vehicleData['vehiclePhotoUrl']?.toString();
      q.selectedVariantPhotoUrls =
          (vehicleData['vehiclePhotoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [];

      // Fetch the models and details for the selected brand/model
      await _fetchBrandsForQuotation(q);
      await _fetchModels(q, vehicleData['brand'] ?? '');
      await _loadModelDetailsForQuotation(q, vehicleData['model'] ?? '');

      setState(() {});
    }
  }

  Future<void> _fetchBrandsForQuotation(VehicleQuotation q) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Brand')
          .get();
      if (mounted) {
        setState(() {
          q.brands = snapshot.docs
              .map((doc) => doc['Name'].toString())
              .toList();
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
        q.models = snapshot.docs.map((doc) => doc['Name'].toString()).toList();
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

  Future<void> _loadModelDetailsForQuotation(
    VehicleQuotation q,
    String model,
  ) async {
    final brand = q.selectedBrand?.trim() ?? '';

    if (brand.isEmpty || model.trim().isEmpty) {
      return;
    }

    final details = await fetchVehicleModelLookupData(
      firestore: FirebaseFirestore.instance,
      brand: brand,
      model: model,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      q.selectedVariant = null;
      q.variantController.clear();
      q.onRoadPriceController.text = details.price.isNotEmpty
          ? details.price
          : q.onRoadPriceController.text;
      q.selectedVariantPhotoUrl =
          details.primaryPhotoUrl ?? q.selectedVariantPhotoUrl;
      q.selectedVariantPhotoUrls = details.photoUrls.isNotEmpty
          ? details.photoUrls
          : q.selectedVariantPhotoUrls;
      q.selectedVehicleId = details.vehicleId ?? q.selectedVehicleId;
    });
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      final currentNumber = counterSnapshot.exists
          ? counterSnapshot['current'] ?? 0
          : 0;
      final newInquiryNumber = currentNumber + 1;
      await counterRef.set({'current': newInquiryNumber});

      final additionalQuotations = quotations.skip(1).map((aq) {
        return {
          'brand': aq.brandController.text.trim(),
          'model': aq.modelController.text.trim(),
          'variant': '',
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
        'brand': q.brandController.text.trim(),
        'model': q.modelController.text.trim(),
        'variant': '',
        'vehicleId': q.selectedVehicleId,
        'vehiclePhotoUrl': q.selectedVariantPhotoUrl,
        'vehiclePhotoUrls': q.selectedVariantPhotoUrls,
        'price': q.onRoadPriceController.text.trim(),
        'offerPrice': q.offerPriceController.text.trim(),
        'description': q.descriptionController.text.trim(),
        'otherDescription': q.otherController.text.trim(),
        if (additionalQuotations.isNotEmpty)
          'additionalQuotations': additionalQuotations,
        'source': selectedSource,
        if (selectedSource == 'Reference') ...{
          'referenceName': referenceNameController.text.trim(),
          'referencePhone': referencePhoneController.text.trim(),
        },
        'paymentType': paymentType,
        'eagerness': selectedEagerness,
        'exchangeVehicle': exchangeOption == 'Yes',
        if (exchangeOption == 'Yes') ...{
          'exchangeBrandModel': exchangeBrandModelController.text.trim(),
          'exchangeRegNumber': exchangeRegController.text.trim(),
          'exchangeExpectedPrice': exchangeExpectedPriceController.text.trim(),
          'exchangeOfferPrice': exchangeOfferPriceController.text.trim(),
        },
        'date': selectedDate,
        'createdBy': user.uid,
        if (selectedAssignedStaffId != null &&
            selectedAssignedStaffId!.isNotEmpty) ...{
          'staffId': selectedAssignedStaffId,
          'assignedTo': selectedAssignedStaffId,
        } else ...{
          'staffId': user.uid,
          'assignedTo': user.uid,
        },
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

  // ── PDF header widget (shared across all pages) ────────────
  pw.Widget _pdfHeader(String staffName) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1F3F)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, top: 8),
            child: pw.Text(
              'M. 8866797000',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'JITEN AUTO',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 34,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          if (staffName.isNotEmpty)
            pw.Center(
              child: pw.Text(
                'Staff: $staffName',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
              ),
            ),
          if (staffName.isNotEmpty) pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF4A0E24),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'MULTI BRAND 2 WH. SHOWROOM & WORKSHOP',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            color: PdfColor.fromInt(0xFF4A0E24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfAddressRow(
                  'Head Office :-',
                  'Sargam Complex, Opp. Bhulkabhavan School, Adajan.  M. 8866797019',
                ),
                pw.SizedBox(height: 5),
                _pdfAddressRow(
                  'Work Shop :-',
                  'Next to Shri Ram Petrol Pump A.M. Rd, Adajan.  M. 81605 08608',
                ),
                pw.SizedBox(height: 5),
                _pdfAddressRow(
                  'Branch :- 2',
                  'Between Ichchhapor Bus Station-2 & 3, Ichchhapor.  M. 98259 24999',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── FIX: use pw.Flexible instead of pw.Expanded ───────────
  pw.Widget _pdfAddressRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF7B1F3F),
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 6),
        // ✅ pw.Flexible with loose fit — does NOT require bounded width
        pw.SizedBox(
          width: 320,
          child: pw.Text(
            value,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
        ),
      ],
    );
  }

  // ── PDF footer with staff details ─────────────────────────
  pw.Widget _pdfFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7B1F3F)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Thank you for choosing Jiten Auto',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '-> Best Exchange Value Of Any Old Two Wheeler',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ── Single quotation page content ─────────────────────────
  pw.Widget _buildPdfQuotationContent({
    required String customerName,
    required String customerPhone,
    required String date,
    required String brand,
    required String model,
    required String variant,
    required String onRoadPrice,
    required String offerPrice,
    required List<pw.MemoryImage> vehicleImages,
    required int pageNumber,
    required int totalPages,
  }) {
    return pw.Container(
      width: double.infinity,
      color: PdfColor.fromInt(0xFFF7EEF1),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (totalPages > 1)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Option $pageNumber of $totalPages',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF7B1F3F),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          if (totalPages > 1) pw.SizedBox(height: 8),

          // ── Customer details ───────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(
                color: PdfColor.fromInt(0xFF7B1F3F),
                width: 1.5,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Customer Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF7B1F3F),
                  ),
                ),
                pw.SizedBox(height: 10),
                // ✅ No Expanded/Flexible in this Row — plain spaceBetween
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfDetailRow('Name', customerName),
                        pw.SizedBox(height: 4),
                        _pdfDetailRow('Mob', customerPhone),
                      ],
                    ),
                    _pdfDetailRow('Date', date),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // ── Vehicle details ────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 6, color: PdfColor.fromInt(0xFF7B1F3F)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Vehicle Details',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF7B1F3F),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _pdfDetailRow('Brand', brand),
                      pw.SizedBox(height: 4),
                      _pdfDetailRow('Model', model),
                      if (variant.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        _pdfDetailRow('Variant', variant),
                      ],
                      if (vehicleImages.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Text(
                          'Available Colours',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF7B1F3F),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: vehicleImages
                              .map(
                                (img) => pw.Container(
                                  width: 110,
                                  height: 80,
                                  decoration: pw.BoxDecoration(
                                    borderRadius: pw.BorderRadius.circular(8),
                                  ),
                                  child: pw.ClipRRect(
                                    horizontalRadius: 8,
                                    verticalRadius: 8,
                                    child: pw.Image(img, fit: pw.BoxFit.cover),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // ── Price block ────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF7B1F3F),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'On Road Price',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Rs. $onRoadPrice',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (offerPrice.isNotEmpty)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Offer Price',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. $offerPrice',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FIX: pw.Flexible instead of pw.Expanded ───────────────
  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 55,
          child: pw.Text(
            '$label :',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF7B1F3F),
            ),
          ),
        ),
        // ✅ KEY FIX: pw.Flexible with loose fit — no bounded width required
        pw.SizedBox(
          width: 180,
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
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

      final user = FirebaseAuth.instance.currentUser;
      String staffName = user?.displayName ?? '';

      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            if ((data['name'] ?? '').toString().isNotEmpty) {
              staffName = data['name'].toString();
            }
          }
        } catch (_) {}
      }

      final date = DateTime.now().toString().split(' ')[0];
      final pdf = pw.Document();
      final totalPages = quotations.length;

      for (int i = 0; i < quotations.length; i++) {
        final vq = quotations[i];

        final vehicleImages = <pw.MemoryImage>[];
        final imageUrls = <String>[
          ...vq.selectedVariantPhotoUrls,
          if (vq.selectedVariantPhotoUrl != null &&
              vq.selectedVariantPhotoUrl!.isNotEmpty &&
              !vq.selectedVariantPhotoUrls.contains(vq.selectedVariantPhotoUrl))
            vq.selectedVariantPhotoUrl!,
        ];
        for (final url in imageUrls) {
          try {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 15));
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              vehicleImages.add(pw.MemoryImage(response.bodyBytes));
            }
          } catch (_) {}
        }

        final brand = vq.brandController.text.trim();
        final model = vq.modelController.text.trim();
        final variant = vq.variantController.text.trim();
        final onRoadPrice = vq.onRoadPriceController.text.trim();
        final offerPrice = vq.offerPriceController.text.trim();
        final isFirstPage = i == 0;
        final isLastPage = i == totalPages - 1;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (context) {
              return pw.Column(
                mainAxisSize: pw.MainAxisSize.max,
                children: [
                  if (isFirstPage) _pdfHeader(staffName),
                  _buildPdfQuotationContent(
                    customerName: name,
                    customerPhone: phone,
                    date: date,
                    brand: brand,
                    model: model,
                    variant: variant,
                    onRoadPrice: onRoadPrice,
                    offerPrice: offerPrice,
                    vehicleImages: vehicleImages,
                    pageNumber: i + 1,
                    totalPages: totalPages,
                  ),
                  if (isLastPage) _pdfFooter(),
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final cacheDir = await getTemporaryDirectory();
      final filePath = '${cacheDir.path}/quotation.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      final message =
          "Hello $name,\n\nPlease find attached the vehicle quotation from Jiten Auto.\n\nRegards,\n$staffName\nJiten Auto";

      await _platform.invokeMethod('shareToWhatsApp', {
        'filePath': filePath,
        'phone': phone,
        'message': message,
      });

      if (mounted) {
        showMessage("Quotation sent successfully");
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('sendPdfToWhatsApp error:');
      debugPrint(st.toString());
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
    for (final vq in quotations) {
      vq.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {bool disabled = false}) {
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
    BuildContext context,
    VehicleQuotation q,
    int index,
  ) {
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
                child: Container(
                  height: 1.5,
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                child: Container(
                  height: 1.5,
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => setState(() => quotations.removeAt(index)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        DropdownButtonFormField<String>(
          value: q.selectedBrand,
          isExpanded: true,
          hint: q.brandsLoading
              ? const Text("Loading brands...")
              : const Text("Select Brand"),
          items: q.brands
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
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
          decoration: _dec('Vehicle Brand', Icons.directions_car_outlined),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          key: ValueKey('model_${index}_${q.selectedBrand}'),
          value: q.selectedModel,
          isExpanded: true,
          hint: const Text("Select Model"),
          disabledHint: const Text("Select a brand first"),
          items: q.models
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: q.selectedBrand == null || q.models.isEmpty
              ? null
              : (value) {
                  setState(() {
                    q.selectedModel = value;
                    q.modelController.text = value ?? '';
                    q.selectedVariant = null;
                    q.variantController.clear();
                    q.onRoadPriceController.clear();
                    q.selectedVariantPhotoUrl = null;
                    q.selectedVariantPhotoUrls = [];
                    q.selectedVehicleId = null;
                  });
                  if (value != null) {
                    _loadModelDetailsForQuotation(q, value);
                  }
                },
          decoration: _dec(
            'Model',
            Icons.precision_manufacturing,
            disabled: q.selectedBrand == null,
          ),
        ),
        const SizedBox(height: 16),

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
                child: const Text("Unable to load vehicle photo"),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (q.selectedVariantPhotoUrls.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Available Colours",
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
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

        TextField(
          controller: q.onRoadPriceController,
          readOnly: true,
          keyboardType: TextInputType.number,
          decoration: _dec('On Road Price', Icons.currency_rupee),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: q.offerPriceController,
          keyboardType: TextInputType.number,
          decoration: _dec(
            'Offer Price (optional)',
            Icons.local_offer_outlined,
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: q.descriptionController,
          minLines: 1,
          maxLines: 5,
          decoration: _dec('Vehicle Description', Icons.info_outline),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: q.otherController,
          minLines: 1,
          maxLines: 5,
          decoration: _dec('Other Description', Icons.description_outlined),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Capture the lead details and send a WhatsApp confirmation.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: nameController,
                      decoration: _dec('Customer Name', Icons.person_outline),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _dec('Phone Number', Icons.phone_outlined),
                    ),
                    const SizedBox(height: 16),

                    for (int i = 0; i < quotations.length; i++)
                      _buildQuotationBlock(context, quotations[i], i),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text(' Add Vehicle'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _addQuotation,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: selectedSource,
                      isExpanded: true,
                      hint: const Text('Select Source'),
                      items: sourceOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedSource = value),
                      decoration: _dec('Source', Icons.source_outlined),
                    ),
                    const SizedBox(height: 16),

                    if (selectedSource == 'Reference') ...[
                      TextField(
                        controller: referenceNameController,
                        decoration: _dec(
                          "Reference Person's Name",
                          Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: referencePhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(
                          "Reference Person's Phone",
                          Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                      decoration: _dec(
                        'Payment Option',
                        Icons.payment_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: selectedEagerness,
                      isExpanded: true,
                      hint: const Text('Select Eagerness'),
                      items: const [
                        DropdownMenuItem(value: 'Hot', child: Text('🔥  Hot')),
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
                      decoration: _dec(
                        'Eagerness',
                        Icons.local_fire_department_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: exchangeOption,
                      items: const [
                        DropdownMenuItem(
                          value: 'No',
                          child: Text('No Exchange'),
                        ),
                        DropdownMenuItem(
                          value: 'Yes',
                          child: Text('Yes, Exchange Vehicle'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => exchangeOption = value);
                        }
                      },
                      decoration: _dec(
                        'Exchange Vehicle?',
                        Icons.swap_horiz_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (staffList.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedAssignedStaffId,
                        isExpanded: true,
                        hint: const Text('Assign to staff (optional)'),
                        items: staffList
                            .map(
                              (s) => DropdownMenuItem(
                                value: s['id'],
                                child: Text(s['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedAssignedStaffId = v),
                        decoration: _dec(
                          'Assign Staff (optional)',
                          Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (exchangeOption == 'Yes') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              controller: exchangeBrandModelController,
                              decoration: _dec(
                                'Brand / Model',
                                Icons.directions_bike_outlined,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exchangeRegController,
                              decoration: _dec(
                                'Registration Number',
                                Icons.confirmation_number_outlined,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exchangeExpectedPriceController,
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                "Customer's Expected Price",
                                Icons.currency_rupee,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exchangeOfferPriceController,
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                'Our Offer Price',
                                Icons.local_offer_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              followUpDate ??
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => followUpDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined),
                            const SizedBox(width: 12),
                            Flexible(
                              fit: FlexFit.loose,
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
                                onPressed: () =>
                                    setState(() => followUpDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1F3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: loading ? null : sendPdfToWhatsApp,
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
                                  fontWeight: FontWeight.bold,
                                ),
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
