import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionModel {
  final String id;
  final String sportId;
  final String name;
  final String type;
  final String status;
  final DateTime startDate;
  final DateTime endDate;

  CompetitionModel({
    required this.id,
    required this.sportId,
    required this.name,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'sport_id': sportId,
      'name': name,
      'type': type,
      'status': status,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
    };
  }

  factory CompetitionModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CompetitionModel(
      id: doc.id,
      sportId: map['sport_id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'team',
      status: map['status'] ?? 'active',
      startDate: (map['start_date'] as Timestamp).toDate(),
      endDate: (map['end_date'] as Timestamp).toDate(),
    );
  }
}
