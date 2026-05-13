import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final roles = ['customer', 'staff', 'admin', 'workshop'];

  Future<void> updateRole(String userId, String newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole,
      // 🔑 Triggers auto-logout on user's device via their session listener
      'roleUpdatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteUser(String userId) async {
    // 🔑 Mark as disabled first — user's device detects this and logs out
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isDisabled': true,
    });
    // Small delay to allow the user's listener to trigger before doc is gone
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await deleteUser(userId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User deleted")),
                );
              },
              child: const Text("Delete"),
            ),
          ],
        ),
      );
      return;
    }

    // STAFF/ADMIN/WORKSHOP — fetch other staff for transfer
    final staffSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['staff', 'admin', 'workshop'])
        .get();

    final staffList =
        staffSnapshot.docs.where((doc) => doc.id != userId).toList();

    String? selectedStaffId;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reassign & Delete"),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (selectedStaffId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Select a staff first")),
                );
                return;
              }
              Navigator.pop(context);
              await transferInquiries(userId, selectedStaffId!);
              await deleteUser(userId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("User deleted & leads reassigned"),
                ),
              );
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Users")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'No Name';
              final email = data['email'] ?? '';
              String role = data['role'] ?? 'customer';

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: role,
                        items: roles.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value != null) {
                            await updateRole(doc.id, value);
                          }
                        },
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => confirmDelete(doc.id, name, role),
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
