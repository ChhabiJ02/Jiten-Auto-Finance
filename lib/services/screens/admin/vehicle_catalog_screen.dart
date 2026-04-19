import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VehicleCatalogScreen extends StatelessWidget {
  const VehicleCatalogScreen({super.key});

  List<String> _normalizePhotoList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  Future<void> _showVehicleDialog(BuildContext context, [QueryDocumentSnapshot? doc]) async {
    final brandController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['brand'] as String? ?? '' : '');
    final modelController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['model'] as String? ?? '' : '');
    final variantController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['variant'] as String? ?? '' : '');
    final nameController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['displayName'] as String? ?? '' : '');
    final priceController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['price']?.toString() ?? '' : '');
    final descriptionController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? (doc!.data() as Map<String, dynamic>)['description'] as String? ?? '' : '');
    final photosController = TextEditingController(text: doc?.data() is Map<String, dynamic> ? _normalizePhotoList((doc!.data() as Map<String, dynamic>)['photos']).join(', ') : '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(doc == null ? 'Add Vehicle' : 'Edit Vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand')),
                const SizedBox(height: 12),
                TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model')),
                const SizedBox(height: 12),
                TextField(controller: variantController, decoration: const InputDecoration(labelText: 'Variant')),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Display Name')),
                const SizedBox(height: 12),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                const SizedBox(height: 12),
                TextField(
                  controller: photosController,
                  decoration: const InputDecoration(
                    labelText: 'Photos (comma separated URLs)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final brand = brandController.text.trim();
                final model = modelController.text.trim();
                final variant = variantController.text.trim();
                final displayName = nameController.text.trim();
                final price = priceController.text.trim();
                final description = descriptionController.text.trim();
                final photos = photosController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                if (brand.isEmpty || model.isEmpty) {
                  return;
                }

                final data = {
                  'brand': brand,
                  'model': model,
                  'variant': variant,
                  'displayName': displayName,
                  'price': price,
                  'description': description,
                  'photos': photos,
                  'updatedAt': Timestamp.now(),
                };

                if (doc == null) {
                  await FirebaseFirestore.instance.collection('vehicles').add({
                    ...data,
                    'createdAt': Timestamp.now(),
                  });
                } else {
                  await FirebaseFirestore.instance.collection('vehicles').doc(doc.id).update(data);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(doc == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Catalog')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').orderBy('brand').orderBy('model').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No vehicles added yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final photos = _normalizePhotoList(data['photos']);
              final imageUrl = photos.isNotEmpty ? photos.first : null;
              final displayName = data['displayName'] as String? ?? '';
              final title = displayName.isNotEmpty ? displayName : '${data['brand'] ?? ''} ${data['model'] ?? ''} ${data['variant'] ?? ''}'.trim();

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(imageUrl, width: 64, height: 64, fit: BoxFit.cover),
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.directions_bike, color: Colors.grey),
                        ),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Price: ₹${data['price'] ?? 'N/A'}'),
                      if ((data['description'] as String?)?.isNotEmpty ?? false) Text(data['description'] as String),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showVehicleDialog(context, doc);
                      } else if (value == 'delete') {
                        await FirebaseFirestore.instance.collection('vehicles').doc(doc.id).delete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
