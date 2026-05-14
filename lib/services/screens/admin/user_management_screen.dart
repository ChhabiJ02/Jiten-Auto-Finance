import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends State<UserManagementScreen> {

  final roles = [
    'customer',
    'staff',
    'admin',
    'workshop',
  ];

  Future<void> updateRole(
    String userId,
    String newRole,
  ) async {

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'role': newRole,
    });
  }

  Future<void> deleteUser(
    String userId,
  ) async {

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .delete();
  }

  // 🔥 TRANSFER ALL LEADS
  Future<void> transferInquiries(
    String oldId,
    String newId,
  ) async {

    final snapshot =
        await FirebaseFirestore.instance
            .collection('inquiries')
            .get();

    for (var doc in snapshot.docs) {

      final data =
          doc.data();

      final staffId =
          data['staffId'];

      final createdBy =
          data['createdBy'];

      final assignedTo =
          data['assignedTo'];

      // ✅ MATCH ANY OLD STAFF FIELD
      if (
          staffId == oldId ||
          createdBy == oldId ||
          assignedTo == oldId
      ) {

        await doc.reference.update({

          // ✅ NEW STAFF OWNER
          'staffId': newId,

          // ✅ NEW ASSIGNED STAFF
          'assignedTo': newId,

          // ✅ ALSO UPDATE CREATOR
          'createdBy': newId,
        });
      }
    }
  }

  // 🔴 DELETE WITH TRANSFER
  void confirmDelete(
    String userId,
    String name,
    String role,
  ) async {

    // CUSTOMER SIMPLE DELETE
    if (role == 'customer') {

      showDialog(

        context: context,

        builder: (_) => AlertDialog(

          title: const Text(
            "Delete User",
          ),

          content: Text(
            "Are you sure you want to delete $name?",
          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);
              },

              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),

              onPressed: () async {

                await deleteUser(userId);

                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(

                  const SnackBar(
                    content: Text(
                      "User deleted",
                    ),
                  ),
                );
              },

              child: const Text(
                "Delete",
              ),
            ),
          ],
        ),
      );

      return;
    }

    // 🔥 FETCH OTHER STAFF
    final staffSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where(
              'role',
              whereIn: [
                'staff',
                'admin',
                'workshop',
              ],
            )
            .get();

    final staffList =
        staffSnapshot.docs
            .where(
              (doc) => doc.id != userId,
            )
            .toList();

    String? selectedStaffId;

    showDialog(

      context: context,

      builder: (_) => AlertDialog(

        title: const Text(
          "Reassign & Delete",
        ),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Text(
              "Transfer all leads of $name to:",
            ),

            const SizedBox(
              height: 10,
            ),

            DropdownButtonFormField<String>(

              hint: const Text(
                "Select Staff",
              ),

              items:
                  staffList.map((doc) {

                final data = doc.data();

                return DropdownMenuItem(

                  value: doc.id,

                  child: Text(
                    data['name'] ??
                        'No Name',
                  ),
                );

              }).toList(),

              onChanged: (value) {

                selectedStaffId =
                    value;
              },
            ),
          ],
        ),

        actions: [

          TextButton(

            onPressed: () {

              Navigator.pop(context);
            },

            child: const Text(
              "Cancel",
            ),
          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),

            onPressed: () async {

              if (selectedStaffId ==
                  null) {

                ScaffoldMessenger.of(
                        context)
                    .showSnackBar(

                  const SnackBar(
                    content: Text(
                      "Select a staff first",
                    ),
                  ),
                );

                return;
              }

              // 🔥 TRANSFER LEADS
              await transferInquiries(
                userId,
                selectedStaffId!,
              );

              // 🔥 DELETE USER
              await deleteUser(userId);

              Navigator.pop(context);

              ScaffoldMessenger.of(context)
                  .showSnackBar(

                const SnackBar(

                  content: Text(
                    "User deleted & leads reassigned",
                  ),
                ),
              );
            },

            child: const Text(
              "Confirm",
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Manage Users",
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final users =
              snapshot.data!.docs;

          return ListView.builder(

            itemCount: users.length,

            itemBuilder: (
              context,
              index,
            ) {

              final doc = users[index];

              final data =
                  doc.data()
                      as Map<String, dynamic>;

              final name =
                  data['name'] ??
                      'No Name';

              final email =
                  data['email'] ??
                      '';

              String role =
                  data['role'] ??
                      'customer';

              return Card(

                margin:
                    const EdgeInsets.all(10),

                child: ListTile(

                  title: Text(name),

                  subtitle: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Text(email),

                      const SizedBox(
                        height: 6,
                      ),

                      DropdownButton<String>(

                        value: role,

                        items:
                            roles.map((r) {

                          return DropdownMenuItem(

                            value: r,

                            child: Text(
                              r.toUpperCase(),
                            ),
                          );

                        }).toList(),

                        onChanged:
                            (value) async {

                          if (value !=
                              null) {

                            await updateRole(
                              doc.id,
                              value,
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  trailing: IconButton(

                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),

                    onPressed: () {

                      confirmDelete(
                        doc.id,
                        name,
                        role,
                      );
                    },
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