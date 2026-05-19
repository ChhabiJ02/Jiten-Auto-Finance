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
  bool selectionMode = false;

  Set<String> selectedInquiryIds = {};

  String? selectedBrandFilter;
  String? selectedModelFilter;
  String? selectedExchangeName;

  final filters = [
    'All',
    'New Inquiry',
    'Follow Ups',
    'Finance',
    'Cash',
    'Booked',
    'Closed',
  ];

  bool _matchesCurrentUserLead(
    Map<String, dynamic> itemData,
    User user,
  ) {
    final ownerValues = [
      itemData['staffId'],
      itemData['createdBy'],
      itemData['assignedTo'],
    ];

    return ownerValues.any(
      (value) => value?.toString().trim() == user.uid,
    );
  }

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

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  bool _isCompletedInquiry(
    Map<String, dynamic> itemData,
  ) {
    final status =
        itemData['status']
                as String? ??
            'New Inquiry';

    final isClosed =
        itemData['isClosed'] == true;

    final isBooked =
        itemData['isBooked'] == true;

    return isClosed ||
        isBooked ||
        status.toLowerCase() ==
            'booked' ||
        status.toLowerCase() ==
            'closed';
  }

  DateTime? _followUpDay(
    Map<String, dynamic> itemData,
  ) {
    final nextFollowUp = itemData['nextFollowUp'];

    if (nextFollowUp is Timestamp) {
      return _dateOnly(nextFollowUp.toDate());
    }
    if (nextFollowUp is DateTime) {
      return _dateOnly(nextFollowUp);
    }
    if (nextFollowUp is String) {
      try {
        return _dateOnly(DateTime.parse(nextFollowUp));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _hasDueFollowUp(
    Map<String, dynamic> itemData,
  ) {
    final followUpDay =
        _followUpDay(itemData);

    if (followUpDay == null ||
        _isCompletedInquiry(itemData)) {
      return false;
    }

    final todayDay = _dateOnly(
      DateTime.now(),
    );

    return !followUpDay.isAfter(
      todayDay,
    );
  }

  String? _followUpReminderText(
    Map<String, dynamic> itemData,
  ) {
    final followUpDay =
        _followUpDay(itemData);

    if (followUpDay == null ||
        !_hasDueFollowUp(itemData)) {
      return null;
    }

    final todayDay = _dateOnly(
      DateTime.now(),
    );

    if (followUpDay.isBefore(
      todayDay,
    )) {
      return 'Reminder: follow-up pending since ${followUpDay.toString().split(' ')[0]}';
    }

    return 'Reminder: follow-up due today';
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
    (user.displayName != null &&
            user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : 'Staff';

        if ((user.displayName == null ||
                user.displayName!.trim().isEmpty)) {

          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .then((doc) async {

            if (doc.exists) {

              final data =
                  doc.data() as Map<String, dynamic>;

              final firestoreName =
                  (data['name'] ?? '')
                      .toString()
                      .trim();

              if (firestoreName.isNotEmpty) {

                await user.updateDisplayName(
                  firestoreName,
                );

                await user.reload();

                if (mounted) {
                  setState(() {});
                }
              }
            }
          });
        }

    return Scaffold(

      appBar: AppBar(

        title: Text(
          selectionMode
              ? "${selectedInquiryIds.length} Selected"
              : "$staffName",
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.miscellaneous_services_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ServiceRequestsScreen(),
                ),
              );
            },
          ),

          if (selectionMode)

            IconButton(

              icon: const Icon(Icons.delete),

              onPressed: () async {

                final confirm =
                    await showDialog<bool>(

                  context: context,

                  builder: (context) {

                    return AlertDialog(

                      title: const Text(
                        "Delete Leads",
                      ),

                      content: Text(
                        "Delete ${selectedInquiryIds.length} selected lead(s)?",
                      ),

                      actions: [

                        TextButton(

                          onPressed: () {

                            Navigator.pop(
                              context,
                              false,
                            );
                          },

                          child: const Text(
                            "Cancel",
                          ),
                        ),

                        ElevatedButton(

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.red,
                          ),

                          onPressed: () {

                            Navigator.pop(
                              context,
                              true,
                            );
                          },

                          child: const Text(
                            "Delete",
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {

                  for (final id
                      in selectedInquiryIds) {

                    await FirebaseFirestore
                        .instance
                        .collection('inquiries')
                        .doc(id)
                        .delete();
                  }

                  setState(() {

                    selectedInquiryIds
                        .clear();

                    selectionMode = false;
                  });

                  if (mounted) {

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(

                      const SnackBar(
                        content: Text(
                          "Leads deleted successfully",
                        ),
                      ),
                    );
                  }
                }
              },
            ),

          if (!selectionMode)

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

            return _matchesCurrentUserLead(
              itemData,
              user,
            );

          }).toList();

            var filteredData =
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

                      final isCompleted =
                          _isCompletedInquiry(
                        itemData,
                      );

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

                      final isClosed = itemData['isClosed'] == true;
                      final isBooked = itemData['isBooked'] == true;

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
                        return _hasDueFollowUp(
                          itemData,
                        );
                      }

                      return status ==
                            selectedFilter;

                    }).toList();

            // apply brand/model/exchange filters
            if (selectedBrandFilter != null && selectedBrandFilter!.isNotEmpty) {
              filteredData = filteredData.where((item) {
                final d = (item.data() as Map<String, dynamic>);
                return (d['brand'] ?? '').toString() == selectedBrandFilter;
              }).toList();
            }

            if (selectedModelFilter != null && selectedModelFilter!.isNotEmpty) {
              filteredData = filteredData.where((item) {
                final d = (item.data() as Map<String, dynamic>);
                return (d['model'] ?? '').toString() == selectedModelFilter;
              }).toList();
            }

            if (selectedExchangeName != null && selectedExchangeName!.isNotEmpty) {
              filteredData = filteredData.where((item) {
                final d = (item.data() as Map<String, dynamic>);
                return d['exchangeVehicle'] == true &&
                    (d['name'] ?? '').toString() == selectedExchangeName;
              }).toList();
            }

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

          // derive brand/model/exchange lists from data
          final brandSet = <String>{};
          final modelSet = <String>{};
          final exchangeNames = <String>{};
          final brandToModels = <String, Set<String>>{};

          for (final d in data) {
            final itemData = d.data() as Map<String, dynamic>;
            final b = (itemData['brand'] ?? '').toString().trim();
            final m = (itemData['model'] ?? '').toString().trim();
            if (b.isNotEmpty) {
              brandSet.add(b);
              if (m.isNotEmpty) {
                brandToModels.putIfAbsent(b, () => <String>{}).add(m);
              }
            }
            if (m.isNotEmpty) modelSet.add(m);
            if (itemData['exchangeVehicle'] == true) {
              final n = (itemData['name'] ?? '').toString().trim();
              if (n.isNotEmpty) exchangeNames.add(n);
            }
          }

          final availableModelSet = (selectedBrandFilter?.isNotEmpty ?? false)
              ? (brandToModels[selectedBrandFilter!] ?? <String>{})
              : modelSet;

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

                    if (brandSet.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: DropdownButton<String>(
                          value: selectedBrandFilter,
                          hint: const Text('Brand'),
                          isExpanded: true,
                          items: brandSet
                              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedBrandFilter = v;
                              selectedModelFilter = null;
                            });
                          },
                        ),
                      ),
                    ],

                    if (selectedBrandFilter != null && availableModelSet.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: DropdownButton<String>(
                          value: selectedModelFilter,
                          hint: const Text('Model'),
                          isExpanded: true,
                          items: availableModelSet
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedModelFilter = v;
                            });
                          },
                        ),
                      ),
                    ],

                    if ((selectedBrandFilter?.isNotEmpty ?? false) ||
                        (selectedModelFilter?.isNotEmpty ?? false)) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear brand/model filter',
                        onPressed: () {
                          setState(() {
                            selectedBrandFilter = null;
                            selectedModelFilter = null;
                          });
                        },
                      ),
                    ],
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

                        children: [
                          ...filters.map((filter) {

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
                          if (exchangeNames.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: selectedExchangeName,
                              hint: const Text('Exchange'),
                              items: exchangeNames
                                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                  .toList(),
                              onChanged: (v) => setState(() => selectedExchangeName = v),
                            ),
                            if (selectedExchangeName != null && selectedExchangeName!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Clear exchange filter',
                                onPressed: () => setState(() => selectedExchangeName = null),
                              ),
                          ],
                        ],
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

                              final isCompleted =
                                  _isCompletedInquiry(
                                itemData,
                              );

                              final nextFollowUp =
                                  itemData[
                                      'nextFollowUp'];

                              final overdueReminderText =
                                  _followUpReminderText(
                                itemData,
                              );

                              final hasOverdueReminder =
                                  overdueReminderText !=
                                          null &&
                                      !isCompleted;

                              return Card(

                                margin:
                                    const EdgeInsets
                                        .all(10),

                                child: ListTile(

                                  selected:
                                      selectedInquiryIds.contains(
                                    item.id,
                                  ),

                                  selectedTileColor:
                                      Colors.red.withOpacity(0.08),

                                  onLongPress: () {

                                    setState(() {

                                      selectionMode = true;

                                      if (selectedInquiryIds
                                          .contains(item.id)) {

                                        selectedInquiryIds
                                            .remove(item.id);

                                      } else {

                                        selectedInquiryIds
                                            .add(item.id);
                                      }

                                      if (selectedInquiryIds
                                          .isEmpty) {

                                        selectionMode = false;
                                      }
                                    });
                                  },

                                  leading: selectionMode
                                      ? Checkbox(

                                          value:
                                              selectedInquiryIds.contains(
                                            item.id,
                                          ),

                                          activeColor:
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,

                                          onChanged: (value) {

                                            setState(() {

                                              if (value == true) {

                                                selectedInquiryIds
                                                    .add(item.id);

                                              } else {

                                                selectedInquiryIds
                                                    .remove(item.id);
                                              }

                                              if (selectedInquiryIds
                                                  .isEmpty) {

                                                selectionMode = false;
                                              }
                                            });
                                          },
                                        )
                                      : null,

                                  title: Text(
                                    itemData['name'] ?? '',
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
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                hasOverdueReminder
                                                    ? Colors.red
                                                    : null,
                                          ),
                                        ),

                                      if (hasOverdueReminder)

                                        Padding(

                                          padding:
                                              const EdgeInsets.only(
                                            top: 6,
                                          ),

                                          child: Text(

                                            overdueReminderText.toString(),

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

                                    if (selectionMode) {

                                      setState(() {

                                        if (selectedInquiryIds
                                            .contains(item.id)) {

                                          selectedInquiryIds
                                              .remove(item.id);

                                        } else {

                                          selectedInquiryIds
                                              .add(item.id);
                                        }

                                        if (selectedInquiryIds
                                            .isEmpty) {

                                          selectionMode = false;
                                        }
                                      });

                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInquiryScreen(
                                          inquiry: item,
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
