import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:cloud_functions/cloud_functions.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final roles = ['customer', 'staff', 'admin'];

  // Temporary selected roles
  final Map<String, String> selectedRoles = {};

  String _resolveUserUid(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawUid = data?['uid']?.toString().trim();

    if (rawUid != null && rawUid.isNotEmpty) {
      return rawUid;
    }

    return doc.id;
  }

  String _normalizeRole(String? role) {
    final normalizedRole =
        role?.trim().toLowerCase() ?? 'customer';

    if (normalizedRole == 'workshop') {
      return 'staff';
    }

    return normalizedRole;
  }

  Set<String> _buildUserIdentifiers(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {
      doc.id,
      _resolveUserUid(doc),
    }.where((value) => value.trim().isNotEmpty).toSet();
  }

  bool _matchesUserIdentifier(
    dynamic fieldValue,
    Set<String> identifiers,
  ) {
    final normalizedValue = fieldValue?.toString().trim();

    return normalizedValue != null &&
        normalizedValue.isNotEmpty &&
        identifiers.contains(normalizedValue);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadTransferCandidates({
    required String deletedUserDocId,
    required List<String> roles,
  }) async {
    final snapshot = await _firestore.collection('users').get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final role = _normalizeRole(
        data['role']?.toString(),
      );
      final isDisabled = data['isDisabled'] == true;
      final identifiers = _buildUserIdentifiers(doc);

      if (isDisabled || !roles.contains(role)) {
        return false;
      }

      return !identifiers.contains(deletedUserDocId);
    }).toList();
  }

  Future<void> updateRole(String userId, String newRole) async {
    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'roleUpdatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isDisabled': true,
    });

    await Future.delayed(const Duration(seconds: 2));

    await _firestore.collection('users').doc(userId).delete();
  }

  Future<int> transferInquiries(String oldUserDocId, String newUserDocId) async {
    final oldUserDoc =
        await _firestore.collection('users').doc(oldUserDocId).get();
    final newUserDoc =
        await _firestore.collection('users').doc(newUserDocId).get();

    if (!oldUserDoc.exists || !newUserDoc.exists) {
      return 0;
    }

    final sourceIdentifiers =
        _buildUserIdentifiers(oldUserDoc);
    final targetUserUid =
        _resolveUserUid(newUserDoc);

    final snapshot =
        await _firestore.collection('inquiries').get();

    final transferredAt = Timestamp.now();
    final transferredFrom =
        _resolveUserUid(oldUserDoc);
    int transferredCount = 0;
    int pendingWrites = 0;
    WriteBatch batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final staffId = data['staffId'];
      final createdBy = data['createdBy'];
      final assignedTo = data['assignedTo'];

      if (_matchesUserIdentifier(staffId, sourceIdentifiers) ||
          _matchesUserIdentifier(createdBy, sourceIdentifiers) ||
          _matchesUserIdentifier(assignedTo, sourceIdentifiers)) {
        batch.update(doc.reference, {
          'staffId': targetUserUid,
          'assignedTo': targetUserUid,
          'createdBy': targetUserUid,
          'lastTransferredAt': transferredAt,
          'lastTransferredFrom': transferredFrom,
          'lastTransferredTo': targetUserUid,
        });

        transferredCount++;
        pendingWrites++;

        if (pendingWrites == 400) {
          await batch.commit();
          batch = _firestore.batch();
          pendingWrites = 0;
        }
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }

    return transferredCount;
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
    if (role == 'staff') {
      final staffList =
          await _loadTransferCandidates(
        deletedUserDocId: userId,
        roles: ['staff'],
      );

      if (staffList.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Staff Available"),
            content: const Text(
              "There is no other staff account available to transfer leads.",
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
                  final displayName =
                      (data['name'] ?? 'No Name').toString();

                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(displayName),
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

                try {
                  final transferredCount =
                      await transferInquiries(userId, selectedStaffId!);

                  await deleteUser(userId);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        transferredCount > 0
                            ? "User deleted & $transferredCount lead(s) transferred"
                            : "User deleted. No matching leads were found to transfer.",
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Failed to transfer leads: $e",
                      ),
                    ),
                  );
                }
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
      final adminList =
          await _loadTransferCandidates(
        deletedUserDocId: userId,
        roles: ['admin'],
      );

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

                try {
                  final transferredCount =
                      await transferInquiries(userId, selectedAdminId!);

                  await deleteUser(userId);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        transferredCount > 0
                            ? "Admin deleted & $transferredCount lead(s) transferred"
                            : "Admin deleted. No matching leads were found to transfer.",
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Failed to transfer leads: $e",
                      ),
                    ),
                  );
                }
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

          // Compute role counts
          final counts = <String, int>{'admin': 0, 'staff': 0, 'customer': 0};
          for (final doc in users) {
            final data = doc.data() as Map<String, dynamic>;
            final role = _normalizeRole(data['role']?.toString());
            if (counts.containsKey(role)) counts[role] = counts[role]! + 1;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Chip(label: Text('Admins: ${counts['admin']}')),
                    Chip(label: Text('Staff: ${counts['staff']}')),
                    Chip(label: Text('Customers: ${counts['customer']}')),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,

                  itemBuilder: (context, index) {
                    final doc = users[index];

                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name'] ?? 'No Name';
                    final email = data['email'] ?? '';

                    final currentRole = _normalizeRole(
                      data['role']?.toString(),
                    );

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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
