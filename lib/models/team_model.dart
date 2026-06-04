import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String college;
  final String? captainId;
  final List<String> players;
  final bool isDeleted;

  TeamModel({
    required this.id,
    required this.name,
    required this.college,
    this.captainId,
    required this.players,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'college': college,
      'captain_id': captainId,
      'players': players,
      'is_deleted': isDeleted,
    };
  }

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final rawPlayers = map['players'];

    return TeamModel(
      id: doc.id,
      name: map['name'] ?? '',
      college: map['college'] ?? '',
      captainId: map['captain_id'],
      players: rawPlayers is Iterable
          ? rawPlayers.whereType<String>().toList()
          : const [],
      isDeleted: map['is_deleted'] == true,
    );
  }
}
