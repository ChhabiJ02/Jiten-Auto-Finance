import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'dart:async';
import '../../vehicle_model_lookup.dart';

class EditInquiryScreen extends StatefulWidget {
  final QueryDocumentSnapshot inquiry;

  const EditInquiryScreen({super.key, required this.inquiry});

  @override
  State<EditInquiryScreen> createState() => _EditInquiryScreenState();
}

class _EditInquiryScreenState extends State<EditInquiryScreen> {
  static const double _sectionTitleFontSize = 16;

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController brandController;
  late final TextEditingController modelController;
  late final TextEditingController variantController;
  late final TextEditingController priceController;
  late final TextEditingController descriptionController;
  late final TextEditingController referenceController;
  late final TextEditingController otherController;
  late final TextEditingController callDurationController;
  late String paymentType;
  late DateTime selectedDate;
  late DateTime newFollowUpDate;

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

  DateTime? callStartedAt;
  PhoneStateStatus? lastStatus;

  StreamSubscription<PhoneState>? callSubscription;

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

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(dynamic value) {
    final parsed = _parseDate(value);
    if (parsed == null) return 'N/A';
    return parsed.toString().split(' ')[0];
  }

  bool get _hasPendingFollowUpDraft {
    return !_isSameDate(newFollowUpDate, selectedDate);
  }

  bool get _hasPendingCallDraft {
    return callDurationController.text.trim().isNotEmpty;
  }

  bool _stagePendingFollowUp() {
    if (!_hasPendingFollowUpDraft) {
      return true;
    }

    final alreadyExists = followUpHistory.any((item) {
      final itemDate = _parseDate(item['date']);
      return itemDate != null && _isSameDate(itemDate, newFollowUpDate);
    });

    if (alreadyExists) {
      showMessage(
        'A follow-up already exists for this date. Edit it or choose another date.',
      );
      return false;
    }

    followUpHistory.add({
      'date': Timestamp.fromDate(newFollowUpDate),
      'createdAt': Timestamp.now(),
    });
    selectedDate = newFollowUpDate;
    return true;
  }

  bool _stagePendingCall() {
    if (!_hasPendingCallDraft) {
      return true;
    }

    final duration = callDurationController.text.trim();
    if (duration.isEmpty) {
      showMessage('Please make a call first or enter a call duration.');
      return false;
    }

    callHistory.add({
      'date': Timestamp.now(),
      'duration': duration,
      'createdAt': Timestamp.now(),
    });
    callDurationController.clear();
    return true;
  }

