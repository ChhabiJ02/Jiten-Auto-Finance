import 'package:cloud_firestore/cloud_firestore.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return doc['role'];
      }
      return null;
    } catch (e) {
      print("Error fetching role: $e");
      return null;
    }
  }
}