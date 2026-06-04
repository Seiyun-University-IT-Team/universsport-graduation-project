import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/department.dart';

class DepartmentDto extends Department {
  const DepartmentDto({
    required super.id,
    required super.collegeId,
    required super.name,
  });

  factory DepartmentDto.fromFirestore({
    required String collegeId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final name = data['name'];

    if (name is! String || name.trim().isEmpty) {
      throw FormatException(
        'Department ${doc.id} in college $collegeId is missing a valid name.',
      );
    }

    return DepartmentDto(id: doc.id, collegeId: collegeId, name: name.trim());
  }
}
