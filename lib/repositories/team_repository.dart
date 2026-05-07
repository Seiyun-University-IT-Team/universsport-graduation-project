import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';

class TeamRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'teams';

  Future<void> addTeam(TeamModel team) async {
    await _firestore.collection(_collection).doc(team.id).set(team.toMap());
  }

  Future<void> updateTeam(TeamModel team) async {
    await _firestore.collection(_collection).doc(team.id).update(team.toMap());
  }

  Future<void> deleteTeam(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<TeamModel>> getAllTeams() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
    });
  }

  Future<TeamModel?> getTeamById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return TeamModel.fromFirestore(doc);
    }
    return null;
  }
}
