import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'inquiry_list_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const int daysToShow = 16;

  late DateTime selectedStartDate;
  late DateTime selectedEndDate;
  late DateTime appliedStartDate;
  late DateTime appliedEndDate;
  String selectedMake = 'All';
  String selectedModel = 'All';
  String selectedSource = 'All';
  String appliedMake = 'All';
  String appliedModel = 'All';
  String appliedSource = 'All';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    selectedEndDate = DateTime(today.year, today.month, today.day);
    selectedStartDate = selectedEndDate.subtract(const Duration(days: daysToShow - 1));
    appliedStartDate = selectedStartDate;
    appliedEndDate = selectedEndDate;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? selectedStartDate : selectedEndDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        selectedStartDate = picked.isAfter(selectedEndDate) ? selectedEndDate : picked;
      } else {
        selectedEndDate = picked.isBefore(selectedStartDate) ? selectedStartDate : picked;
      }
    });
  }

  String _normalizeField(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> _uniqueValues(List<QueryDocumentSnapshot> docs, String field) {
    final values = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      if (data is Map<String, dynamic>) {
        final value = _normalizeField(data[field]);
        if (value.isNotEmpty) {
          values.add(value);
        }
      }
    }
    final sorted = values.toList()..sort();
    return ['All', ...sorted];
  }

  bool _applyFilter(Map<String, dynamic> data, DateTime dayKey) {
    if (appliedMake != 'All') {
      final brand = _normalizeField(data['brand']);
      if (brand.toLowerCase() != appliedMake.toLowerCase()) {
        return false;
      }
    }

    if (appliedModel != 'All') {
      final model = _normalizeField(data['model']);
      if (model.toLowerCase() != appliedModel.toLowerCase()) {
        return false;
      }
    }

    if (appliedSource != 'All') {
      final source = _normalizeField(data['source']);
      if (source.toLowerCase() != appliedSource.toLowerCase()) {
        return false;
      }
    }

    final createdAt = data['createdAt'];
    if (createdAt is! Timestamp) {
      return false;
    }

    final createdDate = createdAt.toDate();
    final createdDay = DateTime(createdDate.year, createdDate.month, createdDate.day);
    return !createdDay.isBefore(appliedStartDate) && !createdDay.isAfter(appliedEndDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inquiries').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final inquiries = snapshot.data!.docs;
          final makeOptions = _uniqueValues(inquiries, 'brand');
          final modelOptions = _uniqueValues(inquiries, 'model');
          final sourceOptions = _uniqueValues(inquiries, 'source');

          final counts = <DateTime, int>{};
          for (final doc in inquiries) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              final createdAt = data['createdAt'];
              if (createdAt is Timestamp) {
                final createdDate = createdAt.toDate();
                final dayKey = DateTime(createdDate.year, createdDate.month, createdDate.day);
                if (_applyFilter(data, dayKey)) {
                  counts[dayKey] = (counts[dayKey] ?? 0) + 1;
                }
              }
            }
          }

          final days = List.generate(
            appliedEndDate.difference(appliedStartDate).inDays + 1,
            (index) => appliedStartDate.add(Duration(days: index)),
          );
          final dailyCounts = days.map((day) => counts[day] ?? 0).toList();
          final totalLeads = dailyCounts.fold<int>(0, (total, value) => total + value);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedMake,
                                    decoration: const InputDecoration(labelText: 'Make'),
                                    items: makeOptions.map((value) {
                                      return DropdownMenuItem(value: value, child: Text(value));
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedMake = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedModel,
                                    decoration: const InputDecoration(labelText: 'Model'),
                                    items: modelOptions.map((value) {
                                      return DropdownMenuItem(value: value, child: Text(value));
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedModel = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedSource,
                                    decoration: const InputDecoration(labelText: 'Source'),
                                    items: sourceOptions.map((value) {
                                      return DropdownMenuItem(value: value, child: Text(value));
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedSource = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _pickDate(isStart: true),
                                          child: Text('From: ${DateFormat('dd/MM/yyyy').format(selectedStartDate)}'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _pickDate(isStart: false),
                                          child: Text('To: ${DateFormat('dd/MM/yyyy').format(selectedEndDate)}'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 160,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      appliedMake = selectedMake;
                                      appliedModel = selectedModel;
                                      appliedSource = selectedSource;
                                      appliedStartDate = selectedStartDate;
                                      appliedEndDate = selectedEndDate;
                                    });
                                  },
                                  child: const Text('Search'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: 'Total Leads',
                        value: totalLeads.toString(),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: 'Active Leads',
                        value: inquiries.length.toString(),
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Lead Trend',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text(
                              '$totalLeads total',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: CustomPaint(
                            painter: _LineChartPainter(
                              points: dailyCounts,
                              lineColor: Theme.of(context).colorScheme.primary,
                              dotColor: Theme.of(context).colorScheme.secondary,
                              gridColor: Theme.of(context).dividerColor,
                            ),
                            child: Container(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('From ${DateFormat('dd MMM').format(appliedStartDate)}', style: Theme.of(context).textTheme.bodyMedium),
                            Text('To ${DateFormat('dd MMM').format(appliedEndDate)}', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM').format(appliedStartDate),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            defaultColumnWidth: const IntrinsicColumnWidth(),
                            border: TableBorder.all(color: Colors.grey.shade300),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: [
                                  _TableCell(label: 'Days', isHeader: true),
                                  ...days.map((day) => _TableCell(label: DateFormat('d').format(day), isHeader: true)),
                                  _TableCell(label: 'Total', isHeader: true),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _TableCell(label: 'Leads', isHeader: true),
                                  ...dailyCounts.map((leadCount) => _TableCell(label: leadCount.toString())),
                                  _TableCell(label: totalLeads.toString(), isBold: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InquiryListScreen()),
                      );
                    },
                    child: const Text('View All Inquiries'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.label, this.isHeader = false, this.isBold = false});

  final String label;
  final bool isHeader;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isHeader || isBold ? FontWeight.w700 : FontWeight.w500,
          color: isHeader ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.lineColor, required this.dotColor, required this.gridColor});

  final List<int> points;
  final Color lineColor;
  final Color dotColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height - i * size.height / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final maxValue = points.isEmpty ? 1 : points.reduce(math.max);
    final path = Path();
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var index = 0; index < points.length; index++) {
      final dx = points.length == 1 ? 0.0 : index * (size.width / (points.length - 1));
      final normalized = maxValue == 0 ? 0.5 : points[index] / maxValue;
      final dy = size.height - normalized * size.height;
      final current = Offset(dx, dy);
      if (index == 0) {
        path.moveTo(current.dx, current.dy);
      } else {
        path.lineTo(current.dx, current.dy);
      }
    }

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = dotColor;
    for (var index = 0; index < points.length; index++) {
      final dx = points.length == 1 ? 0.0 : index * (size.width / (points.length - 1));
      final normalized = maxValue == 0 ? 0.5 : points[index] / maxValue;
      final dy = size.height - normalized * size.height;
      canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
