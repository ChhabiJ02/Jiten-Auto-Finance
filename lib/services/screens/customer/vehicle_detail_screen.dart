import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'new_vehicle_booking_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final photos =
        (widget.vehicle['photos']
                    as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            [];

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // IMAGE SLIDER
            if (photos.isNotEmpty)
              SizedBox(
                height: 320,

                child: PageView.builder(
                  itemCount: photos.length,

                  onPageChanged: (index) {
                    setState(() {
                      selectedImage = index;
                    });
                  },

                  itemBuilder:
                      (context, index) {

                    return Hero(
                      tag:
                          '${widget.vehicle['model']}$index',

                      child:
                          CachedNetworkImage(
                        imageUrl:
                            photos[index],

                        fit: BoxFit.cover,

                        width: double.infinity,

                        placeholder:
                            (context, url) {

                          return const Center(
                            child:
                                CircularProgressIndicator(),
                          );
                        },

                        errorWidget:
                            (
                              context,
                              url,
                              error,
                            ) {

                          return const Icon(
                            Icons
                                .directions_bike,
                            size: 80,
                          );
                        },
                      ),
                    );
                  },
                ),
              )

            else

              Container(
                height: 220,

                color: theme.colorScheme
                    .surfaceContainerHighest,

                child: const Center(
                  child: Icon(
                    Icons.directions_bike,
                    size: 80,
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // DOT INDICATOR
            if (photos.length > 1)

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: List.generate(
                  photos.length,

                  (index) {

                    return AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 300,
                      ),

                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 4,
                      ),

                      width:
                          selectedImage == index
                              ? 24
                              : 8,

                      height: 8,

                      decoration:
                          BoxDecoration(
                        color:
                            selectedImage ==
                                    index
                                ? theme
                                    .colorScheme
                                    .primary
                                : Colors.grey
                                    .shade300,

                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding:
                  const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // BRAND CHIP
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
                          BorderRadius.circular(
                        20,
                      ),
                    ),

                    child: Text(
                      widget.vehicle['brand'] ??
                          '',

                      style: TextStyle(
                        color: theme
                            .colorScheme.primary,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // MODEL
                  Text(
                    widget.vehicle['model'] ??
                        '',

                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // VARIANT
                  Text(
                    widget.vehicle['variant'] ??
                        '',

                    style: TextStyle(
                      fontSize: 18,
                      color:
                          Colors.grey.shade700,
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

                        style:
                            const TextStyle(
                          fontSize: 30,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  const SizedBox(height: 100),

                  // BOOK NOW BUTTON
                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(

                      style:
                          ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 18,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                        ),
                      ),

                      onPressed: () {

                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) =>
                                NewVehicleBookingScreen(
                              vehicle:
                                  widget.vehicle,
                            ),
                          ),
                        );
                      },

                      child: const Text(
                        "Book Inquiry",

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
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