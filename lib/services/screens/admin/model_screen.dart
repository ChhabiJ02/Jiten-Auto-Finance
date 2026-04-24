import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'variant_screen.dart';

class ModelScreen extends StatelessWidget {
  final String brand;

  const ModelScreen({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(brand)),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Model')
            .where('ParentBrand', isEqualTo: brand)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final models = snapshot.data!.docs;

          return ListView.builder(
            itemCount: models.length,
            itemBuilder: (context, index) {
              final data = models[index].data() as Map<String, dynamic>;
              final modelName = data['Name'];

              return ListTile(
                title: Text(modelName),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VariantScreen(
                        brand: brand,
                        model: modelName,
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