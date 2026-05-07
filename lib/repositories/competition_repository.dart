import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/competition_model.dart';

class CompetitionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'competitions';

  Future<void> addCompetition(CompetitionModel competition) async {
    await _firestore.collection(_collection).doc(competition.id).set(competition.toMap());
  }

  Future<void> updateCompetition(CompetitionModel competition) async {
    await _firestore.collection(_collection).doc(competition.id).update(competition.toMap());
  }

  Future<void> deleteCompetition(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<CompetitionModel>> getCompetitionsBySport(String sportId) {
    return _firestore
        .collection(_collection)
        .where('sport_id', isEqualTo: sportId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CompetitionModel.fromFirestore(doc)).toList());
  }

  Stream<List<CompetitionModel>> getActiveCompetitions() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CompetitionModel.fromFirestore(doc)).toList());
  }
}
