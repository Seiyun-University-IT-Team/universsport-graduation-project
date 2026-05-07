import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String competitionId;
  final String sportId;
  final String teamAId;
  final String teamBId;
  final String teamAName;
  final String teamBName;
  final DateTime matchTime;
  final String status;
  final int scoreA;
  final int scoreB;
  final String? winnerId;

  MatchModel({
    required this.id,
    required this.competitionId,
    required this.sportId,
    required this.teamAId,
    required this.teamBId,
    required this.teamAName,
    required this.teamBName,
    required this.matchTime,
    required this.status,
    this.scoreA = 0,
    this.scoreB = 0,
    this.winnerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'competition_id': competitionId,
      'sport_id': sportId,
      'team_a_id': teamAId,
      'team_b_id': teamBId,
      'team_a_name': teamAName,
      'team_b_name': teamBName,
      'match_time': Timestamp.fromDate(matchTime),
      'status': status,
      'score_a': scoreA,
      'score_b': scoreB,
      'winner_id': winnerId,
    };
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      competitionId: map['competition_id'] ?? '',
      sportId: map['sport_id'] ?? '',
      teamAId: map['team_a_id'] ?? '',
      teamBId: map['team_b_id'] ?? '',
      teamAName: map['team_a_name'] ?? '',
      teamBName: map['team_b_name'] ?? '',
      matchTime: (map['match_time'] as Timestamp).toDate(),
      status: map['status'] ?? 'scheduled',
      scoreA: map['score_a'] ?? 0,
      scoreB: map['score_b'] ?? 0,
      winnerId: map['winner_id'],
    );
  }
}
