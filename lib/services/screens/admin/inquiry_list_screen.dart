import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../staff/edit_inquiry_screen.dart';

class InquiryListScreen extends StatefulWidget {
  const InquiryListScreen({super.key});

  @override
  State<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends State<InquiryListScreen> {
  String? selectedStaffId;
  List<Map<String, dynamic>> staffList = [];
  Set<String> selectedInquiries = {};
  bool isSelectionMode = false;
  bool isAssigningLeads = false;

  String _normalizeRole(String? role) {
    final normalizedRole =
        role?.trim().toLowerCase() ?? '';

    if (normalizedRole == 'workshop') {
      return 'staff';
    }

    return normalizedRole;
  }

  bool _matchesStaffLead(
    Map<String, dynamic> data,
    String staffId,
  ) {
    final ownerValues = [
      data['staffId'],
      data['assignedTo'],
      data['createdBy'],
    ];

    return ownerValues.any(
      (value) => value?.toString().trim() == staffId,
    );
  }

  String _resolveStaffOwnerId(
    Map<String, dynamic> data,
  ) {
    final candidateValues = [
      data['assignedTo'],
      data['staffId'],
      data['createdBy'],
    ];

    for (final value in candidateValues) {
      final normalized = value?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  String _getStaffNameById(String staffId) {
    final staffMember = staffList.firstWhere(
      (staff) => staff['id'] == staffId,
      orElse: () => {
        'id': staffId,
        'name': 'Selected Staff',
      },
    );

    return (staffMember['name'] ?? 'Selected Staff').toString();
  }

  @override
  void initState() {
    super.initState();
    _loadStaffList();
    _assignUnassignedInquiries();
  }

  Future<void> _assignUnassignedInquiries() async {
    try {
      // Wait for staff list to load
      await Future.delayed(const Duration(seconds: 1));

      if (staffList.isEmpty) {
        return;
      }

      // Don't automatically assign - each inquiry should keep its original staffId
      // This function is now just for validation/cleanup if needed
    } catch (e) {
      print('Error in inquiry assignment validation: $e');
    }
  }

  Future<void> _loadStaffList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final uniqueStaff = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = _normalizeRole(
          data['role']?.toString(),
        );
        final isDisabled = data['isDisabled'] == true;
        if (role == 'staff' && !isDisabled) {
          final name = data['name'] ?? 'Unknown Staff';
          final uid = data['uid']?.toString().trim();
          final resolvedId =
              uid != null && uid.isNotEmpty ? uid : doc.id;

          uniqueStaff[resolvedId] = {
            'id': resolvedId,
            'name': name,
          };
        }
      }

      setState(() {
        staffList = uniqueStaff.values.toList();
      });
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }


  void _toggleSelection(String inquiryId) {
    setState(() {
      if (selectedInquiries.contains(inquiryId)) {
        selectedInquiries.remove(inquiryId);
      } else {
        selectedInquiries.add(inquiryId);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedInquiries.clear();
      }
    });
  }

  Future<void> _makeCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendBulkWhatsApp() async {
    if (selectedInquiries.isEmpty) return;

    try {
      final inquiries = await FirebaseFirestore.instance
          .collection('inquiries')
          .where(FieldPath.documentId, whereIn: selectedInquiries.toList())
          .get();

      String message = 'Hello! We have some updates regarding your vehicle inquiry.';
      List<String> phoneNumbers = [];

      for (var doc in inquiries.docs) {
        final data = doc.data();
        final phone = data['phone']?.toString().trim() ?? '';
        if (phone.isNotEmpty) {
          // Clean phone number
          String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (cleanPhone.length == 10) {
            cleanPhone = '91$cleanPhone';
          }
          if (cleanPhone.length >= 10) {
            phoneNumbers.add(cleanPhone);
          }
        }
      }

      if (phoneNumbers.isNotEmpty) {
        // For bulk messaging, we'll send individual messages
        for (String phone in phoneNumbers) {
          final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
            // Small delay between launches
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp opened for ${phoneNumbers.length} contacts')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone numbers found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending WhatsApp: $e')),
      );
    }
  }

