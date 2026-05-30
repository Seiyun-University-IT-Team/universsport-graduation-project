import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  Future<void> createUser(UserModel user) async {
    await _firestore.collection(_collection).doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection(_collection).doc(user.id).update(user.toMap());
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<UserModel>> getStudents() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Stream<List<UserModel>> getStudentsByCollege(String college) {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'student')
        .where('college', isEqualTo: college)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }
}
