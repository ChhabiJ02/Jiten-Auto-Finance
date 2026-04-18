import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Service Appointments')),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('serviceRequests')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No service appointments found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final preferredDate = data['preferredDate'];
                    final preferredDateText = preferredDate is Timestamp
                        ? preferredDate.toDate().toString().split(' ')[0]
                        : 'Not set';
                    final boughtFromUs = data['boughtFromUs'] as bool? ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['serviceType'] as String? ?? 'Service',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text('Vehicle: ${data['vehicleBrand'] ?? ''} ${data['vehicleModel'] ?? ''} ${data['variant'] ?? ''}'.trim()),
                            Text('Reg. No: ${data['registrationNumber'] ?? 'N/A'}'),
                            Text('Preferred Date: $preferredDateText'),
                            Text('Status: ${data['status'] ?? 'Pending'}'),
                            if (boughtFromUs) ...[
                              const SizedBox(height: 8),
                              Text('Bought from us: Yes'),
                              Text('Service Package: ${data['servicePackage'] ?? 'N/A'}'),
                              Text('Left Services: ${data['remainingServices'] ?? 'N/A'}'),
                            ],
                            if ((data['notes'] as String?)?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 8),
                              Text('Notes: ${data['notes']}'),
                            ],
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
