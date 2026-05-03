import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VehicleDetailScreen extends StatefulWidget {

  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState
    extends State<VehicleDetailScreen> {

  int selectedImage = 0;
  int selectedColor = 0;

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final photos =
        (widget.vehicle['photos'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        [];

    final colors =
        (widget.vehicle['colors'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        [
          "Black",
          "White",
          "Blue",
        ];

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
            SizedBox(
              height: 320,

              child: PageView.builder(

                itemCount: photos.length,

                onPageChanged: (index) {
                  setState(() {
                    selectedImage = index;
                  });
                },

                itemBuilder: (context, index) {

                  return Hero(

                    tag:
                        '${widget.vehicle['model']}$index',

                    child: CachedNetworkImage(
                      imageUrl: photos[index],
                      fit: BoxFit.cover,
                      width: double.infinity,

                      placeholder: (context, url) =>
                          const Center(
                        child:
                            CircularProgressIndicator(),
                      ),

                      errorWidget:
                          (context, url, error) =>
                              const Icon(
                        Icons.directions_bike,
                        size: 80,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // DOT INDICATOR
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: List.generate(
                photos.length,
                (index) {

                  return AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 300),

                    margin:
                        const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),

                    width:
                        selectedImage == index
                        ? 24
                        : 8,

                    height: 8,

                    decoration: BoxDecoration(
                      color:
                          selectedImage == index
                          ? theme.colorScheme.primary
                          : Colors.grey.shade300,

                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // BRAND
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: theme
                          .colorScheme.primary
                          .withOpacity(0.1),

                      borderRadius:
                          BorderRadius.circular(20),
                    ),

                    child: Text(
                      widget.vehicle['brand'] ?? '',

                      style: TextStyle(
                        color:
                            theme.colorScheme.primary,

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

                      const Icon(
                        Icons.currency_rupee,
                        color: Colors.green,
                        size: 28,
                      ),

                      Text(
                        widget.vehicle['price']
                            .toString(),

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

                        final isSelected =
                            selectedColor == index;

                        return GestureDetector(

                          onTap: () {
                            setState(() {
                              selectedColor = index;
                            });
                          },

                          child: AnimatedContainer(

                            duration:
                                const Duration(
                              milliseconds: 250,
                            ),

                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),

                            decoration: BoxDecoration(

                              color: isSelected
                                  ? theme
                                      .colorScheme
                                      .primary
                                  : Colors.grey.shade100,

                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                            ),

                            child: Text(
                              colors[index],

                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(

                      style:
                          ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 18,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                      ),

                      onPressed: () {},

                      child: const Text(
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