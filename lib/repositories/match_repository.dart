import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'matches';

  Future<void> addMatch(MatchModel match) async {
    await _firestore.collection(_collection).doc(match.id).set(match.toMap());
  }

  Future<void> updateMatch(MatchModel match) async {
    await _firestore
        .collection(_collection)
        .doc(match.id)
        .update(match.toMap());
  }

  Future<MatchModel?> getMatchById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return MatchModel.fromFirestore(doc);
  }

  Future<void> deleteMatch(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<MatchModel>> getMatchesByCompetition(String competitionId) {
    return _firestore
        .collection(_collection)
        .where('competition_id', isEqualTo: competitionId)
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .toList();
          matches.sort((a, b) => a.matchTime.compareTo(b.matchTime));
          return matches;
        });
  }

  Stream<List<MatchModel>> getAllMatches() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => MatchModel.fromFirestore(doc))
          .toList();
      matches.sort((a, b) => a.matchTime.compareTo(b.matchTime));
      return matches;
    });
  }

  Stream<List<MatchModel>> getUpcomingMatches() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'scheduled')
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .toList();
          matches.sort((a, b) => a.matchTime.compareTo(b.matchTime));
          return matches.take(10).toList();
        });
  }

  Stream<List<MatchModel>> getCompletedMatches() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .toList();
          matches.sort((a, b) => b.matchTime.compareTo(a.matchTime));
          return matches.take(10).toList();
        });
  }
}
