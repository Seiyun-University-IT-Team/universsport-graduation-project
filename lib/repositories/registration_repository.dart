import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/registration_model.dart';

class DuplicateRegistrationException implements Exception {
  const DuplicateRegistrationException();

  @override
  String toString() => 'DuplicateRegistrationException';
}

class RegistrationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'registrations';

  Future<void> addRegistration(RegistrationModel registration) async {
    await _firestore
        .collection(_collection)
        .doc(registration.id)
        .set(registration.toMap());
  }

  Future<void> addCompetitionRegistrationOnce({
    required String userId,
    required String sportId,
    required String competitionId,
  }) async {
    final existingRegistration = await getCompetitionRegistration(
      userId: userId,
      competitionId: competitionId,
    );

    if (existingRegistration != null) {
      throw const DuplicateRegistrationException();
    }

    final registration = RegistrationModel(
      id: _competitionRegistrationId(userId, competitionId),
      userId: userId,
      sportId: sportId,
      competitionId: competitionId,
      status: 'pending',
      registrationDate: DateTime.now(),
    );

    try {
      await addRegistration(registration);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final latestRegistration = await getCompetitionRegistration(
          userId: userId,
          competitionId: competitionId,
        );
        if (latestRegistration != null) {
          throw const DuplicateRegistrationException();
        }
      }

      rethrow;
    }
  }

  Future<RegistrationModel?> getCompetitionRegistration({
    required String userId,
    required String competitionId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs) {
      final registration = RegistrationModel.fromFirestore(doc);
      if (registration.competitionId == competitionId) {
        return registration;
      }
    }

    return null;
  }

  Future<void> updateRegistrationStatus(String id, String status) async {
    await _firestore.collection(_collection).doc(id).update({'status': status});
  }

  Stream<List<RegistrationModel>> getRegistrationsByUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RegistrationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<RegistrationModel>> getPendingRegistrations() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final registrations = snapshot.docs
              .map((doc) => RegistrationModel.fromFirestore(doc))
              .toList();
          registrations.sort(
            (a, b) => b.registrationDate.compareTo(a.registrationDate),
          );
          return registrations;
        });
  }

  String _competitionRegistrationId(String userId, String competitionId) {
    final safeUserId = userId.replaceAll('/', '_');
    final safeCompetitionId = competitionId.replaceAll('/', '_');
    return '${safeUserId}_$safeCompetitionId';
  }
}
