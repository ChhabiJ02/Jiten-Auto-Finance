import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../staff/edit_inquiry_screen.dart';

class InquiryListScreen extends StatelessWidget {
  const InquiryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Inquiries"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final inquiries = snapshot.data!.docs;

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
              final isClosed = data['isClosed'] == true;
              final isBooked = data['isBooked'] == true;
              final isCompleted = isClosed || isBooked;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: hasPendingFollowUp && !isCompleted ? Colors.red.shade50 : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(data['name'] ?? ''),
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
                                const TextSpan(text: 'Ref: '),
                                TextSpan(text: data['reference'] ?? ''),
                              ],
                            ),
                          ),
                          if (hasPendingFollowUp && !isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                color: Colors.red.shade100,
                                child: Text(
                                  followUpText,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (isClosed)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Status: CLOSED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isBooked)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Status: BOOKED',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
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
    );
  }
}
