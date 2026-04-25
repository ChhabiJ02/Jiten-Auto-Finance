import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'book_service_screen.dart';

class MyServicePlanScreen extends StatelessWidget {
  const MyServicePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Service Plan')),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('serviceRequests')
                  .where('userId', isEqualTo: user.uid)
                  .where('boughtFromUs', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No purchased vehicles found.'),
                        const SizedBox(height: 12),
                        const Text('If you bought a vehicle from JitenAuto, book a service appointment and track left services here.'),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookServiceScreen()));
                          },
                          child: const Text('Book Service Appointment'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final remaining = data['remainingServices'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['vehicleBrand'] ?? ''} ${data['vehicleModel'] ?? ''}'.trim(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Package: ${data['servicePackage'] ?? 'N/A'}'),
                            Text('Left Services: ${remaining ?? 'N/A'}'),
                            Text('Preferred Date: ${data['preferredDate'] is Timestamp ? (data['preferredDate'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}'),
                            Text('Status: ${data['status'] ?? 'Pending'}'),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const BookServiceScreen()));
                              },
                              child: const Text('Renew Service / Book Again'),
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
