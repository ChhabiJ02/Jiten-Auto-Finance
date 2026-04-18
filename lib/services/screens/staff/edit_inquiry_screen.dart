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
  late final TextEditingController followUpCommentController;
  late final TextEditingController otherController;
  late String paymentType;
  late String status;
  late DateTime selectedDate;
  late DateTime newFollowUpDate;
  bool loading = false;
  bool isClosed = false;
  bool isBooked = false;
  List<Map<String, dynamic>> followUpHistory = [];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    descriptionController = TextEditingController(text: data['description'] ?? '');
    referenceController = TextEditingController(text: data['reference'] ?? '');
    followUpCommentController = TextEditingController();
    otherController = TextEditingController(text: data['otherDescription'] ?? '');
    paymentType = data['paymentType'] ?? 'Loan';
    status = data['status'] ?? 'New Inquiry';
    final nextFollowUp = data['nextFollowUp'];
    selectedDate = nextFollowUp is Timestamp
        ? nextFollowUp.toDate()
        : DateTime.now();
    
    newFollowUpDate = DateTime.now();
    
    // Load follow-up history
    final history = data['followUpHistory'];
    if (history is List) {
      followUpHistory = List<Map<String, dynamic>>.from(history);
    }
    
    // Load status
    isClosed = data['isClosed'] == true;
    isBooked = data['isBooked'] == true;
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
    followUpCommentController.dispose();
    otherController.dispose();
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

  Future<void> _saveChanges() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final variant = variantController.text.trim();
    final price = priceController.text.trim();
    final description = descriptionController.text.trim();
    final reference = referenceController.text.trim();
    final otherDescription = otherController.text.trim();

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showMessage('Unable to save inquiry: user not signed in.');
        return;
      }

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
        'status': status,
        'nextFollowUp': Timestamp.fromDate(selectedDate),
        'followUpHistory': followUpHistory,
        'isClosed': isClosed,
        'isBooked': isBooked,
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

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
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
                    const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    TextField(
                      controller: brandController,
                      decoration: const InputDecoration(labelText: 'Vehicle Brand'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: variantController,
                      decoration: const InputDecoration(labelText: 'Variant'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Vehicle Description'),
                      maxLines: 3,
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
                      decoration: const InputDecoration(labelText: 'Payment Option'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Other Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'New Inquiry', child: Text('New Inquiry')),
                        DropdownMenuItem(value: 'Follow Ups', child: Text('Follow Ups')),
                        DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                        DropdownMenuItem(value: 'Booked', child: Text('Booked')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => status = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Inquiry Status'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Follow up: ${selectedDate.toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickFollowUpDate,
                          child: const Text('Change'),
                        ),
                      ],
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
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isClosed,
                          onChanged: (value) {
                            setState(() {
                              isClosed = value ?? false;
                              if (isClosed) isBooked = false; // Can't be both closed and booked
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
                              if (isBooked) isClosed = false; // Can't be both booked and closed
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
                    const Text('Add New Follow-up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

            // Follow-up History Section
            if (followUpHistory.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Follow-up History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      ...followUpHistory.map((followUp) {
                        final date = followUp['date'] is Timestamp 
                            ? (followUp['date'] as Timestamp).toDate()
                            : DateTime.now();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Date: ${date.toString().split(' ')[0]}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Added: ${followUp['createdAt'] is Timestamp ? (followUp['createdAt'] as Timestamp).toDate().toString().split(' ')[0] : ''}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(followUp['comment'] ?? ''),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

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