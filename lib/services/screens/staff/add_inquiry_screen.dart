import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class AddInquiryScreen extends StatefulWidget {
  const AddInquiryScreen({super.key});

  @override
  State<AddInquiryScreen> createState() => _AddInquiryScreenState();
}

class _AddInquiryScreenState extends State<AddInquiryScreen> {
  static const _platform = MethodChannel('whatsapp_pdf_share');

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
  DateTime selectedDate = DateTime.now();
  DateTime? followUpDate;
  String? selectedVariantPhotoUrl;
  List<String> selectedVariantPhotoUrls = [];

  bool loading = false;
  bool lookupLoading = false;
  bool brandsLoading = true;
  bool inquiryAlreadySaved = false;

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

  Future<void> fetchBrands() async {
    try {
      setState(() => brandsLoading = true);
      final snapshot =
          await FirebaseFirestore.instance.collection('Brand').get();
      setState(() {
        brands = snapshot.docs.map((e) => e['Name'].toString()).toList();
        brandsLoading = false;
      });
    } catch (e) {
      setState(() => brandsLoading = false);
      showMessage("Failed to load brands");
    }
  }

  Future<void> fetchModels(String brand) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Model')
        .where('ParentBrand', isEqualTo: brand)
        .get();
    setState(() {
      models = snapshot.docs.map((e) => e['Name'].toString()).toList();
      selectedModel = null;
      selectedVariant = null;
      variants = [];
      modelController.clear();
      variantController.clear();
      priceController.clear();
      selectedVariantPhotoUrl = null;
      selectedVariantPhotoUrls = [];
    });
  }

  Future<void> fetchVariants(String model) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Variant')
        .where('ParentModel', isEqualTo: model)
        .get();

    List<Map<String, dynamic>> fetchedVariants = [];

    for (var doc in snapshot.docs) {
      var variantData = Map<String, dynamic>.from(doc.data());
      String variantName = variantData['Name'] ?? '';
      String? docId = variantData['vehicleImagesDocId'];

      debugPrint("🔍 Variant: '$variantName' → docId: '$docId'");

      if (docId != null && docId.isNotEmpty) {
        try {
          final imagesSnap = await FirebaseFirestore.instance
              .collection('VehicleImages')
              .doc(docId)
              .collection('images')
              .get();

          if (imagesSnap.docs.isNotEmpty) {
            variantData['photoUrls'] =
                imagesSnap.docs.map((d) => d['url'].toString()).toList();
            variantData['photoUrl'] = variantData['photoUrls'][0];
            debugPrint(
                "✅ Found ${imagesSnap.docs.length} images for '$variantName'");
          } else {
            variantData['photoUrls'] = [];
            variantData['photoUrl'] = null;
          }
        } catch (e) {
          variantData['photoUrls'] = [];
          variantData['photoUrl'] = null;
          debugPrint("❌ Error: $e");
        }
      } else {
        variantData['photoUrls'] = [];
        variantData['photoUrl'] = null;
        debugPrint("⚠️ No image linked for '$variantName'");
      }

      fetchedVariants.add(variantData);
    }

    setState(() {
      variants = fetchedVariants;
      selectedVariant = null;
      variantController.clear();
      priceController.clear();
      selectedVariantPhotoUrl = null;
      selectedVariantPhotoUrls = [];
    });
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> saveInquiry() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) { showMessage("Please enter customer name."); return false; }
    if (name.length < 3) { showMessage("Name must be at least 3 characters."); return false; }
    if (phone.isEmpty) { showMessage("Please enter phone number."); return false; }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) { showMessage("Enter valid 10-digit phone number."); return false; }
    if (selectedBrand == null) { showMessage("Please select vehicle brand."); return false; }
    if (selectedModel == null) { showMessage("Please select vehicle model."); return false; }
    if (selectedVariant == null) { showMessage("Please select vehicle variant."); return false; }

    final price = priceController.text.trim();
    if (price.isEmpty) { showMessage("Please enter vehicle price."); return false; }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) { showMessage("Enter valid price."); return false; }
    final priceValue = double.tryParse(price);
    if (priceValue == null) { showMessage("Invalid price."); return false; }
    if (priceValue < 10000) { showMessage("Price must be at least 5 digits."); return false; }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { showMessage("User not logged in."); return false; }

      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('inquiryCounter');
      final counterSnapshot = await counterRef.get();
      int currentNumber = 0;
      if (counterSnapshot.exists) {
        currentNumber = counterSnapshot['current'] ?? 0;
      }
      final newInquiryNumber = currentNumber + 1;
      await counterRef.set({'current': newInquiryNumber});

      await FirebaseFirestore.instance.collection('inquiries').add({
        'inquiryNumber': newInquiryNumber,
        "name": name,
        "phone": phone,
        "brand": brandController.text.trim(),
        "model": modelController.text.trim(),
        "variant": variantController.text.trim(),
        "vehicleId": selectedVehicleId,
        "vehiclePhotoUrl": selectedVariantPhotoUrl,
        "price": priceController.text.trim(),
        "description": descriptionController.text.trim(),
        "otherDescription": otherController.text.trim(),
        "reference": referenceController.text.trim(),
        "date": selectedDate,
        "staffId": user.uid,
        "assignedTo": user.uid,
        "createdBy": user.uid,
        "createdAt": Timestamp.now(),
        "status": "New Inquiry",
        "paymentType": paymentType,
        if (followUpDate != null)
          "nextFollowUp": Timestamp.fromDate(followUpDate!),
      });

      return true;
    } catch (e) {
      showMessage("Failed to save inquiry: $e");
      return false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendPdfToWhatsApp() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final price = priceController.text.trim();

    if (name.isEmpty) { showMessage("Please enter customer name."); return; }
    if (phone.isEmpty) { showMessage("Please enter phone number."); return; }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) { showMessage("Enter valid 10-digit phone number."); return; }
    if (selectedBrand == null) { showMessage("Please select vehicle brand."); return; }
    if (selectedModel == null) { showMessage("Please select vehicle model."); return; }
    if (selectedVariant == null) { showMessage("Please select vehicle variant."); return; }
    if (price.isEmpty) { showMessage("Please enter vehicle price."); return; }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) { showMessage("Enter valid price."); return; }
    final priceValue = double.tryParse(price);
    if (priceValue == null) { showMessage("Invalid price."); return; }
    if (priceValue < 10000) { showMessage("Price must be at least 5 digits."); return; }

    setState(() => loading = true);

    try {
      await Permission.manageExternalStorage.request();
      await Permission.storage.request();

      if (!inquiryAlreadySaved) {
        final inquirySaved = await saveInquiry();
        if (!inquirySaved) {
          setState(() => loading = false);
          return;
        }
        inquiryAlreadySaved = true;
      }

      // ── Load ALL colour images ──────────────────────────────
      List<pw.MemoryImage> vehicleImages = [];
      for (String url in selectedVariantPhotoUrls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            vehicleImages.add(pw.MemoryImage(response.bodyBytes));
            debugPrint("✅ Loaded image: $url");
          }
        } catch (e) {
          debugPrint("❌ Failed to load: $url → $e");
        }
      }

      final reference = referenceController.text.trim();
      final brand = brandController.text.trim();
      final model = modelController.text.trim();
      final variant = variantController.text.trim();
      final priceFinal = priceController.text.trim();
      final date = DateTime.now().toString().split(' ')[0];

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) {
            return pw.Column(
              children: [
                // ── HEADER ────────────────────────────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 30, vertical: 28),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF7B1F3F),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "JITEN AUTO",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 30,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Vehicle Quotation",
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── BODY ──────────────────────────────────────
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    color: PdfColor.fromInt(0xFFF7EEF1),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [

                          // CUSTOMER CARD
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(18),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(18),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "Customer Details",
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromInt(0xFF7B1F3F),
                                  ),
                                ),
                                pw.SizedBox(height: 14),
                                pw.Text("Name: $name",
                                    style:
                                        const pw.TextStyle(fontSize: 14)),
                                pw.SizedBox(height: 6),
                                pw.Text("Phone: $phone",
                                    style:
                                        const pw.TextStyle(fontSize: 14)),
                                pw.SizedBox(height: 6),
                                pw.Text("Reference: $reference",
                                    style:
                                        const pw.TextStyle(fontSize: 14)),
                                pw.SizedBox(height: 6),
                                pw.Text("Date: $date",
                                    style:
                                        const pw.TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 20),

                          // VEHICLE CARD
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(18),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(18),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "Vehicle Details",
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromInt(0xFF7B1F3F),
                                  ),
                                ),
                                pw.SizedBox(height: 14),
                                pw.Text("Brand: $brand"),
                                pw.SizedBox(height: 6),
                                pw.Text("Model: $model"),
                                pw.SizedBox(height: 6),
                                pw.Text("Variant: $variant"),

                                // ── ALL COLOUR IMAGES ────────
                                if (vehicleImages.isNotEmpty)
                                  pw.Padding(
                                    padding:
                                        const pw.EdgeInsets.only(top: 16),
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          "Available Colours",
                                          style: pw.TextStyle(
                                            fontSize: 13,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColor.fromInt(
                                                0xFF7B1F3F),
                                          ),
                                        ),
                                        pw.SizedBox(height: 10),
                                        pw.Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: vehicleImages
                                              .map(
                                                (img) => pw.Container(
                                                  width: 120,
                                                  height: 90,
                                                  decoration: pw.BoxDecoration(
                                                    borderRadius:
                                                        pw.BorderRadius
                                                            .circular(10),
                                                  ),
                                                  child: pw.ClipRRect(
                                                    horizontalRadius: 10,
                                                    verticalRadius: 10,
                                                    child: pw.Image(img,
                                                        fit:
                                                            pw.BoxFit.cover),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 22),

                          // PRICE CARD
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF7B1F3F),
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "Quotation Price",
                                  style: const pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  "Rs. $priceFinal",
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 28,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          pw.Spacer(),

                          // FOOTER
                          pw.Center(
                            child: pw.Column(
                              children: [
                                pw.Text(
                                  "Thank you for choosing Jiten Auto",
                                  style: pw.TextStyle(
                                    color: PdfColor.fromInt(0xFF7B1F3F),
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  "We appreciate your inquiry.",
                                  style: const pw.TextStyle(fontSize: 12),
                                ),
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

      final message = "Hello $name 👋\n\n"
          "Please find attached the quotation for the vehicle you inquired about.\n\n"
          "Regards,\nJiten Auto Team";

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

  Future<void> sendThankYou() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final message = "Thank you $name 🙏\n"
        "For visiting Jiten Auto.\n"
        "We appreciate your inquiry.\n\n"
        "Our team will get back to you shortly.\n\n"
        "Regards,\nJiten Auto Team";
    final url = Uri.parse(
        "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> sendQuotation() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text;
    final model = modelController.text;
    final variant = variantController.text;
    final price = priceController.text;
    final message = "Hello $name 👋\n\n"
        "Thank you for your interest.\n\n"
        "📄 *Quotation Details*\n"
        "Vehicle: $brand $model $variant\n"
        "Price: ₹$price\n"
        "Payment: $paymentType\n\n"
        "Please let us know if you have any questions.\n\n"
        "Regards,\nJiten Auto Team";
    final url = Uri.parse(
        "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}");
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
      appBar: AppBar(
        title: const Text("Add Inquiry"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                    // ── ICON ──────────────────────────────────
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
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Capture the lead details and send a WhatsApp confirmation.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // ── NAME ──────────────────────────────────
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

                    // ── PHONE ─────────────────────────────────
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

                    // ── BRAND ─────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: selectedBrand,
                      isExpanded: true,
                      hint: brands.isEmpty
                          ? const Text("Loading brands...")
                          : const Text("Select Brand"),
                      items: brands
                          .map<DropdownMenuItem<String>>((b) =>
                              DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: brands.isEmpty
                          ? null
                          : (val) {
                              setState(() {
                                selectedBrand = val;
                                brandController.text = val ?? '';
                              });
                              if (val != null) fetchModels(val);
                            },
                      decoration: InputDecoration(
                        labelText: "Vehicle Brand",
                        prefixIcon:
                            const Icon(Icons.directions_car_outlined),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── MODEL ─────────────────────────────────
                    DropdownButtonFormField<String>(
                      key: ValueKey('model_$selectedBrand'),
                      value: selectedModel,
                      isExpanded: true,
                      hint: const Text("Select Model"),
                      disabledHint: const Text("Select a brand first"),
                      items: models
                          .map<DropdownMenuItem<String>>((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: selectedBrand == null || models.isEmpty
                          ? null
                          : (val) {
                              setState(() {
                                selectedModel = val;
                                modelController.text = val ?? '';
                              });
                              if (val != null) fetchVariants(val);
                            },
                      decoration: InputDecoration(
                        labelText: "Model",
                        prefixIcon:
                            const Icon(Icons.precision_manufacturing),
                        filled: true,
                        fillColor: selectedBrand == null
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── VARIANT ───────────────────────────────
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                          'variant_${selectedBrand}_$selectedModel'),
                      value: selectedVariant,
                      isExpanded: true,
                      hint: const Text("Select Variant"),
                      disabledHint: const Text("Select a model first"),
                      items: variants
                          .map<DropdownMenuItem<String>>(
                            (v) => DropdownMenuItem<String>(
                              value: v['Name'],
                              child: Text(
                                v['Name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged:
                          selectedModel == null || variants.isEmpty
                              ? null
                              : (val) {
                                  final selected = variants.firstWhere(
                                      (e) => e['Name'] == val);
                                  setState(() {
                                    selectedVariant = val ?? '';
                                    selectedVariantPhotoUrl =
                                        selected['photoUrl'];
                                    selectedVariantPhotoUrls =
                                        List<String>.from(
                                            selected['photoUrls'] ?? []);
                                    debugPrint(
                                        "🖼️ Total images: ${selectedVariantPhotoUrls.length}");
                                    brandController.text = selectedBrand!;
                                    modelController.text = selectedModel!;
                                    variantController.text = val!;
                                    priceController.text =
                                        selected['Price'].toString();
                                  });
                                },
                      decoration: InputDecoration(
                        labelText: "Variant",
                        prefixIcon: const Icon(Icons.widgets_outlined),
                        filled: true,
                        fillColor: selectedModel == null
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── COLOUR GALLERY ────────────────────────
                    if (selectedVariantPhotoUrls.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Available Colours",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: selectedVariantPhotoUrls.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(right: 10),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    child: Image.network(
                                      selectedVariantPhotoUrls[index],
                                      width: 160,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                    // ── PRICE ─────────────────────────────────
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

                    // ── VEHICLE DESCRIPTION ───────────────────
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
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

                    // ── PAYMENT ───────────────────────────────
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

                    // ── OTHER DESCRIPTION ─────────────────────
                    TextField(
                      controller: otherController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Other Description",
                        prefixIcon:
                            const Icon(Icons.description_outlined),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── REFERENCE ─────────────────────────────
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
                    const SizedBox(height: 16),

                    // ── FOLLOW UP DATE ────────────────────────
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined),
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
                                onPressed: () =>
                                    setState(() => followUpDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── SEND BUTTON ───────────────────────────
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