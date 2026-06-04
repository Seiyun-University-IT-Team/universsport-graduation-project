import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/college.dart';
import '../../domain/entities/department.dart';
import '../../domain/failures/college_failure.dart';
import '../../domain/repositories/college_repository.dart';
import '../datasources/college_remote_data_source.dart';

class FirestoreCollegeRepository implements CollegeRepository {
  final CollegeRemoteDataSource _remoteDataSource;

  const FirestoreCollegeRepository(this._remoteDataSource);

  @override
  Future<List<College>> getColleges() async {
    try {
      return await _remoteDataSource.fetchColleges();
    } on FirebaseException catch (error, stackTrace) {
      throw CollegeFailure(
        'تعذر تحميل الكليات من قاعدة البيانات.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      throw CollegeFailure(
        'بيانات الكليات غير مكتملة.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<Department>> getDepartments(String collegeId) async {
    try {
      return await _remoteDataSource.fetchDepartments(collegeId);
    } on FirebaseException catch (error, stackTrace) {
      throw CollegeFailure(
        'تعذر تحميل الأقسام من قاعدة البيانات.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      throw CollegeFailure(
        'بيانات الأقسام غير مكتملة.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
