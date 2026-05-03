import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/user_settings_screen.dart';
import 'add_inquiry_screen.dart';
import 'edit_inquiry_screen.dart';
import 'service_requests_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String selectedFilter = 'All';
  final filters = ['All', 'New Inquiry', 'Follow Ups', 'Finance', 'Booked'];

  bool _isCreatedToday(Map<String, dynamic> itemData) {
    final createdAt = itemData['createdAt'];
    if (createdAt is! Timestamp) return false;
    
    final createdDate = createdAt.toDate();
    final today = DateTime.now();
    final createdDay = DateTime(createdDate.year, createdDate.month, createdDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    
    return createdDay == todayDay;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSettingsScreen())),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .where('staffId', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.docs;

          final filteredData = selectedFilter == 'All'
              ? data
              : data.where((item) {
                  final itemData = item.data() as Map<String, dynamic>;
                  final status = itemData['status'] as String? ?? 'New Inquiry';
                  
                  // For New Inquiry filter, only show inquiries created today
                  if (selectedFilter == 'New Inquiry') {
                    return status == selectedFilter && _isCreatedToday(itemData);
                  }
                  
                  return status == selectedFilter;
                }).toList();

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Your leads",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.miscellaneous_services_outlined, size: 18),
                      label: const Text('Service Requests'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServiceRequestsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filters.map((filter) {
                          final isSelected = filter == selectedFilter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              selectedColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              labelStyle: TextStyle(
                                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => selectedFilter = filter);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredData.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'No inquiries match "$selectedFilter".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final item = filteredData[index];
                          final itemData = item.data() as Map<String, dynamic>;
                          final status = itemData['status'] as String? ?? 'New Inquiry';
                          final isClosed = itemData['isClosed'] == true;
                          final isBooked = itemData['isBooked'] == true;
                          final isCompleted = isClosed || isBooked || status.toLowerCase() == 'booked' || status.toLowerCase() == 'closed';
                          bool hasOverdueReminder = false;
                          String overdueReminderText = '';

                          final nextFollowUp = itemData['nextFollowUp'];
                          if (nextFollowUp is Timestamp) {
                            final followUpDate = nextFollowUp.toDate();
                            final followUpDay = DateTime(followUpDate.year, followUpDate.month, followUpDate.day);
                            final today = DateTime.now();
                            final todayDay = DateTime(today.year, today.month, today.day);

                            if (!isCompleted && status == 'New Inquiry') {
                              if (followUpDay.isBefore(todayDay)) {
                                hasOverdueReminder = true;
                                overdueReminderText = 'Reminder: follow-up pending since ${followUpDay.toString().split(' ')[0]}';
                              } else if (followUpDay == todayDay) {
                                hasOverdueReminder = true;
                                overdueReminderText = 'Reminder: follow-up due today';
                              }
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.all(10),
                            child: ListTile(
                              title: Text(itemData['name'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "📞 ${itemData['phone'] ?? ''}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "🚗 ${itemData['brand'] ?? ''} ${itemData['model'] ?? ''}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "💰 ₹${itemData['price'] ?? ''}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (nextFollowUp is Timestamp)
                                    Text(
                                      "📅 Follow up: ${nextFollowUp.toDate().toString().split(' ')[0]}",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  if (hasOverdueReminder)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        overdueReminderText,
                                        style: const TextStyle(
                                          color: Colors.red,
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