  Future<void> _showAssignSelectedLeadsDialog() async {
    if (selectedInquiries.isEmpty) {
      return;
    }

    if (staffList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No staff members available for assignment'),
        ),
      );
      return;
    }

    String? selectedAssigneeId;

    final assignedStaffId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Selected Leads'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign ${selectedInquiries.length} selected lead(s) to:',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedAssigneeId,
                hint: const Text('Select Staff'),
                items: staffList.map((staff) {
                  return DropdownMenuItem<String>(
                    value: staff['id'] as String,
                    child: Text(
                      (staff['name'] ?? 'Unknown Staff').toString(),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedAssigneeId = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedAssigneeId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a staff member first'),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  selectedAssigneeId,
                );
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (assignedStaffId == null) {
      return;
    }

    await _assignSelectedLeads(assignedStaffId);
  }

  Future<void> _assignSelectedLeads(String newStaffId) async {
    if (selectedInquiries.isEmpty) {
      return;
    }

    final inquiryIds = selectedInquiries.toList(growable: false);
    final assignedAt = Timestamp.now();

    setState(() {
      isAssigningLeads = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      int pendingWrites = 0;

      for (final inquiryId in inquiryIds) {
        final inquiryRef =
            firestore.collection('inquiries').doc(inquiryId);

        batch.update(inquiryRef, {
          'staffId': newStaffId,
          'assignedTo': newStaffId,
          'createdBy': newStaffId,
          'lastAssignedAt': assignedAt,
          'lastAssignedTo': newStaffId,
        });

        pendingWrites++;

        if (pendingWrites == 400) {
          await batch.commit();
          batch = firestore.batch();
          pendingWrites = 0;
        }
      }

      if (pendingWrites > 0) {
        await batch.commit();
      }

      if (!mounted) return;

      final assignedStaffName = _getStaffNameById(newStaffId);

      setState(() {
        isAssigningLeads = false;
        isSelectionMode = false;
        selectedInquiries.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${inquiryIds.length} lead(s) assigned to $assignedStaffName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isAssigningLeads = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to assign selected leads: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Inquiries"),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: isAssigningLeads
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_ind_outlined),
              onPressed: selectedInquiries.isNotEmpty && !isAssigningLeads
                  ? _showAssignSelectedLeadsDialog
                  : null,
              tooltip: 'Assign selected leads',
            ),
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: selectedInquiries.isNotEmpty && !isAssigningLeads
                  ? _sendBulkWhatsApp
                  : null,
              tooltip: 'Send WhatsApp to selected',
            ),
          IconButton(
            icon: Icon(isSelectionMode ? Icons.cancel : Icons.checklist),
            onPressed: isAssigningLeads ? null : _toggleSelectionMode,
            tooltip: isSelectionMode ? 'Cancel selection' : 'Select multiple',
          ),
        ],
      ),
      body: Column(
        children: [
          // Staff Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<String?>(
              initialValue: selectedStaffId,
              decoration: const InputDecoration(
                labelText: 'Filter by Staff',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Staff'),
                ),
                ...staffList.map((staff) => DropdownMenuItem<String?>(
                  value: staff['id'],
                  child: Text(staff['name']),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  selectedStaffId = value;
                });
              },
            ),
          ),
          // Staff Lead Counts
          if (staffList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: staffList.map((staff) {
                  return FutureBuilder<int>(
                    future: _getStaffLeadCount(staff['id']),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Chip(
                        label: Text('${staff['name']}: $count leads'),
                        backgroundColor: selectedStaffId == staff['id']
                            ? Colors.blue.withValues(alpha: 0.2)
                            : null,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inquiries')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allInquiries = snapshot.data!.docs;

                // Filter by selected staff
                final inquiries = selectedStaffId == null
                    ? allInquiries
                    : allInquiries.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _matchesStaffLead(
                          data,
                          selectedStaffId!,
                        );
                      }).toList();

                if (inquiries.isEmpty) {
                  return const Center(child: Text("No inquiries yet"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: inquiries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Inquiries',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      inquiries.length.toString(),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.list_alt, size: 32, color: Colors.blueAccent),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final doc = inquiries[index - 1];
                    final data = doc.data() as Map<String, dynamic>;

                    // Check if follow-up is pending
                    bool hasPendingFollowUp = false;
                    String followUpText = '';

                    final nextFollowUp = data['nextFollowUp'];
                    if (nextFollowUp is Timestamp) {
                      final followUpDate = nextFollowUp.toDate();
                      final today = DateTime.now();
                      // Reset time for comparison
                      final todayWithoutTime = DateTime(today.year, today.month, today.day);
                      final followUpDateWithoutTime = DateTime(followUpDate.year, followUpDate.month, followUpDate.day);

                      if (followUpDateWithoutTime.isBefore(todayWithoutTime)) {
                        hasPendingFollowUp = true;
                        followUpText = 'Follow-up pending since ${followUpDateWithoutTime.toString().split(' ')[0]}';
                      } else if (followUpDateWithoutTime.year == todayWithoutTime.year &&
                                 followUpDateWithoutTime.month == todayWithoutTime.month &&
                                 followUpDateWithoutTime.day == todayWithoutTime.day) {
                        hasPendingFollowUp = true;
                        followUpText = 'Follow-up due today';
                      }
                    }

                    // Check if lead is closed or booked
                    final status = data['status'] as String? ?? 'New Inquiry';
                    final isClosed = data['isClosed'] == true;
                    final isBooked = data['isBooked'] == true;
                    final isCompleted = isClosed || isBooked || status.toLowerCase() == 'booked' || status.toLowerCase() == 'closed';

                    // Get staff name from loaded staffList
                    String staffName = 'Unassigned';
                    final ownerId = _resolveStaffOwnerId(data);
                    if (ownerId.isNotEmpty) {
                      final staffMember = staffList.firstWhere(
                        (staff) => staff['id'] == ownerId,
                        orElse: () => {
                          'id': ownerId,
                          'name': 'Unknown Staff',
                        },
                      );
                      staffName = staffMember['name'] ?? 'Unknown Staff';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: isSelectionMode
                                ? Checkbox(
                                    value: selectedInquiries.contains(doc.id),
                                    onChanged: (value) => _toggleSelection(doc.id),
                                  )
                                : null,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(data['name'] ?? ''),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status, isClosed, isBooked),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(status, isClosed, isBooked),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    children: [
                                      const TextSpan(text: 'Phone: '),
                                      TextSpan(text: data['phone'] ?? ''),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    children: [
                                      const TextSpan(text: 'Vehicle: '),
                                      TextSpan(text: data['brand'] ?? data['vehicle'] ?? 'N/A'),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    children: [
                                      const TextSpan(text: 'Model: '),
                                      TextSpan(text: data['model'] ?? ''),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    children: [
                                      const TextSpan(text: 'Staff: '),
                                      TextSpan(text: staffName),
                                    ],
                                  ),
                                ),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _getCallHistory(doc.id),
                                  builder: (context, callSnapshot) {
                                    final calls = callSnapshot.data ?? [];
                                    if (calls.isNotEmpty) {
                                      final lastCall = calls.last;
                                      final duration = lastCall['duration'] ?? 'N/A';
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text.rich(
                                          TextSpan(
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            children: [
                                              const TextSpan(text: 'Last call: '),
                                              TextSpan(text: duration),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                if (hasPendingFollowUp && !isCompleted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      followUpText,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call, color: Colors.green),
                                  onPressed: () => _makeCall(data['phone'] ?? ''),
                                  tooltip: 'Call customer',
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            onTap: isSelectionMode
                                ? () => _toggleSelection(doc.id)
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditInquiryScreen(inquiry: doc),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getStaffLeadCount(String staffId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('inquiries')
          .get();

      return snapshot.docs.where((doc) {
        final data = doc.data();
        return _matchesStaffLead(data, staffId);
      }).length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _getCallHistory(String inquiryId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('inquiries')
          .doc(inquiryId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final calls = data?['callHistory'];
        if (calls is List) {
          return List<Map<String, dynamic>>.from(calls);
        }
      }
    } catch (e) {
      print('Error getting call history: $e');
    }
    return [];
  }

  Color _getStatusColor(String status, bool isClosed, bool isBooked) {
    if (isBooked) return Colors.green;
    if (isClosed) return Colors.red;
    switch (status.toLowerCase()) {
      case 'new inquiry':
        return Colors.blue;
      case 'follow ups':
        return Colors.orange;
      case 'finance':
        return Colors.purple;
      case 'booked':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, bool isClosed, bool isBooked) {
    if (isBooked) return 'BOOKED';
    if (isClosed) return 'CLOSED';
    return status.toUpperCase();
  }
}
