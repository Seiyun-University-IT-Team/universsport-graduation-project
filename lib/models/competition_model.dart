import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionModel {
  final String id;
  final String sportId;
  final String name;
  final String type;
  final String tournamentFormat;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? championId;
  final String? championName;
  final String? college;

  CompetitionModel({
    required this.id,
    required this.sportId,
    required this.name,
    required this.type,
    this.tournamentFormat = 'league',
    required this.status,
    required this.startDate,
    required this.endDate,
    this.championId,
    this.championName,
    this.college,
  });

  Map<String, dynamic> toMap() {
    return {
      'sport_id': sportId,
      'name': name,
      'type': type,
      'tournament_format': tournamentFormat,
      'status': status,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'champion_id': championId,
      'champion_name': championName,
      'college': college,
    };
  }

  factory CompetitionModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CompetitionModel(
      id: doc.id,
      sportId: map['sport_id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'team',
      tournamentFormat: map['tournament_format'] ?? 'league',
      status: map['status'] ?? 'active',
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
      championId: map['champion_id'],
      championName: map['champion_name'],
      college: map['college'] as String?,
    );
  }
}
