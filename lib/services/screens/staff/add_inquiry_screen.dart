import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
// remove share_plus import

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
  String? selectedVariantPhotoUrl; // Store variant photo URL

  bool loading = false;
  bool lookupLoading = false;

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

  // 🔥 FETCH BRAND
  Future<void> fetchBrands() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Brand').get();

    setState(() {
      brands = snapshot.docs.map((e) => e['Name'].toString()).toList();
    });
  }

  // 🔥 FETCH MODEL
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
    });
  }

  // 🔥 FETCH VARIANT
  Future<void> fetchVariants(String model) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Variant')
        .where('ParentModel', isEqualTo: model)
        .get();

    setState(() {
      variants = snapshot.docs.map((e) => e.data()).toList();
      selectedVariant = null;
    });
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ignore: unused_element
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
        final data = vehicle.data();
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

  Future<bool> saveInquiry() async {

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    // NAME VALIDATION
    if (name.isEmpty) {
      showMessage("Please enter customer name.");
      return false;
    }

    if (name.length < 3) {
      showMessage("Name must be at least 3 characters.");
      return false;
    }

    // PHONE VALIDATION
    if (phone.isEmpty) {
      showMessage("Please enter phone number.");
      return false;
    }

    // BRAND VALIDATION
    if (selectedBrand == null || selectedBrand!.isEmpty) {
      showMessage("Please select vehicle brand.");
      return false;
    }

    // MODEL VALIDATION
    if (selectedModel == null || selectedModel!.isEmpty) {
      showMessage("Please select vehicle model.");
      return false;
    }

    // VARIANT VALIDATION
    if (selectedVariant == null || selectedVariant!.isEmpty) {
      showMessage("Please select vehicle variant.");
      return false;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      showMessage("Enter valid 10-digit phone number.");
      return false;
    }

    setState(() => loading = true);


    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage("Unable to save inquiry: user not signed in.");
        return false;
      }

      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('inquiryCounter');

      final counterSnapshot = await counterRef.get();

      int currentNumber = 0;

      if (counterSnapshot.exists) {
        currentNumber = counterSnapshot['current'] ?? 0;
      }

      final newInquiryNumber = currentNumber + 1;

      // update counter
      await counterRef.set({
        'current': newInquiryNumber,
      });

      await FirebaseFirestore.instance.collection('inquiries').add({
        'inquiryNumber': newInquiryNumber,
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "brand": brandController.text.trim(),
        "model": modelController.text.trim(),
        "variant": variantController.text.trim(),
        "vehicleId": selectedVehicleId,
        "vehiclePhotoUrl": selectedVariantPhotoUrl, // Save vehicle photo URL
        "price": priceController.text.trim(),
        "description": descriptionController.text.trim(),
        "paymentType": paymentType,
        "otherDescription": otherController.text.trim(),
        "reference": referenceController.text.trim(),
        "date": selectedDate,
        "staffId": user.uid,
        "createdBy": user.uid,
        "createdAt": Timestamp.now(),
        "status": paymentType == "Loan"
            ? "Finance"
            : "New Inquiry",
        if (followUpDate != null) "nextFollowUp": Timestamp.fromDate(followUpDate!),
      });

      if (mounted) {
        showMessage("Lead generated successfully.");
        
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

 Future<String?> saveQuotationPdfToLocalStorage() async {
  try {
    final pdf = pw.Document();

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final reference = referenceController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();
    final price = priceController.text.trim();
    final date = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("JITEN AUTO",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text("Quotation", style: pw.TextStyle(fontSize: 18)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text("Customer Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text("Name: $name"),
              pw.Text("Mobile: $phone"),
              pw.Text("Reference: $reference"),
              pw.Text("Date: $date"),
              pw.SizedBox(height: 20),
              pw.Text("Vehicle Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text("Brand: $brand"),
              pw.Text("Model: $model"),
              pw.Text("Variant: $variant"),
              pw.SizedBox(height: 10),
              pw.Text("Price: ₹$price",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 30),
              pw.Text("Thank you for your inquiry.",
                  style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text("Regards,\nJiten Auto",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    final bytes = await pdf.save();

// ✅ Replace with this:
final cacheDir = await getTemporaryDirectory();
final filePath = '${cacheDir.path}/quotation.pdf';
final file = File(filePath);
await file.writeAsBytes(bytes, flush: true);

    return filePath;
  } catch (e) {
    showMessage('Failed to save PDF: ${e.toString()}');
    return null;
  }
}

Future<void> sendPdfToWhatsApp() async {
  final name = nameController.text.trim();
  final phone = phoneController.text.trim();

  // NAME VALIDATION
  if (name.isEmpty) {
    showMessage("Please enter customer name.");
    return;
  }

  if (name.length < 3) {
    showMessage("Name must be at least 3 characters.");
    return;
  }

  // PHONE VALIDATION
  if (phone.isEmpty) {
    showMessage("Please enter phone number.");
    return;
  }

  if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
    showMessage("Enter valid 10-digit phone number.");
    return;
  }

  setState(() => loading = true);

  try {
    // 1. Save inquiry first
    final inquirySaved = await saveInquiry();
    if (!inquirySaved) {
      setState(() => loading = false);
      return;
    }

    // 2. Generate PDF
    final pdf = pw.Document();
    final reference = referenceController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();
    final price = priceController.text.trim();
    final date = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Container(
          color: PdfColor.fromInt(0xFFF4DBE1),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF7B1F3F),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(12),
                    ),
                  ),
                  child: pw.Text(
                    "🚗 JITEN AUTO\nPremium Vehicle Quotation",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),

                pw.SizedBox(height: 20),

                // Customer Details
                pw.Text(
                  "Customer Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text("Name: $name"),
                pw.Text("Phone: +91 $phone"),
                pw.Text("Reference: $reference"),
                pw.Text("Date: $date"),

                pw.SizedBox(height: 20),

                // Vehicle Details
                pw.Text(
                  "Vehicle Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text("Brand: $brand"),
                pw.Text("Model: $model"),
                pw.Text("Variant: $variant"),

                pw.SizedBox(height: 20),

                // 🔥 FIXED GRADIENT SECTION
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(   // ✅ FIX HERE
                      colors: [
                        PdfColor.fromInt(0xFF7B1F3F),
                        PdfColor.fromInt(0xFF5A1530),
                      ],
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Quoted Price",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColor.fromInt(0xFFF4DBE1),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        "₹ $price",
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Footer
                pw.Text(
                  "Thank you for your inquiry 🙏",
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  "Regards,\nJiten Auto Team",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bytes = await pdf.save();

    // 3. Save to cache
    final cacheDir = await getTemporaryDirectory();
    final filePath = '${cacheDir.path}/quotation.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // 4. Validate file
    if (!await file.exists() || await file.length() == 0) {
      showMessage('Failed to generate PDF.');
      return;
    }

    // 5. Send to WhatsApp
    final message =
        "Hello $name 👋\n\n"
        "Please find the attached quotation.\n\n"
        "Regards,\nJiten Auto Team";

    await _platform.invokeMethod('shareToWhatsApp', {
      'filePath': filePath,
      'phone': phone,
      'message': message,
    });
    if (mounted) {
      Navigator.pop(context);
    }

  } catch (e) {
    print("WHATSAPP ERROR => $e");
    showMessage('Error: ${e.toString()}');
  } finally {
    if (mounted) setState(() => loading = false);
  }
}

  Future<void> sendThankYou() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    final message = 
        "Thank you $name 🙏\n"
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

    final message =
        "Hello $name 👋\n\n"
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
                      
                      // 🔵 BRAND DROPDOWN
                      DropdownButtonFormField<String>(
                        value: selectedBrand,
                        isExpanded: true,
                        hint: const Text("Select Brand"),
                        items: brands.map<DropdownMenuItem<String>>((b) {
                          return DropdownMenuItem(value: b, child: Text(b));
                        }).toList(),
                        onChanged: (val) {
                          setState(() => selectedBrand = val);
                          fetchModels(val!);
                        },
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

                      // 🔵 MODEL DROPDOWN
                      DropdownButtonFormField<String>(
                        value: selectedModel,
                        isExpanded: true,
                        hint: const Text("Select Model"),
                        items: models.map<DropdownMenuItem<String>>((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (val) {
                          setState(() => selectedModel = val);
                          fetchVariants(val!);
                        },
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

                      // 🔵 VARIANT DROPDOWN
                      DropdownButtonFormField<String>(
                        value: selectedVariant,
                        isExpanded: true, // ✅ FIX OVERFLOW
                        hint: const Text("Select Variant"),
                        items: variants.map<DropdownMenuItem<String>>((v) {
                          return DropdownMenuItem<String>(
                            value: v['Name'],
                            child: Text(
                              v['Name'] ?? '',
                              overflow: TextOverflow.ellipsis, // ✅ CLEAN UI
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selected =
                              variants.firstWhere((e) => e['Name'] == val);

                          setState(() {
                            selectedVariant = val ?? '';
                            selectedVariantPhotoUrl = selected['photoUrl']; // Capture photo URL

                            brandController.text = selectedBrand!;
                            modelController.text = selectedModel!;
                            variantController.text = val!;
                            priceController.text = selected['Price'].toString();
                          });
                        },
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
                      
                      const SizedBox(height: 16),
                      
                      const SizedBox(height: 16),
                      
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
                        initialValue: paymentType,
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

                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: followUpDate ?? DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
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
                                    color: followUpDate != null ? Colors.black : Colors.black54,
                                  ),
                                ),
                              ),
                              if (followUpDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => followUpDate = null),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                        
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

                          onPressed: sendPdfToWhatsApp,

                          label: const Text(
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
      ),
    );
  }
}