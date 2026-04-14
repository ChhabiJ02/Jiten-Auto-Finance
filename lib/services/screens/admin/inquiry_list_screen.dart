import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InquiryListScreen extends StatelessWidget {
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
            itemCount: inquiries.length,
            itemBuilder: (context, index) {
              final doc = inquiries[index];

              // ✅ IMPORTANT FIX HERE
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(data['name'] ?? ''),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Phone: ${data['phone'] ?? ''}"),

                      // ✅ HANDLE BOTH brand & vehicle
                      Text(
                        "Vehicle: ${data['brand'] ?? data['vehicle'] ?? 'N/A'}",
                      ),

                      Text("Model: ${data['model'] ?? ''}"),
                      Text("Ref: ${data['reference'] ?? ''}"),
                    ],
                  ),

                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}