import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ServiceRequestsScreen extends StatelessWidget {
  const ServiceRequestsScreen({super.key});

  Future<void> updateStatus(String id, String status) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    String approvedByName = currentUser?.displayName ?? '';
    if (approvedByName.trim().isEmpty && currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        approvedByName = (userData['name'] ?? approvedByName).toString();
      }
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .snapshots(),
        builder: (context, snapshot) {
          // LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ERROR
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // NO DATA
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No service requests found.'));
          }

          // SORT SAFELY
          final docs = snapshot.data!.docs;

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;

            if (aTime == null || bTime == null) {
              return 0;
            }

            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

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
                        Text('Requested by: $requestedByEmail'),
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

                      Text('Status: ${data['status'] ?? 'Pending'}'),

                      if ((data['approvedByName'] as String?)?.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 4),
                        Text(
                          data['status'] == 'Approved'
                              ? 'Accepted by: ${data['approvedByName']}'
                              : 'Handled by: ${data['approvedByName']}',
                        ),
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
                            onPressed: data['status'] == 'Pending'
                                ? () async {
                                    await updateStatus(id, 'Approved');

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Request accepted'),
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
                            onPressed: data['status'] == 'Pending'
                                ? () async {
                                    await updateStatus(id, 'Rejected');

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Request rejected'),
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
            },
          );
        },
      ),
    );
  }
}
