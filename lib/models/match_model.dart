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
  final String? stage;
  final String phase;
  final String? groupId;
  final String? groupName;
  final int? roundIndex;
  final int? matchIndex;
  final int? matchNumber;
  final String? nextMatchId;
  final String? nextSlot;

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
    this.stage,
    this.phase = 'group',
    this.groupId,
    this.groupName,
    this.roundIndex,
    this.matchIndex,
    this.matchNumber,
    this.nextMatchId,
    this.nextSlot,
  });

  bool get isGroupPhase =>
      phase == 'group' ||
      groupId != null ||
      (stage?.contains('المجموعة') ?? false);

  bool get isKnockoutPhase =>
      phase == 'knockout' ||
      roundIndex != null ||
      (stage?.contains('النهائي') ?? false) ||
      (stage?.contains('دور') ?? false);

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
      'stage': stage,
      'phase': phase,
      'group_id': groupId,
      'group_name': groupName,
      'round_index': roundIndex,
      'match_index': matchIndex,
      'match_number': matchNumber,
      'next_match_id': nextMatchId,
      'next_slot': nextSlot,
    };
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final stage = map['stage'] as String?;
    final phase =
        map['phase'] as String? ??
        ((stage?.contains('دور') ?? false) ||
                (stage?.contains('النهائي') ?? false)
            ? 'knockout'
            : 'group');
    final rawMatchNumber = map['match_number'];

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
      stage: stage,
      phase: phase,
      groupId: map['group_id'],
      groupName: map['group_name'],
      roundIndex: map['round_index'],
      matchIndex: map['match_index'],
      matchNumber: rawMatchNumber is num ? rawMatchNumber.toInt() : null,
      nextMatchId: map['next_match_id'],
      nextSlot: map['next_slot'],
    );
  }
}
