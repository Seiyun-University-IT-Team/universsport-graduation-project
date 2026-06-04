import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationModel {
  final String id;
  final String userId;
  final String sportId;
  final String? competitionId;
  final String status;
  final DateTime registrationDate;

  RegistrationModel({
    required this.id,
    required this.userId,
    required this.sportId,
    this.competitionId,
    required this.status,
    required this.registrationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'sport_id': sportId,
      'competition_id': competitionId,
      'status': status,
      'registration_date': Timestamp.fromDate(registrationDate),
    };
  }

  factory RegistrationModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final rawRegistrationDate = map['registration_date'];

    return RegistrationModel(
      id: doc.id,
      userId: map['user_id'] ?? '',
      sportId: map['sport_id'] ?? '',
      competitionId: map['competition_id'],
      status: map['status'] ?? 'pending',
      registrationDate: rawRegistrationDate is Timestamp
          ? rawRegistrationDate.toDate()
          : rawRegistrationDate is DateTime
          ? rawRegistrationDate
          : DateTime.now(),
    );
  }
}
