import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'new_vehicle_booking_screen.dart';
import 'book_service_screen.dart';
import 'my_appointments_screen.dart';
import 'my_service_plan_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  final List<Map<String, String>> fallbackVehicles = [
    {"name": "Activa 6G Black", "price": "₹1,05,000", "img": "https://via.placeholder.com/150"},
    {"name": "Activa 5G Grey", "price": "₹95,000", "img": "https://via.placeholder.com/150"},
    {"name": "Jupiter Matte Black", "price": "₹1,00,000", "img": "https://via.placeholder.com/150"},
  ];

  Widget buildVehicleSection(BuildContext context, String title, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final photoUrls = (item['photos'] as List<dynamic>?)?.whereType<String>().toList() ?? [];
              final imageUrl = photoUrls.isNotEmpty ? photoUrls.first : item['img'] as String?;
              final titleText = (item['displayName'] as String?)?.isNotEmpty == true
                  ? item['displayName'] as String
                  : '${item['brand'] ?? ''} ${item['model'] ?? ''} ${item['variant'] ?? ''}'.trim();

              return Container(
                width: 170,
                margin: const EdgeInsets.only(left: 12),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: imageUrl != null
                            ? Image.network(imageUrl, height: 110, width: double.infinity, fit: BoxFit.cover)
                            : Container(height: 110, color: Colors.grey.shade200, child: const Icon(Icons.directions_bike, size: 48, color: Colors.grey)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('₹${item['price'] ?? 'N/A'}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildOptionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 170,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final brand = (data['brand'] as String?)?.trim() ?? 'Others';
            grouped.putIfAbsent(brand, () => []).add(data);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back, $name!', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text('Customer Dashboard — new vehicle booking and service appointment flows.', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      buildOptionCard(
                        context,
                        'New Vehicle Booking',
                        'Request a new vehicle purchase',
                        Icons.directions_bike,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewVehicleBookingScreen())),
                      ),
                      buildOptionCard(
                        context,
                        'Book Service',
                        'Schedule service for any 2-wheeler',
                        Icons.miscellaneous_services,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookServiceScreen())),
                      ),
                      buildOptionCard(
                        context,
                        'My Appointments',
                        'Track service requests and approvals',
                        Icons.calendar_month,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAppointmentsScreen())),
                      ),
                      buildOptionCard(
                        context,
                        'My Service Plan',
                        'View left services and renew plans',
                        Icons.assignment_turned_in,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicePlanScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (docs.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'No vehicle catalog available yet. Please check back later.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildVehicleSection(context, 'Featured Vehicles', fallbackVehicles.map((item) => item.cast<String, dynamic>()).toList()),
                ] else ...[
                  for (final entry in grouped.entries)
                    buildVehicleSection(context, entry.key, entry.value),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}