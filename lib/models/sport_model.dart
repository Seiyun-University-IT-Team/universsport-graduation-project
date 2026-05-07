import 'package:cloud_firestore/cloud_firestore.dart';

class SportModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final bool isActive;

  SportModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconName = 'sports',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon_name': iconName,
      'is_active': isActive,
    };
  }

  factory SportModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return SportModel(
      id: doc.id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconName: map['icon_name'] ?? 'sports',
      isActive: map['is_active'] ?? true,
    );
  }
}
