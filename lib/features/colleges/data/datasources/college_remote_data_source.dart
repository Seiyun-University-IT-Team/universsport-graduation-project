import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/college_dto.dart';
import '../models/department_dto.dart';

abstract class CollegeRemoteDataSource {
  Future<List<CollegeDto>> fetchColleges();

  Future<List<DepartmentDto>> fetchDepartments(String collegeId);
}

class FirestoreCollegeRemoteDataSource implements CollegeRemoteDataSource {
  final FirebaseFirestore _firestore;

  const FirestoreCollegeRemoteDataSource(this._firestore);

  @override
  Future<List<CollegeDto>> fetchColleges() async {
    final snapshot = await _firestore
        .collection('colleges')
        .orderBy('name')
        .get();

    return snapshot.docs.map(CollegeDto.fromFirestore).toList();
  }

  @override
  Future<List<DepartmentDto>> fetchDepartments(String collegeId) async {
    final snapshot = await _firestore
        .collection('colleges')
        .doc(collegeId)
        .collection('departments')
        .orderBy('name')
        .get();

    return snapshot.docs
        .map(
          (doc) => DepartmentDto.fromFirestore(collegeId: collegeId, doc: doc),
        )
        .toList();
  }
}
