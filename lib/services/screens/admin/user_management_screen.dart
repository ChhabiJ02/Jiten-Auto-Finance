import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final roles = ['customer', 'staff', 'admin', 'workshop'];

  // Temporary selected roles
  final Map<String, String> selectedRoles = {};

  Future<void> updateRole(String userId, String newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole,
      'roleUpdatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isDisabled': true,
    });

    await Future.delayed(const Duration(seconds: 2));

    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
  }

  Future<void> transferInquiries(String oldId, String newId) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('inquiries').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final staffId = data['staffId'];
      final createdBy = data['createdBy'];
      final assignedTo = data['assignedTo'];

      if (staffId == oldId || createdBy == oldId || assignedTo == oldId) {
        await doc.reference.update({
          'staffId': newId,
          'assignedTo': newId,
          'createdBy': newId,
        });
      }
    }
  }

  void confirmRoleChange({
    required String userId,
    required String userName,
    required String oldRole,
    required String newRole,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Role Change"),

        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
            children: [
              const TextSpan(text: "Are you sure you want to change "),
              TextSpan(
                text: userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: "'s role from "),
              TextSpan(
                text: oldRole.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: " to "),
              TextSpan(
                text: newRole.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const TextSpan(text: "?"),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedRoles[userId] = oldRole;
              });

              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              await updateRole(userId, newRole);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "$userName role updated to ${newRole.toUpperCase()}",
                  ),
                ),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void confirmDelete(String userId, String name, String role) async {
    // CUSTOMER — simple delete
    if (role == 'customer') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Delete User"),
          content: Text("Are you sure you want to delete $name?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.pop(context);

                await deleteUser(userId);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("User deleted"),
                  ),
                );
              },
              child: const Text("Delete"),
            ),
          ],
        ),
      );

      return;
    }

    // =========================
    // STAFF DELETE
    // =========================
    if (role == 'staff' || role == 'workshop') {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['staff', 'workshop'])
          .get();

      final staffList =
          staffSnapshot.docs.where((doc) => doc.id != userId).toList();

      if (staffList.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Staff Available"),
            content: const Text(
              "There is no other staff/workshop account available to transfer leads.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );

        return;
      }

      String? selectedStaffId;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Transfer Leads & Delete"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Transfer all leads of $name to:"),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                hint: const Text("Select Staff"),

                items: staffList.map((doc) {
                  final data = doc.data();

                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(data['name'] ?? 'No Name'),
                  );
                }).toList(),

                onChanged: (value) => selectedStaffId = value,
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                if (selectedStaffId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Select a staff first"),
                    ),
                  );

                  return;
                }

                Navigator.pop(context);

                await transferInquiries(userId, selectedStaffId!);

                await deleteUser(userId);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "User deleted & leads transferred",
                    ),
                  ),
                );
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      );

      return;
    }

    // =========================
    // ADMIN DELETE
    // =========================
    if (role == 'admin') {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final adminList =
          adminSnapshot.docs.where((doc) => doc.id != userId).toList();

      // No other admin
      if (adminList.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Admin Available"),
            content: const Text(
              "This admin account cannot be deleted because no other admin account exists.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );

        return;
      }

      String? selectedAdminId;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Transfer Leads To Another Admin"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Transfer all leads of $name to:"),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                hint: const Text("Select Admin"),

                items: adminList.map((doc) {
                  final data = doc.data();

                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(data['name'] ?? 'No Name'),
                  );
                }).toList(),

                onChanged: (value) => selectedAdminId = value,
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                if (selectedAdminId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Select an admin first"),
                    ),
                  );

                  return;
                }

                Navigator.pop(context);

                await transferInquiries(userId, selectedAdminId!);

                await deleteUser(userId);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Admin deleted & leads transferred",
                    ),
                  ),
                );
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      );

      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,

            itemBuilder: (context, index) {
              final doc = users[index];

              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] ?? 'No Name';
              final email = data['email'] ?? '';

              final currentRole = data['role'] ?? 'customer';

              selectedRoles.putIfAbsent(
                doc.id,
                () => currentRole,
              );

              return Card(
                margin: const EdgeInsets.all(10),

                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),

                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),

                      Text(email),

                      const SizedBox(height: 10),

                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRoles[doc.id],

                        items: roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase()),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null &&
                              value != currentRole) {
                            setState(() {
                              selectedRoles[doc.id] = value;
                            });

                            confirmRoleChange(
                              userId: doc.id,
                              userName: name,
                              oldRole: currentRole,
                              newRole: value,
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
                    onPressed: () => confirmDelete(
                      doc.id,
                      name,
                      currentRole,
                    ),
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