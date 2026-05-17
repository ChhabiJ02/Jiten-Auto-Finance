import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyInquiriesScreen extends StatelessWidget {
  const MyInquiriesScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'My Inquiries',
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('inquiries')
            .where(
            'customerId',
            isEqualTo: user.uid,
            )
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.hasError) {

            return const Center(
              child: Text(
                'Failed to load inquiries',
              ),
            );
          }

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

        final docs =
            snapshot.data!.docs;

        docs.sort((a, b) {

        final aTime =
            (a['createdAt'] as Timestamp?)
                ?.millisecondsSinceEpoch ?? 0;

        final bTime =
            (b['createdAt'] as Timestamp?)
                ?.millisecondsSinceEpoch ?? 0;

        return bTime.compareTo(aTime);
        });

          if (docs.isEmpty) {

            return Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [

                  Icon(
                    Icons.inbox_outlined,
                    size: 70,
                    color:
                        Colors.grey.shade400,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'No inquiries yet',
                    style: theme
                        .textTheme
                        .titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(

            padding:
                const EdgeInsets.all(16),

            itemCount: docs.length,

            itemBuilder:
                (context, index) {

              final data =
                  docs[index].data()
                      as Map<String, dynamic>;

              final createdAt =
                  data['createdAt']
                      as Timestamp?;

              final formattedDate =
                  createdAt != null
                      ? DateFormat(
                          'dd MMM yyyy • hh:mm a',
                        ).format(
                          createdAt.toDate(),
                        )
                      : 'Unknown date';

              return Card(

                margin:
                    const EdgeInsets.only(
                  bottom: 14,
                ),

                child: Padding(

                  padding:
                      const EdgeInsets.all(
                    16,
                  ),

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      // MODEL
                      Text(
                        data['model'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      // VARIANT
                      Text(
                        data['variant'] ?? '',
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // PRICE
                      Row(
                        children: [

                          const Icon(
                            Icons.currency_rupee,
                            color: Colors.green,
                            size: 18,
                          ),

                          Text(
                            data['price']
                                    ?.toString() ??
                                '',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Colors.green,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // STATUS
                      Container(

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color: theme
                              .colorScheme
                              .primary
                              .withOpacity(
                                0.1,
                              ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Text(
                          data['status'] ??
                              'Pending',

                          style: TextStyle(
                            color: theme
                                .colorScheme
                                .primary,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // DATE TIME
                      Row(
                        children: [

                          Icon(
                            Icons.access_time,
                            size: 18,
                            color:
                                Colors.grey
                                    .shade600,
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors
                                  .grey.shade700,
                            ),
                          ),
                        ],
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