import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/registration_model.dart';

class RegistrationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'registrations';

  Future<void> addRegistration(RegistrationModel registration) async {
    await _firestore.collection(_collection).doc(registration.id).set(registration.toMap());
  }

  Future<void> updateRegistrationStatus(String id, String status) async {
    await _firestore.collection(_collection).doc(id).update({'status': status});
  }

  Stream<List<RegistrationModel>> getRegistrationsByUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RegistrationModel.fromFirestore(doc)).toList());
  }

  Stream<List<RegistrationModel>> getPendingRegistrations() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RegistrationModel.fromFirestore(doc)).toList());
  }
}
