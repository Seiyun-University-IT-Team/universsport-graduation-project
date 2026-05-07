import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'matches';

  Future<void> addMatch(MatchModel match) async {
    await _firestore.collection(_collection).doc(match.id).set(match.toMap());
  }

  Future<void> updateMatch(MatchModel match) async {
    await _firestore.collection(_collection).doc(match.id).update(match.toMap());
  }

  Future<void> deleteMatch(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<MatchModel>> getMatchesByCompetition(String competitionId) {
    return _firestore
        .collection(_collection)
        .where('competition_id', isEqualTo: competitionId)
        .orderBy('match_time')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList());
  }

  Stream<List<MatchModel>> getUpcomingMatches() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('match_time')
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList());
  }
}
