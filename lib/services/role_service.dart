import 'package:cloud_firestore/cloud_firestore.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _normalizeRole(dynamic rawRole) {
    final role = rawRole?.toString().trim().toLowerCase();

    if (role == 'workshop') {
      return 'staff';
    }

    return role;
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return _normalizeRole(
          doc.data()?['role'],
        );
      }
      return null;
    } catch (e) {
      print("Error fetching role: $e");
      return null;
    }
  }
}
