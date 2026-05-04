import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditInquiryScreen extends StatefulWidget {
  final QueryDocumentSnapshot inquiry;

  const EditInquiryScreen({super.key, required this.inquiry});

  @override
  State<EditInquiryScreen> createState() => _EditInquiryScreenState();
}

class _EditInquiryScreenState extends State<EditInquiryScreen> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController brandController;
  late final TextEditingController modelController;
  late final TextEditingController variantController;
  late final TextEditingController priceController;
  late final TextEditingController descriptionController;
  late final TextEditingController referenceController;
  late final TextEditingController otherController;
  late final TextEditingController followUpCommentController;
  late final TextEditingController callDurationController;
  late final TextEditingController callNotesController;
  late String paymentType;
  late DateTime selectedDate;
  late DateTime newFollowUpDate;
  late DateTime callDateTime;
  bool loading = false;
  bool isClosed = false;
  bool isBooked = false;
  String status = 'New Inquiry';
  static const List<String> _statusOptions = [
    'New Inquiry',
    'Follow Ups',
    'Finance',
  ];
  List<Map<String, dynamic>> followUpHistory = [];
  List<Map<String, dynamic>> callHistory = [];

  String? selectedBrand;
  String? selectedModel;
  String? selectedVariant;
  String? selectedVariantPhotoUrl;

  List<String> brands = [];
  List<String> models = [];
  List<Map<String, dynamic>> variants = [];

  List<Map<String, dynamic>> editHistory = [];

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchBrands() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Brand').get();

    setState(() {
      brands = snapshot.docs.map((e) => e['Name'].toString()).toList();
    });
  }

  Future<void> fetchModels(String brand) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Model')
        .where('ParentBrand', isEqualTo: brand)
        .get();

    setState(() {
      models = snapshot.docs.map((e) => e['Name'].toString()).toList();
      variants = [];
    });
  }

  Future<void> fetchVariants(String model) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Variant')
        .where('ParentModel', isEqualTo: model)
        .get();

    setState(() {
      variants = snapshot.docs.map((e) => e.data()).toList();
    });
  }

  @override
