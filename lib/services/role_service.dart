import 'package:cloud_firestore/cloud_firestore.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final rawRole = (doc.data() as Map<String, dynamic>?)?['role'];
        if (rawRole is String) {
          return rawRole.trim().toLowerCase();
        }
        return rawRole?.toString().trim().toLowerCase();
      }
      return null;
    } catch (e) {
      print("Error fetching role: $e");
      return null;
    }
  }
}