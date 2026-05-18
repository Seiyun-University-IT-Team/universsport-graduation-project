import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, admin, supervisor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? studentId;
  final String? college;
  final String? department;
  final String? academicLevel;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentId,
    this.college,
    this.department,
    this.academicLevel,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isStudent => role == UserRole.student;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'student_id': studentId,
      'college': college,
      'department': department,
      'academic_level': academicLevel,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: UserRole.values.firstWhere((e) => e.name == map['role']),
      studentId: map['student_id'] as String?,
      college: map['college'] as String?,
      department: map['department'] as String?,
      academicLevel: map['academic_level'] as String?,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere((e) => e.name == map['role'], orElse: () => UserRole.student),
      studentId: map['student_id'] as String?,
      college: map['college'] as String?,
      department: map['department'] as String?,
      academicLevel: map['academic_level'] as String?,
    );
  }
}
