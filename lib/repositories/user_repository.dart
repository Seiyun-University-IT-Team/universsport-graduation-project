import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/demo_config.dart';

class UserRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String _collection = 'users';

  Future<void> createUser(UserModel user) async {
    if (AppDemoConfig.useMockData) return;
    await _firestore.collection(_collection).doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    if (AppDemoConfig.useMockData) return;
    await _firestore.collection(_collection).doc(user.id).update(user.toMap());
  }

  Future<UserModel?> getUserById(String id) async {
    if (AppDemoConfig.useMockData) {
      if (id == 'mock_student_id') return AppDemoConfig.studentUser;
      if (id == 'mock_supervisor_id') return AppDemoConfig.supervisorUser;
      if (id == 'mock_admin_id') return AppDemoConfig.adminUser;
      return AppDemoConfig.studentUser;
    }
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<UserModel>> getStudents() {
    if (AppDemoConfig.useMockData) {
      return Stream.value([AppDemoConfig.studentUser]);
    }
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Stream<List<UserModel>> getStudentsByCollege(String college) {
    if (AppDemoConfig.useMockData) {
      return Stream.value([AppDemoConfig.studentUser]);
    }
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: 'student')
        .where('college', isEqualTo: college)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }
}

