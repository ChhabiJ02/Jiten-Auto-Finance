import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../cloudinary_service.dart';

class VariantScreen extends StatefulWidget {
  final String brand;
  final String model;

  const VariantScreen({super.key, required this.brand, required this.model});

  @override
  State<VariantScreen> createState() => _VariantScreenState();
}

class _VariantScreenState extends State<VariantScreen> {
  // ─── Normalize key for consistent matching ───
  String _normalizeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Returns images from the map for a given vehicle name.
  /// Tries: "Brand Variant" → "Variant" → partial match → empty
  List<String> _resolveImages(
    String brand,
    String variant,
    Map<String, List<String>> imageMap,
  ) {
    // 1. Try "Brand Variant" e.g. "Honda ACTIVA DLX DIGITAL"
    final fullKey = _normalizeKey('$brand $variant');
    if (imageMap.containsKey(fullKey)) return imageMap[fullKey]!;

    // 2. Try just variant e.g. "ACTIVA DLX DIGITAL"
    final variantKey = _normalizeKey(variant);
    if (imageMap.containsKey(variantKey)) return imageMap[variantKey]!;

    // 3. Partial match — any key that contains variant or vice versa
    for (final entry in imageMap.entries) {
      if (entry.key.contains(variantKey) || variantKey.contains(entry.key)) {
        return entry.value;
      }
    }

    return [];
  }

  void showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, List<String>> imageMap,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    final nameController = TextEditingController(text: data['Name']);
    final priceController =
        TextEditingController(text: data['Price'].toString());

    final variant = (data['Name'] ?? '').toString();
    final brand = (data['ParentBrand'] ?? widget.brand).toString();

    // Get existing images from VehicleImages map
    List<String> existingPhotos = _resolveImages(brand, variant, imageMap);
    String? newlyUploadedUrl; // track newly uploaded single photo
    bool isUploadingPhoto = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          // Display images: existing from VehicleImages + newly uploaded
          final displayPhotos = [
            ...existingPhotos,
            if (newlyUploadedUrl != null) newlyUploadedUrl!,
          ];

          return AlertDialog(
            title: const Text("Edit Variant Details"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── PHOTO GALLERY ───
                  if (displayPhotos.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: displayPhotos.length,
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: displayPhotos[i],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: const Center(
                        child: Icon(Icons.image, size: 80, color: Colors.grey),
                      ),
                    ),

                  if (displayPhotos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Swipe to see all ${displayPhotos.length} photos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ─── UPLOAD NEW PHOTO BUTTON ───
                  // This uploads to Cloudinary & saves to VehicleImages/{name}/images
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploadingPhoto
                          ? null
                          : () async {
                              setState(() => isUploadingPhoto = true);

                              final url =
                                  await CloudinaryService.pickAndUploadImage(
                                folder:
                                    'vehicle_variants/${data['ParentBrand']}',
                                source: ImageSource.gallery,
                              );

                              if (url != null) {
                                // Save to VehicleImages/{variantName}/images
                                final vehicleDocName =
                                    '${brand} ${variant}'.trim();
                                await FirebaseFirestore.instance
                                    .collection('VehicleImages')
                                    .doc(vehicleDocName)
                                    .collection('images')
                                    .add({
                                  'url': url,
                                  'fileName':
                                      url.split('/').last.split('?').first,
                                  'uploadedAt': FieldValue.serverTimestamp(),
                                });

                                setState(() {
                                  newlyUploadedUrl = url;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('✓ Photo uploaded!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('❌ Upload failed')),
                                );
                              }

                              setState(() => isUploadingPhoto = false);
                            },
                      icon: isUploadingPhoto
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label:
                          Text(isUploadingPhoto ? 'Uploading...' : 'Add Photo'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── VARIANT NAME ───
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: "Variant Name"),
                  ),
                  const SizedBox(height: 12),

                  // ─── PRICE ───
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: "Price"),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isUploadingPhoto
                    ? null
                    : () async {
                        await FirebaseFirestore.instance
                            .collection('Variant')
                            .doc(doc.id)
                            .update({
                          "Name": nameController.text,
                          "Price": priceController.text,
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Variant updated!')),
                        );
                      },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.brand} - ${widget.model}")),
      body: StreamBuilder<QuerySnapshot>(
        // ─── STREAM 1: Fetch all images from VehicleImages subcollection ───
        stream: FirebaseFirestore.instance
            .collectionGroup('images')
            .snapshots(),
        builder: (context, imageSnapshot) {
          // Build the vehicleImages map
          final vehicleImages = <String, List<String>>{};

          if (imageSnapshot.hasData) {
            for (final imageDoc in imageSnapshot.data!.docs) {
              final parentDoc = imageDoc.reference.parent.parent;
              if (parentDoc == null) continue;

              final vehicleName = parentDoc.id; // e.g. "Honda ACTIVA DLX DIGITAL"
              final data = imageDoc.data() as Map<String, dynamic>;
              final url = data['url']?.toString();
              if (url == null || url.isEmpty) continue;

              // Store by full name
              final fullKey = _normalizeKey(vehicleName);
              vehicleImages.putIfAbsent(fullKey, () => []).add(url);

              // Store without brand prefix as fallback
              final parts = vehicleName.trim().split(' ');
              if (parts.length > 1) {
                final withoutBrand = _normalizeKey(parts.skip(1).join(' '));
                vehicleImages.putIfAbsent(withoutBrand, () => []).add(url);
              }
            }
          }

          // ─── STREAM 2: Fetch variants for this model ───
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Variant')
                .where('ParentModel', isEqualTo: widget.model)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final variants = snapshot.data!.docs;

              if (variants.isEmpty) {
                return const Center(
                  child: Text('No variants found for this model.'),
                );
              }

              return ListView.builder(
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final doc = variants[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final variant = (data['Name'] ?? '').toString();
                  final brand =
                      (data['ParentBrand'] ?? widget.brand).toString();
                  final price = (data['Price'] ?? '').toString();

                  // Resolve photos from VehicleImages
                  final photos = _resolveImages(brand, variant, vehicleImages);
                  final firstPhoto = photos.isNotEmpty ? photos.first : null;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey[300],
                        ),
                        child: firstPhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: firstPhoto,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                      ),
                      title: Text(variant),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹$price'),
                          if (photos.length > 1)
                            Text(
                              '${photos.length} photos',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                showEditDialog(context, doc, vehicleImages),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('Variant')
                                  .doc(doc.id)
                                  .delete();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}