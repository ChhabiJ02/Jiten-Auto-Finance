import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../cloudinary_service.dart';

class VariantScreen extends StatelessWidget {
  final String brand;
  final String model;

  const VariantScreen({super.key, required this.brand, required this.model});

  void showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final nameController =
        TextEditingController(text: data['Name']);
    final priceController =
        TextEditingController(text: data['Price'].toString());
    
    String? photoUrl = data['photoUrl']; // Get existing photo URL
    bool isUploadingPhoto = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Variant Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo Display and Upload
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Center(
                          child: Icon(Icons.image, size: 80, color: Colors.grey),
                        ),
                ),
                const SizedBox(height: 12),
                
                // Upload Photo Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUploadingPhoto
                        ? null
                        : () async {
                            setState(() => isUploadingPhoto = true);
                            
                            final url = await CloudinaryService.pickAndUploadImage(
                              folder: 'vehicle_variants/${data['ParentBrand']}',
                              source: ImageSource.gallery,
                            );
                            
                            if (url != null) {
                              setState(() {
                                photoUrl = url;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Photo uploaded!')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❌ Upload failed')),
                              );
                            }
                            
                            setState(() => isUploadingPhoto = false);
                          },
                    icon: isUploadingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(isUploadingPhoto ? 'Uploading...' : 'Upload Photo'),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Variant Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Variant Name"),
                ),
                const SizedBox(height: 12),
                
                // Price
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
                        if (photoUrl != null) "photoUrl": photoUrl,
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Variant updated!')),
                      );
                    },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$brand - $model")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Variant')
            .where('ParentModel', isEqualTo: model)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final variants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final doc = variants[index];
              final data = doc.data() as Map<String, dynamic>;
              final photoUrl = data['photoUrl'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey[300],
                    ),
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                  title: Text(data['Name']),
                  subtitle: Text("₹${data['Price']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => showEditDialog(context, doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
      ),
    );
  }
}