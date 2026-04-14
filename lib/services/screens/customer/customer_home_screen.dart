import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerHomeScreen extends StatelessWidget {
  final List<Map<String, String>> activa6g = [
    {"name": "Black", "price": "₹1,05,000", "img": "https://via.placeholder.com/150"},
    {"name": "Blue", "price": "₹1,07,000", "img": "https://via.placeholder.com/150"},
    {"name": "Red", "price": "₹1,06,000", "img": "https://via.placeholder.com/150"},
  ];

  final List<Map<String, String>> activa5g = [
    {"name": "Grey", "price": "₹95,000", "img": "https://via.placeholder.com/150"},
    {"name": "White", "price": "₹96,000", "img": "https://via.placeholder.com/150"},
  ];

  final List<Map<String, String>> jupiter = [
    {"name": "Matte Black", "price": "₹1,00,000", "img": "https://via.placeholder.com/150"},
    {"name": "Silver", "price": "₹99,000", "img": "https://via.placeholder.com/150"},
  ];

  Widget buildSection(BuildContext context, String title, List<Map<String, String>> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Container(
                width: 140,
                margin: const EdgeInsets.only(left: 12),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          item["img"]!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(item["name"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        item["price"]!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text("JitenAuto"),
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

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            buildSection(context, "Activa 6G", activa6g),
            buildSection(context, "Activa 5G", activa5g),
            buildSection(context, "Jupiter", jupiter),
          ],
        ),
      ),
    );
  }
}