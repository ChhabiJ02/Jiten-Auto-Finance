import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  int selectedImage = 0;
  int selectedColor = 0;
  bool bookingLoading = false;

  Future<void> _bookNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book a vehicle.')),
      );
      return;
    }

    setState(() => bookingLoading = true);

    try {
      // Get counter for inquiry number
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('inquiryCounter');
      final counterSnapshot = await counterRef.get();
      var currentNumber = 0;
      if (counterSnapshot.exists) {
        currentNumber = counterSnapshot['current'] ?? 0;
      }
      final newInquiryNumber = currentNumber + 1;
      await counterRef.set({'current': newInquiryNumber});

      final brand = widget.vehicle['brand']?.toString() ?? '';
      final model = widget.vehicle['model']?.toString() ?? '';
      final variant = widget.vehicle['variant']?.toString() ?? '';
      final price = widget.vehicle['price']?.toString() ?? '';
      final photos = (widget.vehicle['photos'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [];

      // Fetch user display name from Firestore
      String customerName = user.displayName ?? '';
      String customerPhone = user.phoneNumber ?? '';
      if (customerName.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          customerName =
              (userDoc.data()?['name'] ?? '').toString();
          customerPhone =
              (userDoc.data()?['phone'] ?? '').toString();
        }
      }

      await FirebaseFirestore.instance.collection('inquiries').add({
        'inquiryNumber': newInquiryNumber,
        'name': customerName.isNotEmpty ? customerName : 'Customer',
        'phone': customerPhone,
        'brand': brand,
        'model': model,
        'variant': variant,
        'price': price,
        'vehiclePhotoUrl': photos.isNotEmpty ? photos.first : null,
        'vehiclePhotoUrls': photos,
        'status': 'New Inquiry',
        'paymentType': 'Loan',
        // Customer fields — staff cannot edit this inquiry
        'createdByCustomer': true,
        'customerId': user.uid,
        'customerEmail': user.email,
        // NOT assigned to any staff yet
        'staffId': null,
        'assignedTo': null,
        'createdBy': user.uid,
        'acceptedBy': null,
        'acceptedByName': null,
        'createdAt': Timestamp.now(),
        'date': DateTime.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request submitted! Our team will contact you.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit booking: $e')),
      );
    } finally {
      if (mounted) setState(() => bookingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final photos = (widget.vehicle['photos'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        [];

    final colors = (widget.vehicle['colors'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        ['Black', 'White', 'Blue'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SLIDER
            if (photos.isNotEmpty)
              SizedBox(
                height: 320,
                child: PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (index) =>
                      setState(() => selectedImage = index),
                  itemBuilder: (context, index) {
                    return Hero(
                      tag: '${widget.vehicle['model']}$index',
                      child: CachedNetworkImage(
                        imageUrl: photos[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.directions_bike,
                          size: 80,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 220,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.directions_bike, size: 80),
                ),
              ),

            const SizedBox(height: 14),

            // DOT INDICATOR
            if (photos.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: selectedImage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selectedImage == index
                          ? theme.colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BRAND CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.vehicle['brand'] ?? '',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // MODEL
                  Text(
                    widget.vehicle['model'] ?? '',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // VARIANT
                  Text(
                    widget.vehicle['variant'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // PRICE
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee,
                          color: Colors.green, size: 28),
                      Text(
                        widget.vehicle['price'].toString(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // COLORS
                  const Text(
                    "Available Colors",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 12,
                    children: List.generate(
                      colors.length,
                      (index) {
                        final isSelected = selectedColor == index;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedColor = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              colors[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  // BOOK NOW BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: bookingLoading ? null : _bookNow,
                      child: bookingLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "Book Now",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}