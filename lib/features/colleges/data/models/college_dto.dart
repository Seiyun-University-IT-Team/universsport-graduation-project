import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/college.dart';

class CollegeDto extends College {
  const CollegeDto({required super.id, required super.name});

  factory CollegeDto.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = data['name'];

    if (name is! String || name.trim().isEmpty) {
      throw FormatException('College ${doc.id} is missing a valid name.');
    }

    return CollegeDto(id: doc.id, name: name.trim());
  }
}
