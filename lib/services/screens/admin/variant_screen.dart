import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VariantScreen extends StatelessWidget {
  final String brand;
  final String model;

  const VariantScreen({required this.brand, required this.model});

  void showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final nameController =
        TextEditingController(text: data['Name']);
    final priceController =
        TextEditingController(text: data['Price'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Variant"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Variant Name"),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: "Price"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('Variant')
                  .doc(doc.id)
                  .update({
                "Name": nameController.text,
                "Price": priceController.text,
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
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

              return ListTile(
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
              );
            },
          );
        },
      ),
    );
  }
}