import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:showroom_app/services/auth_service.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  final _authService = AuthService();
  String selectedTab = 'Service Requests';
  final tabs = ['Service Requests', 'Customer Inquiries'];

  Future<String> _fetchCurrentUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    String name = currentUser?.displayName ?? '';
    if (name.trim().isEmpty && currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        name = (userData['name'] ?? name).toString();
      }
    }
    return name.isNotEmpty ? name : 'Staff';
  }

  Future<void> updateStatus(String id, String status) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final approvedByName = await _fetchCurrentUserName();

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(id)
        .update({
      'status': status,
      'approvedBy': currentUser?.uid,
      'approvedByName': approvedByName.isNotEmpty ? approvedByName : null,
      'approvedAt': Timestamp.now(),
    });
  }

  Future<void> acceptInquiry(String id) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user is currently signed in',
      );
    }

    final acceptedByName = await _fetchCurrentUserName();

    await FirebaseFirestore.instance.collection('inquiries').doc(id).update({
      'assignedTo': currentUser.uid,
      'staffId': currentUser.uid,
      'acceptedBy': currentUser.uid,
      'acceptedByName': acceptedByName.isNotEmpty ? acceptedByName : null,
      'acceptedAt': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> _getCurrentStream() {
    if (selectedTab == 'Customer Inquiries') {
      return FirebaseFirestore.instance.collection('inquiries').snapshots();
    }
    return FirebaseFirestore.instance.collection('serviceRequests').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((tab) {
                  final isSelected = tab == selectedTab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedTab = tab;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getCurrentStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      selectedTab == 'Service Requests'
                          ? 'No service requests found.'
                          : 'No customer inquiries found.',
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final items = selectedTab == 'Service Requests'
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status =
                            (data['status'] ?? 'New Inquiry').toString().toLowerCase();
                        final accepted =
                            (data['acceptedBy'] as String?)?.isNotEmpty ?? false;
                        final createdByCustomer = data['createdByCustomer'] == true;
                        return status == 'new inquiry' &&
                            !accepted &&
                            createdByCustomer;
                      }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      selectedTab == 'Service Requests'
                          ? 'No service requests found.'
                          : 'No pending customer inquiries to accept.',
                    ),
                  );
                }

                items.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final data = items[index].data() as Map<String, dynamic>;
                    final id = items[index].id;

                    if (selectedTab == 'Service Requests') {
                      final preferredDate = data['preferredDate'];
                      final dateText = preferredDate is Timestamp
                          ? preferredDate.toDate().toString().split(' ')[0]
                          : 'N/A';
                      final requestedByName =
                          (data['requestedByName'] ??
                                  data['customerName'] ??
                                  data['customerEmail'] ??
                                  'Customer')
                              .toString();
                      final requestedByEmail =
                          (data['requestedByEmail'] ?? data['customerEmail'] ?? '')
                              .toString();
                      final variant = (data['variant'] ?? '').toString().trim();
                      final vehicleText = [
                        (data['vehicleBrand'] ?? '').toString().trim(),
                        (data['vehicleModel'] ?? '').toString().trim(),
                        if (variant.isNotEmpty) variant,
                      ].where((part) => part.isNotEmpty).join(' ');
                      final boughtFromUs = data['boughtFromUs'] as bool? ?? false;
                      final approvedByName =
                          (data['approvedByName'] as String?)?.toString() ?? '';
                      final status = (data['status'] ?? 'Pending').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                requestedByName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (requestedByEmail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Email: $requestedByEmail'),
                              ],
                              if ((data['customerPhone'] as String?)?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 4),
                                Text('Phone: ${data['customerPhone']}'),
                              ],
                              const SizedBox(height: 8),
                              Text('Vehicle: $vehicleText'),
                              Text('Service Type: ${data['serviceType'] ?? 'N/A'}'),
                              Text('Preferred Date: $dateText'),
                              Text('Status: $status'),
                              if (approvedByName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Accepted by admin: $approvedByName'),
                              ],
                              if (boughtFromUs) ...[
                                const SizedBox(height: 8),
                                const Text('Bought from us: Yes'),
                                Text('Package: ${data['servicePackage'] ?? 'N/A'}'),
                                Text(
                                  'Left Services: ${data['remainingServices'] ?? 'N/A'}',
                                ),
                              ],
                              if ((data['notes'] as String?)?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 8),
                                Text('Notes: ${data['notes']}'),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: status == 'Pending'
                                        ? () async {
                                            await updateStatus(id, 'Approved');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Request accepted'),
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                    child: const Text('Accept'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: status == 'Pending'
                                        ? () async {
                                            await updateStatus(id, 'Rejected');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Request rejected'),
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final name = (data['name'] ?? 'Customer').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final email = (data['customerEmail'] ?? '').toString();
                    final vehicleText = [
                      (data['brand'] ?? '').toString().trim(),
                      (data['model'] ?? '').toString().trim(),
                      (data['variant'] ?? '').toString().trim(),
                    ].where((part) => part.isNotEmpty).join(' ');
                    final acceptedByName =
                        (data['acceptedByName'] as String?)?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Email: $email'),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Phone: $phone'),
                            ],
                            const SizedBox(height: 8),
                            Text('Vehicle: $vehicleText'),
                            Text('Status: ${data['status'] ?? 'New Inquiry'}'),
                            if (acceptedByName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Accepted by admin: $acceptedByName'),
                            ],
                            if ((data['notes'] as String?)?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 8),
                              Text('Notes: ${data['notes']}'),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: acceptedByName.isEmpty
                                      ? () async {
                                          await acceptInquiry(id);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Inquiry accepted'),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  child: Text(
                                    acceptedByName.isEmpty ? 'Accept' : 'Accepted',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
