import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'inquiry_list_screen.dart';
import 'vehicle_catalog_screen.dart';
import 'admin_profile_screen.dart';
import 'user_management_screen.dart';
import '../staff/service_requests_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  Map<DateTime, int> _calculateCounts(List<QueryDocumentSnapshot> inquiries) {

    final counts = <DateTime, int>{};

    for (final doc in inquiries) {

      final data = doc.data();

      if (data is Map<String, dynamic>) {

        final createdAt = data['createdAt'];

        if (createdAt is Timestamp) {

          final createdDate = createdAt.toDate();

          final dayKey = DateTime(
            createdDate.year,
            createdDate.month,
            createdDate.day,
          );

          counts[dayKey] = (counts[dayKey] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {

    final today = DateTime.now();

    final startDate = DateTime(today.year, today.month, 1);

    final endDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return Scaffold(

      backgroundColor: const Color(0xFFF4EBEE),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4EBEE),

        title: const Text(
          'Admin Dashboard',

          style: TextStyle(
            color: Color(0xFF7B1F3F),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),

        actions: [

          Container(
            margin: const EdgeInsets.only(right: 8),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),

            child: IconButton(
              icon: const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF7B1F3F),
              ),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.miscellaneous_services,
                color: Color(0xFF7B1F3F),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServiceRequestsScreen(),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),

            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF7B1F3F),
              ),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminProfileScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .orderBy('createdAt', descending: true)
            .limit(1000)
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final inquiries = snapshot.data!.docs;

          final counts = _calculateCounts(inquiries);

          final days = List.generate(
            endDate.difference(startDate).inDays + 1,
                (index) => startDate.add(Duration(days: index)),
          );

          final dailyCounts = days
              .map((day) => counts[day] ?? 0)
              .toList();

          final totalLeads = dailyCounts.fold<int>(
            0,
                (total, value) => total + value,
          );

          return SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // CRM HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7B1F3F),
                      Color(0xFF4A1025),
                    ],
                  ),

                  borderRadius: BorderRadius.circular(24),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(
                      "Jiten Auto ",

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Manage inquiries, vehicles & showroom leads",

                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // LEAD CARDS
              Row(
                children: [

                  Expanded(
                    child: GestureDetector(

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InquiryListScreen(),
                          ),
                        );
                      },

                      child: _ModernCard(
                        title: 'All Leads',
                        value: inquiries.length.toString(),
                        icon: Icons.people_alt_outlined,
                        color: const Color(0xFF7B1F3F),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: GestureDetector(

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InquiryListScreen(),
                          ),
                        );
                      },

                      child: _ModernCard(
                        title: 'Monthly Leads',
                        value: totalLeads.toString(),
                        icon: Icons.analytics_outlined,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // VEHICLE CARD
              GestureDetector(

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleCatalogScreen(),
                    ),
                  );
                },

                child: Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [

                      Container(
                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),

                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(
                              "Manage Vehicles",

                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              "Add and manage showroom vehicles",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.arrow_forward_ios_rounded),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // MONTHLY REPORT
              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Monthly Lead Report',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B1F3F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            DateFormat('MMMM yyyy').format(today),
                            style: const TextStyle(
                              color: Color(0xFF7B1F3F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SingleChildScrollView(

                      scrollDirection: Axis.horizontal,

                      child: Table(

                        defaultColumnWidth:
                        const IntrinsicColumnWidth(),

                        border: TableBorder.all(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),

                        children: [

                          TableRow(

                            decoration: const BoxDecoration(
                                color: Color(0xFF7B1F3F),
                            ),

                            children: [

                              const _TableCell(
                                label: 'Days',
                                isHeader: true,
                              ),

                              ...days.map(
                                    (day) => _TableCell(
                                  label: DateFormat('d').format(day),
                                  isHeader: true,
                                ),
                              ),

                              const _TableCell(
                                label: 'Total',
                                isHeader: true,
                              ),
                            ],
                          ),

                          TableRow(
                            children: [

                              const _TableCell(
                                label: 'Leads',
                                //isHeader: true,
                              ),

                              ...List.generate(dailyCounts.length, (i) {
                                final leadCount = dailyCounts[i];
                                final day = days[i];
                                return _TableCell(
                                  label: leadCount.toString(),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InquiryListScreen(
                                          filterFrom: DateTime(day.year, day.month, day.day),
                                          filterTo: DateTime(day.year, day.month, day.day),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),

                              _TableCell(
                                label: totalLeads.toString(),
                                isBold: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InquiryListScreen(
                                        filterFrom: startDate,
                                        filterTo: endDate,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        );
        },
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {

  const _ModernCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              icon,
              color: color,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            title,

            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,

            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {

  const _TableCell({
    required this.label,
    this.isHeader = false,
    this.isBold = false,
    this.onTap,
  });

  final String label;
  final bool isHeader;
  final bool isBold;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),

      child: Text(
        label,

        textAlign: TextAlign.center,

        style: TextStyle(
          fontWeight: isHeader || isBold
              ? FontWeight.bold
              : FontWeight.w500,

          color: isHeader
              ? Colors.white
              : Colors.black54,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }

    return content;
  }
}
