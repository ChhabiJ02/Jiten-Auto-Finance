import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'new_vehicle_booking_screen.dart';
import 'book_service_screen.dart';
import 'my_appointments_screen.dart';
import 'my_service_plan_screen.dart';
import 'customer_profile_screen.dart';
import 'vehicle_detail_screen.dart';
import 'my_inquiries_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  String selectedBrand = 'All';

  final searchController = TextEditingController();
  bool searching = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseAuth.instance.currentUser?.reload();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      searching = !searching;
      if (!searching) {
        searchQuery = '';
        searchController.clear();
      }
    });
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search vehicles, brands or models',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
        ),
      ),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontSize: 16,
      ),
      onChanged: (value) => setState(() {
        searchQuery = value.trim().toLowerCase();
      }),
    );
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    if (searchQuery.isEmpty) return true;
    final candidate =
        '${item['brand'] ?? ''} ${item['model'] ?? ''} ${item['variant'] ?? ''} ${item['description'] ?? ''}'
            .toString()
            .toLowerCase();
    return candidate.contains(searchQuery);
  }

  String _normalizeVehicleKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _imagesForVehicleName(
    String vehicleName,
    Map<String, List<String>> imageMap,
  ) {
    if (vehicleName.trim().isEmpty) return [];
    final normalizedName = _normalizeVehicleKey(vehicleName);

    if (imageMap.containsKey(normalizedName)) {
      return imageMap[normalizedName]!;
    }
    for (final entry in imageMap.entries) {
      if (entry.key.contains(normalizedName) ||
          normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    return [];
  }

  // ─── Brand Section Widget ───────────────────────────────────
  // Shows: Brand name as heading → horizontal scroll of MODEL cards
  Widget buildBrandSection(
    BuildContext context,
    String brandName,
    List<Map<String, dynamic>> models,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Brand heading ──
        Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 4),
          child: Row(
            children: [
              // Brand pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  brandName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${models.length} ${models.length == 1 ? 'Model' : 'Models'}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // ── Divider ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: theme.colorScheme.primary.withOpacity(0.15),
            thickness: 1.5,
          ),
        ),

        const SizedBox(height: 4),

        // ── Horizontal model cards ──
        SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final item = models[index];

              final photos = (item['photos'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  [];
              final imageUrl = photos.isNotEmpty ? photos.first : null;
              final model = item['model'] ?? '';
              final variant = item['variant'] ?? '';
              final price = item['price'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VehicleDetailScreen(vehicle: item),
                    ),
                  );
                },
                child: Container(
                  width: 230,
                  margin: const EdgeInsets.only(right: 14, bottom: 8),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(24),
                    shadowColor:
                        theme.colorScheme.primary.withOpacity(0.2),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: theme.colorScheme.surface,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // IMAGE
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => Container(
                                      height: 160,
                                      color: theme.colorScheme
                                          .surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: 160,
                                      color: theme.colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(
                                          Icons.directions_bike,
                                          size: 64),
                                    ),
                                  )
                                : Container(
                                    height: 160,
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    child: const Center(
                                      child: Icon(Icons.directions_bike,
                                          size: 64),
                                    ),
                                  ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Model name (big, bold)
                                Text(
                                  model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Variant name (smaller, grey)
                                Text(
                                  variant,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Price
                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee,
                                        size: 18, color: Colors.green),
                                    Expanded(
                                      child: Text(
                                        price.toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.75),
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBrandChip(String brand) {
    final isSelected = selectedBrand == brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(brand),
        selected: isSelected,
        onSelected: (_) => setState(() => selectedBrand = brand),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JitenAuto Showroom'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerProfileScreen()),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          // STREAM 1: Vehicle images
          stream: FirebaseFirestore.instance
              .collectionGroup('images')
              .snapshots(),
          builder: (context, imageSnapshot) {
            // Build vehicleImages map
            final vehicleImages = <String, List<String>>{};
            if (imageSnapshot.hasData) {
              for (final imageDoc in imageSnapshot.data!.docs) {
                final parentDoc = imageDoc.reference.parent.parent;
                if (parentDoc == null) continue;
                final vehicleName = parentDoc.id;
                final data = imageDoc.data() as Map<String, dynamic>;
                final url = data['url']?.toString();
                if (url == null || url.isEmpty) continue;

                final fullKey = _normalizeVehicleKey(vehicleName);
                vehicleImages.putIfAbsent(fullKey, () => []).add(url);

                final parts = vehicleName.trim().split(' ');
                if (parts.length > 1) {
                  final withoutBrand =
                      _normalizeVehicleKey(parts.skip(1).join(' '));
                  vehicleImages
                      .putIfAbsent(withoutBrand, () => [])
                      .add(url);
                }
              }
            }

            // STREAM 2: Variants
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Vehicle')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
  debugPrint(
    'FIRESTORE ERROR: ${snapshot.error}',
  );

  return SingleChildScrollView(
    child: Column(
      children: [
        const SizedBox(height: 20),

        // Quick Actions still visible
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Quick Actions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.92,
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            children: [
              buildActionCard(
                context,
                'New Vehicle Booking',
                'Request a new vehicle purchase',
                Icons.directions_bike,
                () {},
              ),

              buildActionCard(
                context,
                'Book Service',
                'Schedule service for any 2-wheeler',
                Icons.miscellaneous_services,
                () {},
              ),

              buildActionCard(
                context,
                'My Appointments',
                'Track service requests and approvals',
                Icons.calendar_month,
                () {},
              ),

              buildActionCard(
                context,
                'My Service Plan',
                'View left services and renew plans',
                Icons.assignment_turned_in,
                () {},
              ),

              buildActionCard(
                context,
                'My Inquiries',
                'Track all your booking inquiries',
                Icons.receipt_long,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const MyInquiriesScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        Icon(
          Icons.error_outline,
          size: 60,
          color: Colors.red,
        ),

        const SizedBox(height: 16),

        Text(
          'Vehicle section failed to load',
          style: theme.textTheme.titleMedium,
        ),

        const SizedBox(height: 8),

        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('Loading vehicles...',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                // Collect all brand names for filter chips
                final allBrands = <String>{};

                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  final brand =
                      (data['Brand'] ?? '').toString().trim();

                  if (brand.isNotEmpty) {
                    allBrands.add(brand);
                  }
                }

                // ── GROUP by Brand → then deduplicate by Model ──
                // Structure: { brandName: { modelName: vehicleData } }
                final grouped =
                    <String, Map<String, Map<String, dynamic>>>{};

                for (final doc in docs) {
                  try {
                    final data = doc.data() as Map<String, dynamic>;

                    final brand =
                        (data['Brand'] ?? '').toString().trim();

                    final model =
                        (data['Model'] ?? '').toString().trim();

                    final variant =
                        (data['Variant'] ?? '').toString().trim();

                    final price =
                        (data['Price'] ?? '').toString().trim();
                    final description =
                        (data['description'] ?? '').toString();

                    // BRAND FILTER
                    if (selectedBrand != 'All' &&
                        selectedBrand != brand) {
                      continue;
                    }

                    // Search filter
                    if (!_matchesSearch({
                      'brand': brand,
                      'model': model,
                      'variant': variant,
                      'description': description,
                    })) continue;

                    // Image resolution
                    final brandVariantKey = '$brand $variant'.trim();
                    final resolvedPhotos = _imagesForVehicleName(
                                brandVariantKey, vehicleImages)
                            .isNotEmpty
                        ? _imagesForVehicleName(
                            brandVariantKey, vehicleImages)
                        : _imagesForVehicleName(variant, vehicleImages)
                                .isNotEmpty
                            ? _imagesForVehicleName(
                                variant, vehicleImages)
                            : _imagesForVehicleName(model, vehicleImages);

                    final vehicleItem = {
                      'brand': brand,
                      'model': model,
                      'variant': variant,
                      'price': price,
                      'description': description,
                      'photos': resolvedPhotos.isNotEmpty
                          ? resolvedPhotos
                          : (data['photos'] is List
                              ? data['photos']
                              : []),
                    };

                    // One card per model
if (!grouped.containsKey(brand)) {
  grouped[brand] = {};
}

if (!grouped[brand]!.containsKey(model)) {
  grouped[brand]![model] = vehicleItem;
} else {
  final existing =
      grouped[brand]![model]!['photos'] as List;

  final incoming =
      vehicleItem['photos'] as List;

  if (incoming.length > existing.length) {
    grouped[brand]![model] = vehicleItem;
  }
}
} catch (e) {
  debugPrint('Vehicle parse error: $e');
}
}

return SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Quick Actions ──
      const SizedBox(height: 16),

      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const SizedBox(height: 12),

      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.92,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [

            buildActionCard(
              context,
              'New Vehicle Booking',
              'Request a new vehicle purchase',
              Icons.directions_bike,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NewVehicleBookingScreen(),
                ),
              ),
            ),

            buildActionCard(
              context,
              'Book Service',
              'Schedule service for any 2-wheeler',
              Icons.miscellaneous_services,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const BookServiceScreen(),
                ),
              ),
            ),

            buildActionCard(
              context,
              'My Appointments',
              'Track service requests and approvals',
              Icons.calendar_month,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MyAppointmentsScreen(),
                ),
              ),
            ),

            buildActionCard(
              context,
              'My Service Plan',
              'View left services and renew plans',
              Icons.assignment_turned_in,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MyServicePlanScreen(),
                ),
              ),
            ),

            buildActionCard(
              context,
              'My Inquiries',
              'Track all your booking inquiries',
              Icons.receipt_long,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MyInquiriesScreen(),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // ── Brand Filter Chips ──
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              buildBrandChip('All'),
              ...allBrands
                  .map((b) => buildBrandChip(b)),
            ],
          ),
        ),
      ),

      const SizedBox(height: 8),

      // ── Vehicle sections ──
      if (docs.isEmpty) ...[
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.directions_bike,
                size: 56,
                color: theme.colorScheme.onSurface
                    .withOpacity(0.3),
              ),

              const SizedBox(height: 16),

              Text(
                'No Vehicles Available',
                style: theme.textTheme.titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Our vehicle catalog is being updated. Please check back soon!',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ] else ...[
        for (final entry in grouped.entries)
          buildBrandSection(
            context,
            entry.key,
            entry.value.values.toList(),
          ),

        const SizedBox(height: 24),
      ],
    ],
  ),
);
              },
            );
          },
        ),
      ),
    );
  }
}