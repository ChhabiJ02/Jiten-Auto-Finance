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

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  String selectedBrand = 'All';
  final List<Map<String, String>> fallbackVehicles = [
    {
      "name": "Activa 6G Black",
      "price": "₹1,05,000",
      "img": "https://via.placeholder.com/150",
    },
    {
      "name": "Activa 5G Grey",
      "price": "₹95,000",
      "img": "https://via.placeholder.com/150",
    },
    {
      "name": "Jupiter Matte Black",
      "price": "₹1,00,000",
      "img": "https://via.placeholder.com/150",
    },
  ];

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
        '${item['displayName'] ?? ''} ${item['brand'] ?? ''} ${item['model'] ?? ''} ${item['variant'] ?? ''} ${item['description'] ?? ''}'
            .toString()
            .toLowerCase();
    return candidate.contains(searchQuery);
  }

  Widget buildVehicleSection(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const Spacer(),
              Text(
                "${items.length} Models",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 340,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              final photos =
                  (item['photos'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  [];

              final imageUrl = photos.isNotEmpty ? photos.first : null;

              final brand = item['brand'] ?? '';
              final model = item['model'] ?? '';
              final variant = item['variant'] ?? '';
              final price = item['price'] ?? '';
              final colors =
                  (item['colors'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  ["Black", "White", "Blue"];

              return GestureDetector(

  onTap: () {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(
          vehicle: item,
        ),
      ),
    );
  },

  child: Container(
    width: 250,
    margin: const EdgeInsets.only(
      right: 16,
      bottom: 8,
    ),

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
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // IMAGE
            Stack(
              children: [

                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),

                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,

                          placeholder:
                              (context, url) => Container(
                            height: 170,
                            color: theme.colorScheme
                                .surfaceContainerHighest,

                            child: const Center(
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),

                          errorWidget:
                              (context, url, error) =>
                                  Container(
                            height: 170,
                            color: theme.colorScheme
                                .surfaceContainerHighest,

                            child: const Icon(
                              Icons.directions_bike,
                              size: 60,
                            ),
                          ),
                        )
                      : Container(
                          height: 170,
                          color: theme.colorScheme
                              .surfaceContainerHighest,

                          child: const Center(
                            child: Icon(
                              Icons.directions_bike,
                              size: 60,
                            ),
                          ),
                        ),
                ),

                Positioned(
                  top: 12,
                  left: 12,

                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),

                    child: Text(
                      brand,

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      model,

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      variant,

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [

                        const Icon(
                          Icons.currency_rupee,
                          size: 18,
                          color: Colors.green,
                        ),

                        Text(
                          price.toString(),

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Available Colors",

                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,

                      children: colors.map((color) {

                        return Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: theme.colorScheme
                                .primary
                                .withOpacity(0.08),

                            borderRadius:
                                BorderRadius.circular(14),
                          ),

                          child: Text(
                            color,

                            style: TextStyle(
                              color:
                                  theme.colorScheme.primary,

                              fontWeight:
                                  FontWeight.w600,

                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const Spacer(),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withOpacity(0.1),

                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      child: Text(
                        '₹$price',

                        style: theme.textTheme.titleSmall
                            ?.copyWith(
                          color:
                              theme.colorScheme.primary,

                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
        onSelected: (_) {
          setState(() {
            selectedBrand = brand;
          });
        },
      ),
    );
  }

  String _normalizeVehicleKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Tries to find images by exact key, then falls back to partial matches.
  List<String> _imagesForVehicleName(
    String vehicleName,
    Map<String, List<String>> imageMap,
  ) {
    if (vehicleName.trim().isEmpty) return [];

    final normalizedName = _normalizeVehicleKey(vehicleName);

    // 1. Exact match
    if (imageMap.containsKey(normalizedName)) {
      return imageMap[normalizedName]!;
    }

    // 2. Check if any key contains the vehicle name or vice versa
    for (final entry in imageMap.entries) {
      if (entry.key.contains(normalizedName) ||
          normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: searching
            ? buildSearchField()
            : const Text("JitenAuto Dashboard"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerProfileScreen(),
                ),
              );
            },
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
          // ─── STREAM 1: Fetch all image docs from VehicleImages/{vehicleName}/images ───
          stream: FirebaseFirestore.instance
              .collectionGroup('images')
              .snapshots(),
          builder: (context, imageSnapshot) {
            if (imageSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Unable to load vehicle images.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }

            // ─── BUILD vehicleImages MAP ───
            // Key   = normalized vehicle name (from VehicleImages doc ID)
            //         e.g. "honda activa dlx digital"
            // Value = list of Cloudinary URLs
            final vehicleImages = <String, List<String>>{};

            if (imageSnapshot.hasData) {
              for (final imageDoc in imageSnapshot.data!.docs) {
                // parent of 'images' subcollection = VehicleImages/{vehicleName}
                final parentDoc = imageDoc.reference.parent.parent;
                if (parentDoc == null) continue;

                final vehicleName = parentDoc.id; // e.g. "Honda ACTIVA DLX DIGITAL"
                final data = imageDoc.data() as Map<String, dynamic>;
                final url = data['url']?.toString();
                if (url == null || url.isEmpty) continue;

                // Store by full normalized name: "honda activa dlx digital"
                final fullKey = _normalizeVehicleKey(vehicleName);
                vehicleImages.putIfAbsent(fullKey, () => []).add(url);

                // Also store without the first word (brand) as fallback key
                // e.g. "activa dlx digital"
                final parts = vehicleName.trim().split(' ');
                if (parts.length > 1) {
                  final withoutBrand =
                      _normalizeVehicleKey(parts.skip(1).join(' '));
                  vehicleImages.putIfAbsent(withoutBrand, () => []).add(url);
                }
              }
            }

            // ─── STREAM 2: Fetch all variants ───
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Variant')
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle errors
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load vehicles',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your connection and try again.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Loading state
                if (!snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading vehicles...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                final brands = <String>{};
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final brand = (data['ParentBrand'] ?? '').toString().trim();

                  if (brand.isEmpty) continue;
                  brands.add(brand);
                }

                // ─── GROUP VEHICLES BY BRAND ───
                final grouped = <String, List<Map<String, dynamic>>>{};

                for (final doc in docs) {
                  try {
                    final data = doc.data() as Map<String, dynamic>;

                    final brandRaw = data['ParentBrand'];
                    final brand =
                        (brandRaw != null &&
                            brandRaw.toString().trim().isNotEmpty)
                        ? brandRaw.toString().trim()
                        : 'Unknown';

                    if (selectedBrand != 'All' && brand != selectedBrand) {
                      continue;
                    }

                    final model = (data['ParentModel'] ?? '').toString();
                    final variant = (data['Name'] ?? '').toString();
                    final price = (data['Price'] ?? '').toString();
                    final description = (data['description'] ?? '').toString();

                    final vehicleItem = {
                      'brand': brand,
                      'model': model,
                      'variant': variant,
                      'displayName': model,
                      'description': description,
                    };

                    if (!_matchesSearch(vehicleItem)) {
                      continue;
                    }

                    // ─── IMAGE RESOLUTION ───
                    // VehicleImages doc ID = "{Brand} {Variant}"
                    // e.g. "Honda ACTIVA DLX DIGITAL"
                    // Try: "brand variant" → "variant" → "model" → empty
                    final brandVariantKey = '$brand $variant'.trim();
                    final resolvedPhotos =
                        _imagesForVehicleName(brandVariantKey, vehicleImages)
                            .isNotEmpty
                        ? _imagesForVehicleName(brandVariantKey, vehicleImages)
                        : _imagesForVehicleName(variant, vehicleImages)
                            .isNotEmpty
                        ? _imagesForVehicleName(variant, vehicleImages)
                        : _imagesForVehicleName(model, vehicleImages);

                    grouped.putIfAbsent(brand, () => []).add({
                      'brand': brand,
                      'model': model,
                      'variant': variant,
                      'price': price,
                      'displayName': model,
                      'photos': resolvedPhotos.isNotEmpty
                          ? resolvedPhotos
                          : (data['photos'] is List ? data['photos'] : []),
                    });
                  } catch (e) {
                    continue;
                  }
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Quick Actions',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
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
                                  builder: (_) => const BookServiceScreen(),
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
                                  builder: (_) => const MyAppointmentsScreen(),
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
                                  builder: (_) => const MyServicePlanScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Brand Filter Chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              buildBrandChip('All'),
                              ...brands.map((b) => buildBrandChip(b)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Vehicles Section
                      if (docs.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Our vehicle catalog is being updated. Please check back soon!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else if (grouped.isEmpty &&
                          searchQuery.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 56,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Results Found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try searching with different keywords.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        for (final entry in grouped.entries)
                          buildVehicleSection(context, entry.key, entry.value),
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