void initState() {
  super.initState();

  final data = widget.inquiry.data() as Map<String, dynamic>;

  nameController = TextEditingController(text: data['name'] ?? '');
  phoneController = TextEditingController(text: data['phone'] ?? '');
  brandController = TextEditingController(text: data['brand'] ?? '');
  modelController = TextEditingController(text: data['model'] ?? '');
  variantController = TextEditingController(text: data['variant'] ?? '');
  priceController = TextEditingController(text: data['price'] ?? '');
  descriptionController = TextEditingController(
    text: data['description'] ?? '',
  );
  referenceController =
      TextEditingController(text: data['reference'] ?? '');

  otherController = TextEditingController(
    text: data['otherDescription'] ?? '',
  );

  followUpCommentController = TextEditingController();
  callDurationController = TextEditingController();
  callNotesController = TextEditingController();

  paymentType = data['paymentType'] ?? 'Loan';

  final nextFollowUp = data['nextFollowUp'];

  selectedDate = nextFollowUp is Timestamp
      ? nextFollowUp.toDate()
      : DateTime.now();

  newFollowUpDate = DateTime.now();
  callDateTime = DateTime.now();

  // DROPDOWN VALUES
  selectedBrand = data['brand'];
  selectedModel = data['model'];
  selectedVariant = data['variant'];

  selectedVariantPhotoUrl = data['vehiclePhotoUrl'];

  fetchBrands();

  if (selectedBrand != null) {
    fetchModels(selectedBrand!);
  }

  if (selectedModel != null) {
    fetchVariants(selectedModel!);
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {});
    });
  }

  // FOLLOWUP HISTORY
  final history = data['followUpHistory'];

  if (history is List) {
    followUpHistory =
        List<Map<String, dynamic>>.from(history);
  }

  // CALL HISTORY
  final calls = data['callHistory'];

  if (calls is List) {
    callHistory =
        List<Map<String, dynamic>>.from(calls);
  }

  // EDIT HISTORY
  final changes = data['editHistory'];

  if (changes is List) {
    editHistory =
        List<Map<String, dynamic>>.from(changes);
  }

  // STATUS
  isClosed = data['isClosed'] == true;
  isBooked = data['isBooked'] == true;

  final savedStatus =
      data['status'] as String? ?? 'New Inquiry';

  if (isClosed) {
    status = 'Closed';
  } else if (isBooked) {
    status = 'Booked';
  } else {
    status = _statusOptions.contains(savedStatus)
        ? savedStatus
        : 'New Inquiry';
  }
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
    followUpCommentController.dispose();
    callDurationController.dispose();
    callNotesController.dispose();
    super.dispose();
  }

  Future<void> _addFollowUp() async {
    final comment = followUpCommentController.text.trim();

    if (comment.isEmpty) {
      showMessage('Please enter a follow-up comment.');
      return;
    }

    final newFollowUp = {
      'date': Timestamp.fromDate(newFollowUpDate),
      'comment': comment,
      'createdAt': Timestamp.now(),
    };

    setState(() {
      followUpHistory.add(newFollowUp);
      followUpCommentController.clear();
      newFollowUpDate = DateTime.now();
    });
  }

  Future<void> _addCall() async {
    final duration = callDurationController.text.trim();
    final notes = callNotesController.text.trim();

    if (duration.isEmpty) {
      showMessage('Please enter call duration.');
      return;
    }

    final newCall = {
      'dateTime': Timestamp.fromDate(callDateTime),
      'duration': duration,
      'notes': notes,
      'createdAt': Timestamp.now(),
    };

    setState(() {
      callHistory.add(newCall);
      callDurationController.clear();
      callNotesController.clear();
      callDateTime = DateTime.now();
    });
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage('Unable to save inquiry: user not signed in.');
        return;
      }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();
    final price = priceController.text.trim();
    final description = descriptionController.text.trim();
    final reference = referenceController.text.trim();
    final otherDescription = otherController.text.trim();
    final oldData =
    widget.inquiry.data() as Map<String, dynamic>;

    List<String> changes = [];

    if (oldData['brand'] != brand) {
      changes.add(
          'Brand changed from "${oldData['brand']}" to "$brand"');
    }

    if (oldData['model'] != model) {
      changes.add(
          'Model changed from "${oldData['model']}" to "$model"');
    }

    if (oldData['variant'] != variant) {
      changes.add(
          'Variant changed from "${oldData['variant']}" to "$variant"');
    }

    if (oldData['price'] != price) {
      changes.add(
          'Price changed from "${oldData['price']}" to "$price"');
    }

    if (oldData['status'] != status) {
      changes.add(
          'Status changed from "${oldData['status']}" to "$status"');
    }

    if (changes.isNotEmpty) {
      editHistory.add({
        'staff': user.email ?? 'Staff',
        'changes': changes,
        'time': Timestamp.now(),
      });
    }

    if (name.isEmpty) {
      showMessage('Please enter the customer name.');
      return;
    }
    if (phone.isEmpty) {
      showMessage('Please enter the customer phone number.');
      return;
    }
    if (brand.isEmpty) {
      showMessage('Please enter the vehicle brand.');
      return;
    }

    setState(() => loading = true);

    try {
      

      await FirebaseFirestore.instance
          .collection('inquiries')
          .doc(widget.inquiry.id)
          .update({
            'name': name,
            'phone': phone,
            'brand': brand,
            'model': model,
            'variant': variant,
            'price': price,
            'description': description,
            'paymentType': paymentType,
            'otherDescription': otherDescription,
            'reference': reference,
            'nextFollowUp': Timestamp.fromDate(selectedDate),
            'followUpHistory': followUpHistory,
            'callHistory': callHistory,
            'vehiclePhotoUrl': selectedVariantPhotoUrl,
            'editHistory': editHistory,
            'isClosed': isClosed,
            'isBooked': isBooked,
            'status': paymentType == 'Loan'
                ? 'Finance'
                : status,
          });

      if (mounted) {
        showMessage('Inquiry updated successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showMessage('Failed to update inquiry. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _pickNewFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: newFollowUpDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => newFollowUpDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Lead')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Basic Information Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: brands.contains(selectedBrand)
                        ? selectedBrand
                        : null,
                      isExpanded: true,
                      hint: const Text("Select Brand"),
                      items: brands.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(b),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        setState(() {
                          selectedBrand = val;
                          selectedModel = null;
                          selectedVariant = null;
                          modelController.clear();
                          variantController.clear();
                        });

                        brandController.text = val ?? '';
                        await fetchModels(val!);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Brand',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: models.contains(selectedModel)
                        ? selectedModel
                        : null,
                      isExpanded: true,
                      hint: const Text("Select Model"),
                      items: models.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        setState(() {
                          selectedModel = val;
                          selectedVariant = null;
                          variantController.clear();
                        });

                        modelController.text = val ?? '';
                        await fetchVariants(val!);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: variants.any(
                              (v) => v['Name'] == selectedVariant,
                            )
                          ? selectedVariant
                          : null,
                      isExpanded: true,
                      hint: const Text("Select Variant"),
                      items: variants.map((v) {
                        return DropdownMenuItem<String>(
                          value: v['Name'],
                          child: Text(
                            v['Name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final selected =
                            variants.firstWhere((e) => e['Name'] == val);

                        setState(() {
                          selectedVariant = val;

                          selectedVariantPhotoUrl =
                            selected['photoUrl'] ??
                            selected['photos']?[0];

                          variantController.text = val ?? '';
                          priceController.text =
                              selected['Price'].toString();
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Variant',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (selectedVariantPhotoUrl != null &&
                        selectedVariantPhotoUrl!.isNotEmpty)
                      Column(
                        children: [
                          const SizedBox(height: 14),
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                selectedVariantPhotoUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),

                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(status),
                      initialValue: status,
                      items: _statusOptions
                          .map(
                            (option) => DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            status = value;
                            isBooked = value == 'Booked';
                            isClosed = value == 'Closed';
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Current Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isClosed,
                          onChanged: (value) {
                            setState(() {
                              isClosed = value ?? false;
                              if (isClosed) {
                                isBooked = false;
                                status = 'Closed'; // Auto-set status when closed
                              } else if (status == 'Closed') {
                                status = 'New Inquiry';
                              }
                            });
                          },
                        ),
                        const Text('Closed'),
                        const SizedBox(width: 30),
                        Checkbox(
                          value: isBooked,
                          onChanged: (value) {
                            setState(() {
                              isBooked = value ?? false;
                              if (isBooked) {
                                isClosed = false;
                                status = 'Booked'; // Auto-set status when booked
                              } else if (status == 'Booked') {
                                status = 'New Inquiry';
                              }
                            });
                          },
                        ),
                        const Text('Booked'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Add New Follow-up Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Follow-up',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Follow-up Date: ${newFollowUpDate.toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickNewFollowUpDate,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: followUpCommentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Follow-up Comment',
                        hintText: 'Enter details about this follow-up...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addFollowUp,
                        child: const Text('Add Follow-up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Add Call Log Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Call',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Call Date & Time: ${callDateTime.toString()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: callDateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              if (!context.mounted) return;
                              final timePicked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(callDateTime),
                              );
                              if (timePicked != null) {
                                setState(() {
                                  callDateTime = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    timePicked.hour,
                                    timePicked.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: callDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Call Duration (e.g., 5 min 30 sec)',
                        hintText: 'Enter call duration...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: callNotesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Call Notes',
                        hintText: 'Enter notes about the call...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addCall,
                        child: const Text('Log Call'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (editHistory.isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lead Changes History',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 14),

                      ...editHistory.reversed.map((e) {
                        final changes =
                            List<String>.from(e['changes'] ?? []);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['staff'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              ...changes.map(
                                (c) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Text("• $c"),
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                (e['time'] as Timestamp)
                                    .toDate()
                                    .toString(),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _saveChanges,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}