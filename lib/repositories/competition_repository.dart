import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/competition_model.dart';

class CompetitionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'competitions';

  Future<void> addCompetition(CompetitionModel competition) async {
    await _firestore
        .collection(_collection)
        .doc(competition.id)
        .set(competition.toMap());
  }

  Future<void> updateCompetition(CompetitionModel competition) async {
    await _firestore
        .collection(_collection)
        .doc(competition.id)
        .update(competition.toMap());
  }

  Future<void> deleteCompetition(String id) async {
    final matchesSnapshot = await _firestore
        .collection('matches')
        .where('competition_id', isEqualTo: id)
        .get();

    for (final matchDoc in matchesSnapshot.docs) {
      await _deleteQuery(
        _firestore
            .collection('notifications')
            .where('related_id', isEqualTo: matchDoc.id),
      );
    }

    await _deleteSnapshot(matchesSnapshot);
    await _deleteQuery(
      _firestore
          .collection('registrations')
          .where('competition_id', isEqualTo: id),
    );
    await _deleteQuery(
      _firestore.collection('notifications').where('related_id', isEqualTo: id),
    );
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    await _deleteSnapshot(snapshot);
  }

  Future<void> _deleteSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    WriteBatch batch = _firestore.batch();
    var operationCount = 0;

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;
      if (operationCount >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
  }

  Future<CompetitionModel?> getCompetitionById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return CompetitionModel.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateChampion({
    required String competitionId,
    required String championId,
    required String championName,
    bool markCompleted = true,
  }) async {
    await _firestore.collection(_collection).doc(competitionId).update({
      'champion_id': championId,
      'champion_name': championName,
      if (markCompleted) 'status': 'completed',
    });
  }

  Stream<List<CompetitionModel>> getAllCompetitions() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final competitions = snapshot.docs
          .map((doc) => CompetitionModel.fromFirestore(doc))
          .toList();
      competitions.sort((a, b) => b.startDate.compareTo(a.startDate));
      return competitions;
    });
  }

  Stream<List<CompetitionModel>> getChampionCompetitions() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final competitions = snapshot.docs
          .map((doc) => CompetitionModel.fromFirestore(doc))
          .where((competition) => competition.championId != null)
          .toList();
      competitions.sort((a, b) => b.endDate.compareTo(a.endDate));
      return competitions;
    });
  }

  Stream<List<CompetitionModel>> getCompetitionsBySport(String sportId) {
    return _firestore
        .collection(_collection)
        .where('sport_id', isEqualTo: sportId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CompetitionModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<CompetitionModel>> getActiveCompetitions() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CompetitionModel.fromFirestore(doc))
              .toList(),
        );
  }
}
