import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_inquiry_screen.dart';
import 'edit_inquiry_screen.dart';
import 'staff_profile_screen.dart';
import 'service_requests_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {

  String selectedFilter = 'All';

  final filters = [
    'All',
    'New Inquiry',
    'Follow Ups',
    'Finance',
    'Cash',
    'Booked',
    'Closed',
  ];

  bool _isCreatedToday(
    Map<String, dynamic> itemData,
  ) {

    final createdAt =
        itemData['createdAt'];

    if (createdAt is! Timestamp) {
      return false;
    }

    final createdDate =
        createdAt.toDate();

    final today =
        DateTime.now();

    final createdDay = DateTime(
      createdDate.year,
      createdDate.month,
      createdDate.day,
    );

    final todayDay = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return createdDay == todayDay;
  }

  @override
  Widget build(BuildContext context) {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {

      WidgetsBinding.instance
          .addPostFrameCallback((_) {

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      });

      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final staffName =
        user.displayName
                    ?.trim()
                    .isNotEmpty ==
                true
            ? user.displayName!.trim()
            : (user.email
                    ?.split('@')
                    .first ??
                'Staff');

    return Scaffold(

      appBar: AppBar(

        title: Text(
          "Staff Dashboard - $staffName",
        ),

        actions: [

          IconButton(

            onPressed: () async {

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const StaffProfileScreen(),
                ),
              );

              await FirebaseAuth.instance
                  .currentUser
                  ?.reload();

              if (mounted) {
                setState(() {});
              }
            },

            icon: const Icon(
              Icons.settings,
            ),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          // 🔥 FIXED DATA FILTER
          final allData =
              snapshot.data!.docs;

          final data =
              allData.where((item) {

            final itemData =
                item.data()
                    as Map<String, dynamic>;

            final staffId =
              itemData['staffId'];

          final createdBy =
              itemData['createdBy'];

          final assignedTo =
              itemData['assignedTo'];

          return staffId == user.uid ||
              createdBy == user.uid ||
              assignedTo == user.uid;

          }).toList();

          final filteredData =
              selectedFilter == 'All'
                  ? data
                  : data.where((item) {

                      final itemData =
                          item.data()
                              as Map<String, dynamic>;

                      final status =
                          itemData['status']
                                  as String? ??
                              'New Inquiry';

                      final isClosed =
                          itemData['isClosed'] ==
                              true;

                      final isBooked =
                          itemData['isBooked'] ==
                              true;

                      final isCompleted =
                          isClosed ||
                              isBooked ||
                              status
                                      .toLowerCase() ==
                                  'booked' ||
                              status
                                      .toLowerCase() ==
                                  'closed';

                      // NEW INQUIRY
                      if (selectedFilter ==
                          'New Inquiry') {

                        return _isCreatedToday(
                                  itemData,
                                ) &&
                            !isCompleted;
                      }

                      // FINANCE
                      if (selectedFilter ==
                          'Finance') {

                        return itemData[
                                'paymentType'] ==
                            'Loan';
                      }

                      // CASH
                      if (selectedFilter ==
                          'Cash') {

                        return itemData[
                                'paymentType'] ==
                            'Cash';
                      }

                      // BOOKED
                      if (selectedFilter ==
                          'Booked') {

                        return isBooked ||
                            status.toLowerCase() ==
                                'booked';
                      }

                      // CLOSED
                      if (selectedFilter ==
                          'Closed') {

                        return isClosed ||
                            status.toLowerCase() ==
                                'closed';
                      }

                      // FOLLOW UPS
                      if (selectedFilter ==
                          'Follow Ups') {

                        final nextFollowUp =
                            itemData[
                                'nextFollowUp'];

                        if (nextFollowUp
                            is Timestamp) {

                          final followUpDate =
                              nextFollowUp
                                  .toDate();

                          final followUpDay =
                              DateTime(
                            followUpDate.year,
                            followUpDate.month,
                            followUpDate.day,
                          );

                          final today =
                              DateTime.now();

                          final todayDay =
                              DateTime(
                            today.year,
                            today.month,
                            today.day,
                          );

                          return !isCompleted &&
                              status ==
                                  'New Inquiry' &&
                              (
                                followUpDay
                                        .isBefore(
                                            todayDay) ||
                                    followUpDay ==
                                        todayDay
                              );
                        }

                        return false;
                      }

                      return status ==
                          selectedFilter;

                    }).toList();

          filteredData.sort((a, b) {

            final aData =
                a.data()
                    as Map<String, dynamic>;

            final bData =
                b.data()
                    as Map<String, dynamic>;

            final aCreated =
                aData['createdAt'];

            final bCreated =
                bData['createdAt'];

            DateTime aTime =
                DateTime(2000);

            DateTime bTime =
                DateTime(2000);

            if (aCreated
                is Timestamp) {

              aTime =
                  aCreated.toDate();
            }

            if (bCreated
                is Timestamp) {

              bTime =
                  bCreated.toDate();
            }

            return bTime.compareTo(
              aTime,
            );
          });

          if (data.isEmpty) {

            return Column(

              mainAxisAlignment:
                  MainAxisAlignment
                      .center,

              children: const [

                Padding(

                  padding:
                      EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  child: Text(
                    "Your leads",

                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                Center(
                  child: Text(
                    "No inquiries yet",
                  ),
                ),
              ],
            );
          }

          return Column(

            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [

              Padding(

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),

                child: Row(

                  children: [

                    const Expanded(

                      child: Text(
                        "Your leads",

                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    TextButton.icon(

                      style:
                          TextButton.styleFrom(

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),

                        minimumSize:
                            const Size(
                          0,
                          36,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        backgroundColor:
                            Theme.of(context)
                                .colorScheme
                                .primary,

                        foregroundColor:
                            Colors.white,
                      ),

                      icon: const Icon(
                        Icons
                            .miscellaneous_services_outlined,
                        size: 18,
                      ),

                      label: const Text(
                        'Service Requests',
                      ),

                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ServiceRequestsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              Padding(

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                child: Card(

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  elevation: 3,

                  child: Padding(

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),

                    child:
                        SingleChildScrollView(

                      scrollDirection:
                          Axis.horizontal,

                      child: Row(

                        children:
                            filters.map((filter) {

                          final isSelected =
                              filter ==
                                  selectedFilter;

                          return Padding(

                            padding:
                                const EdgeInsets.only(
                              right: 8,
                            ),

                            child: ChoiceChip(

                              label:
                                  Text(filter),

                              selected:
                                  isSelected,

                              selectedColor:
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,

                              backgroundColor:
                                  Theme.of(context)
                                      .colorScheme
                                      .surface,

                              labelStyle:
                                  TextStyle(

                                color:
                                    isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                              ),

                              onSelected:
                                  (selected) {

                                if (selected) {

                                  setState(() {

                                    selectedFilter =
                                        filter;
                                  });
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

                child:
                    filteredData.isEmpty

                        ? Center(

                            child: Padding(

                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 24,
                              ),

                              child: Text(

                                'No inquiries match "$selectedFilter".',

                                textAlign:
                                    TextAlign
                                        .center,

                                style:
                                    const TextStyle(
                                  fontSize: 16,
                                  color:
                                      Colors.black54,
                                ),
                              ),
                            ),
                          )

                        : ListView.builder(

                            itemCount:
                                filteredData.length,

                            itemBuilder:
                                (context, index) {

                              final item =
                                  filteredData[
                                      index];

                              final itemData =
                                  item.data()
                                      as Map<String, dynamic>;

                              final status =
                                  itemData['status']
                                          as String? ??
                                      'New Inquiry';

                              final isClosed =
                                  itemData[
                                          'isClosed'] ==
                                      true;

                              final isBooked =
                                  itemData[
                                          'isBooked'] ==
                                      true;

                              final isCompleted =
                                  isClosed ||
                                      isBooked ||
                                      status
                                              .toLowerCase() ==
                                          'booked' ||
                                      status
                                              .toLowerCase() ==
                                          'closed';

                              bool hasOverdueReminder =
                                  false;

                              String overdueReminderText =
                                  '';

                              final nextFollowUp =
                                  itemData[
                                      'nextFollowUp'];

                              if (nextFollowUp
                                  is Timestamp) {

                                final followUpDate =
                                    nextFollowUp
                                        .toDate();

                                final followUpDay =
                                    DateTime(
                                  followUpDate.year,
                                  followUpDate.month,
                                  followUpDate.day,
                                );

                                final today =
                                    DateTime.now();

                                final todayDay =
                                    DateTime(
                                  today.year,
                                  today.month,
                                  today.day,
                                );

                                if (!isCompleted &&
                                    status ==
                                        'New Inquiry') {

                                  if (followUpDay
                                      .isBefore(
                                          todayDay)) {

                                    hasOverdueReminder =
                                        true;

                                    overdueReminderText =
                                        'Reminder: follow-up pending since ${followUpDay.toString().split(' ')[0]}';

                                  } else if (followUpDay ==
                                      todayDay) {

                                    hasOverdueReminder =
                                        true;

                                    overdueReminderText =
                                        'Reminder: follow-up due today';
                                  }
                                }
                              }

                              return Card(

                                margin:
                                    const EdgeInsets
                                        .all(10),

                                child: ListTile(

                                  title: Text(
                                    itemData['name'] ??
                                        '',
                                  ),

                                  subtitle: Column(

                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [

                                      Text(
                                        "📞 ${itemData['phone'] ?? ''}",

                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      Text(
                                        "🚗 ${itemData['brand'] ?? ''} ${itemData['model'] ?? ''}",

                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      Text(
                                        "💰 ₹${itemData['price'] ?? ''}",

                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      if (nextFollowUp
                                          is Timestamp)

                                        Text(
                                          "📅 Follow up: ${nextFollowUp.toDate().toString().split(' ')[0]}",

                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),

                                      if (hasOverdueReminder)

                                        Padding(

                                          padding:
                                              const EdgeInsets.only(
                                            top: 6,
                                          ),

                                          child: Text(

                                            overdueReminderText,

                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.red,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  trailing:
                                      const Icon(
                                    Icons.edit,
                                  ),

                                  onTap: () {

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInquiryScreen(
                                          inquiry:
                                              item,
                                        ),
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

      floatingActionButton:
          FloatingActionButton(

        backgroundColor:
            Theme.of(context)
                .colorScheme
                .primary,

        foregroundColor:
            Colors.white,

        onPressed: () {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddInquiryScreen(),
            ),
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