import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_inquiry_screen.dart';
import 'edit_inquiry_screen.dart';

class StaffDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .where('createdBy', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.docs;

          if (data.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "Your leads",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16),
                Center(child: Text("No inquiries yet")),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Text(
                  "Your leads",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final dataMap = item.data() as Map<String, dynamic>;

                    // Check if follow-up is pending
                    bool hasPendingFollowUp = false;
                    String followUpText = '';
                    
                    final nextFollowUp = dataMap['nextFollowUp'];
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
                    final isClosed = dataMap['isClosed'] == true;
                    final isBooked = dataMap['isBooked'] == true;
                    final isCompleted = isClosed || isBooked;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      color: hasPendingFollowUp && !isCompleted ? Colors.red.shade50 : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(dataMap['name'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "📞 ${dataMap['phone'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "🚗 ${dataMap['brand'] ?? dataMap['vehicle'] ?? 'N/A'} ${dataMap['model'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "💰 ₹${dataMap['price'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "📅 Follow up: ${nextFollowUp is Timestamp ? nextFollowUp.toDate().toString().split(' ')[0] : ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                            trailing: const Icon(Icons.edit),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditInquiryScreen(inquiry: item),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddInquiryScreen()),
          );
        },
        child: const Icon(
          Icons.add,
          size: 30,
        ),
      ),
    );
  }
}
