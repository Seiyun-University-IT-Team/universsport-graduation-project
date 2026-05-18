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
    await _firestore.collection(_collection).doc(id).set({
      'is_deleted': true,
      'players': <String>[],
      'captain_id': null,
    }, SetOptions(merge: true));
  }

  Stream<TeamModel?> watchTeam(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final team = TeamModel.fromFirestore(doc);
      if (team.isDeleted) return null;
      return team;
    });
  }

  Future<void> addPlayer(String teamId, String userId) async {
    await _firestore.collection(_collection).doc(teamId).update({
      'players': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removePlayer(String teamId, String userId) async {
    await _firestore.collection(_collection).doc(teamId).update({
      'players': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> setCaptain(String teamId, String? userId) async {
    await _firestore.collection(_collection).doc(teamId).update({
      'captain_id': userId,
    });
  }

  Stream<List<TeamModel>> getAllTeams({bool includeDeleted = false}) {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final teams = snapshot.docs
          .map((doc) => TeamModel.fromFirestore(doc))
          .toList();
      if (includeDeleted) return teams;
      return teams.where((team) => !team.isDeleted).toList();
    });
  }

  Future<TeamModel?> getTeamById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      final team = TeamModel.fromFirestore(doc);
      if (!team.isDeleted) return team;
    }
    return null;
  }
}