  Future<void> fetchBrands() async {
    final snapshot = await FirebaseFirestore.instance.collection('Brand').get();

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
    });
  }

  Future<void> _loadSelectedModelDetails(String brand, String model) async {
    final details = await fetchVehicleModelLookupData(
      firestore: FirebaseFirestore.instance,
      brand: brand,
      model: model,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      selectedVariant = null;
      variantController.clear();
      selectedVariantPhotoUrl =
          details.primaryPhotoUrl ?? selectedVariantPhotoUrl;
      priceController.text = details.price.isNotEmpty
          ? details.price
          : priceController.text;
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
    referenceController = TextEditingController(text: data['reference'] ?? '');

    otherController = TextEditingController(
      text: data['otherDescription'] ?? '',
    );

    callDurationController = TextEditingController();

    paymentType = data['paymentType'] ?? 'Loan';

    final nextFollowUp = data['nextFollowUp'];

    selectedDate = _parseDate(nextFollowUp) ?? DateTime.now();

    newFollowUpDate = selectedDate;

    selectedBrand = data['brand'];
    selectedModel = data['model'];
    selectedVariant = data['variant'];

    selectedVariantPhotoUrl = data['vehiclePhotoUrl'];

    fetchBrands();

    if (selectedBrand != null) {
      fetchModels(selectedBrand!);
    }

    if (selectedBrand != null && selectedModel != null) {
      _loadSelectedModelDetails(selectedBrand!, selectedModel!);
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {});
      });
    }

    final history = data['followUpHistory'];
    if (history is List) {
      followUpHistory = List<Map<String, dynamic>>.from(history);
    }

    final calls = data['callHistory'];
    if (calls is List) {
      callHistory = List<Map<String, dynamic>>.from(calls);
    }

    final changes = data['editHistory'];
    if (changes is List) {
      editHistory = List<Map<String, dynamic>>.from(changes);
    }

    isClosed = data['isClosed'] == true;
    isBooked = data['isBooked'] == true;

    final savedStatus = data['status'] as String? ?? 'New Inquiry';

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
    callDurationController.dispose();
    callSubscription?.cancel();
    super.dispose();
  }

  Future<void> startDirectCall() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      showMessage('Customer phone number missing.');

      return;
    }

    // PERMISSION
    await Permission.phone.request();

    // SAVE START TIME
    callStartedAt = DateTime.now();

    // LISTEN CALL STATE
    callSubscription?.cancel();

    callSubscription = PhoneState.stream.listen((event) async {
      final status = event.status;

      // CALL ENDED
      if (lastStatus == PhoneStateStatus.CALL_STARTED &&
          status == PhoneStateStatus.CALL_ENDED) {
        final callEndedAt = DateTime.now();

        final duration = callEndedAt.difference(callStartedAt!);

        final durationText =
            '${duration.inMinutes} min ${duration.inSeconds % 60} sec';

        setState(() {
          callDurationController.text = durationText;
        });

        showMessage(
          'Call ended. Review the duration and tap Save All Changes.',
        );
      }

      lastStatus = status;
    });

    // START DIRECT CALL
    await FlutterPhoneDirectCaller.callNumber(phone);
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
    final oldData = widget.inquiry.data() as Map<String, dynamic>;

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

    if (!_stagePendingFollowUp()) {
      return;
    }
    if (!_stagePendingCall()) {
      return;
    }

    final effectiveStatus = isClosed
        ? 'Closed'
        : isBooked
        ? 'Booked'
        : paymentType == 'Loan'
        ? 'Finance'
        : status == 'Finance'
        ? 'New Inquiry'
        : status;

    final changes = <String>[];

    if (oldData['brand'] != brand) {
      changes.add('Brand changed from "${oldData['brand']}" to "$brand"');
    }

    if (oldData['model'] != model) {
      changes.add('Model changed from "${oldData['model']}" to "$model"');
    }

    if (oldData['variant'] != variant) {
      changes.add('Variant changed from "${oldData['variant']}" to "$variant"');
    }

    if (oldData['price'] != price) {
      changes.add('Price changed from "${oldData['price']}" to "$price"');
    }

    final oldPaymentType = (oldData['paymentType'] ?? 'Loan').toString();
    if (oldPaymentType != paymentType) {
      changes.add(
        'Payment option changed from "$oldPaymentType" to "$paymentType"',
      );
    }

    final oldStatus = (oldData['status'] ?? 'New Inquiry').toString();
    if (oldStatus != effectiveStatus) {
      changes.add('Status changed from "$oldStatus" to "$effectiveStatus"');
    }

    if (changes.isNotEmpty) {
      editHistory.add({
        'staff': user.email ?? 'Staff',
        'changes': changes,
        'time': Timestamp.now(),
      });
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
            'status': effectiveStatus,
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _sectionTitleFontSize,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: _sectionTitleFontSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Lead')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      icon: Icons.person,
                      title: 'Basic Information',
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
                        return DropdownMenuItem(value: b, child: Text(b));
                      }).toList(),
                      onChanged: (val) async {
                        setState(() {
                          selectedBrand = val;
                          selectedModel = null;
                          selectedVariant = null;
                          modelController.clear();
                          variantController.clear();
                          selectedVariantPhotoUrl = null;
                          priceController.clear();
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
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) async {
                        setState(() {
                          selectedModel = val;
                          selectedVariant = null;
                          variantController.clear();
                          selectedVariantPhotoUrl = null;
                          priceController.clear();
                        });

                        modelController.text = val ?? '';
                        await _loadSelectedModelDetails(
                          selectedBrand ?? '',
                          val!,
                        );
                      },
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (selectedVariantPhotoUrl != null &&
                        selectedVariantPhotoUrl!.isNotEmpty) ...[
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
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: priceController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),
                    const SizedBox(height: 12),
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
                      decoration: const InputDecoration(
                        labelText: 'Payment Option',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      icon: Icons.call,
                      title: 'Call Log',
                      trailing: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () async {
                            final phone = phoneController.text.trim();

                            if (phone.isEmpty) {
                              showMessage('Customer phone number missing.');
                              return;
                            }

                            try {
                              await startDirectCall();
                            } catch (e) {
                              showMessage('Could not open phone dialer.');
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (callHistory.isNotEmpty)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCardTitle('Call History'),
                              const SizedBox(height: 14),
                              ...callHistory.reversed
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index =
                                        callHistory.length - 1 - entry.key;
                                    final item = entry.value;
                                    final notes = (item['notes'] ?? '')
                                        .toString()
                                        .trim();

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
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatDate(item['date']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    callHistory.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            'Duration: ${item['duration'] ?? ''}',
                                          ),
                                          if (notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text('Notes: $notes'),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                            ],
                          ),
                        ),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 5),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      icon: Icons.event_repeat,
                      title: 'Follow-up',
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 5),

            if (followUpHistory.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardTitle('Follow-up History'),
                      const SizedBox(height: 14),
                      ...followUpHistory.reversed.toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = followUpHistory.length - 1 - entry.key;
                        final item = entry.value;
                        final comment = (item['comment'] ?? '')
                            .toString()
                            .trim();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(item['date']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        followUpHistory.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(comment),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],

            if (editHistory.isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardTitle('Lead Changes History'),
                      const SizedBox(height: 14),
                      ...editHistory.reversed.map((e) {
                        final changes = List<String>.from(e['changes'] ?? []);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("- $c"),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (e['time'] as Timestamp).toDate().toString(),
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

            const SizedBox(height: 5),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      icon: Icons.flag_outlined,
                      title: 'Status',
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
                                status = 'Closed';
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
                                status = 'Booked';
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
                    : const Text('Save All Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
