import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AddInquiryScreen extends StatefulWidget {
  @override
  State<AddInquiryScreen> createState() => _AddInquiryScreenState();
} 

class _AddInquiryScreenState extends State<AddInquiryScreen> {
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
        final data = vehicle.data() as Map<String, dynamic>;
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

  Future<void> sendWhatsAppAndSave() async {
  final name = nameController.text.trim();
  final phone = phoneController.text.trim();

  final message =
      "Hello $name 🙏\n\n"
      "Thank you for visiting Jiten Auto.\n"
      "Your quotation is attached.\n\n"
      "Regards,\nJiten Auto Team";

  final url = Uri.parse(
      "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}");

  await launchUrl(url, mode: LaunchMode.externalApplication);

  // 🔥 GENERATE PDF AFTER MESSAGE
  await generateQuotationPDF();

  await saveInquiry();
}

  Future<bool> saveInquiry() async {
    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage("Unable to save inquiry: user not signed in.");
        return false;
      }

      await FirebaseFirestore.instance.collection('inquiries').add({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "brand": brandController.text.trim(),
        "model": modelController.text.trim(),
        "variant": variantController.text.trim(),
        "vehicleId": selectedVehicleId,
        "price": priceController.text.trim(),
        "description": descriptionController.text.trim(),
        "paymentType": paymentType,
        "otherDescription": otherController.text.trim(),
        "reference": referenceController.text.trim(),
        "date": selectedDate,
        "staffId": user.uid,
        "createdBy": user.uid,
        "createdAt": Timestamp.now(),
        "status": "New Inquiry",
        if (followUpDate != null) "nextFollowUp": Timestamp.fromDate(followUpDate!),
      });

      if (mounted) {
        showMessage("WhatsApp launched and inquiry saved.");
        Navigator.pop(context);
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

  Future<void> generateQuotationPDF() async {
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

              // 🔴 HEADER
              pw.Text(
                "JITEN AUTO",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text("Quotation", style: pw.TextStyle(fontSize: 18)),

              pw.Divider(),

              // 🔵 CUSTOMER DETAILS
              pw.Text("Customer Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 8),
              pw.Text("Name: $name"),
              pw.Text("Mobile: $phone"),
              pw.Text("Reference: $reference"),
              pw.Text("Date: $date"),

              pw.SizedBox(height: 20),

              // 🔵 VEHICLE DETAILS
              pw.Text("Vehicle Details",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 8),
              pw.Text("Brand: $brand"),
              pw.Text("Model: $model"),
              pw.Text("Variant: $variant"),

              pw.SizedBox(height: 10),

              pw.Text(
                "Price: ₹$price",
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 30),

              // 🔵 FOOTER
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

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
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
                            selectedVariant = val;

                            brandController.text = selectedBrand!;
                            modelController.text = selectedModel!;
                            variantController.text = val!;
                            priceController.text = selected['Price'].toString(); // ✅ ONLY HERE
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
                        readOnly: true,
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
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: sendThankYou,
                                child: const Text("Send Thank You"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: sendQuotation,
                                child: const Text("Send Quotation"),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: saveInquiry,
                            child: const Text("Save Inquiry"),
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