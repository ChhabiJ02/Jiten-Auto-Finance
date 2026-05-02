import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_screen.dart';

class VehicleCatalogScreen extends StatelessWidget {
  const VehicleCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Brands")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Brand').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final brands = snapshot.data!.docs;

          return ListView.builder(
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final data = brands[index].data() as Map<String, dynamic>;
              final brandName = data['Name'];

              return ListTile(
                title: Text(brandName),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModelScreen(brand: brandName),
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