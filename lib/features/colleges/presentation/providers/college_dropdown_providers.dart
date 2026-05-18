import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/college_remote_data_source.dart';
import '../../data/repositories/firestore_college_repository.dart';
import '../../domain/entities/college.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/college_repository.dart';
import '../../domain/usecases/get_colleges.dart';
import '../../domain/usecases/get_departments.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final collegeRemoteDataSourceProvider = Provider<CollegeRemoteDataSource>((
  ref,
) {
  return FirestoreCollegeRemoteDataSource(ref.watch(firestoreProvider));
});

final collegeRepositoryProvider = Provider<CollegeRepository>((ref) {
  return FirestoreCollegeRepository(ref.watch(collegeRemoteDataSourceProvider));
});

final getCollegesProvider = Provider<GetColleges>((ref) {
  return GetColleges(ref.watch(collegeRepositoryProvider));
});

final getDepartmentsProvider = Provider<GetDepartments>((ref) {
  return GetDepartments(ref.watch(collegeRepositoryProvider));
});

final collegesProvider = FutureProvider.autoDispose<List<College>>((ref) {
  return ref.watch(getCollegesProvider)();
});

final departmentsProvider = FutureProvider.autoDispose
    .family<List<Department>, String>((ref, collegeId) {
      return ref.watch(getDepartmentsProvider)(collegeId);
    });

final selectedCollegeProvider =
    NotifierProvider.autoDispose<SelectedCollegeNotifier, College?>(
      SelectedCollegeNotifier.new,
    );

final selectedDepartmentProvider =
    NotifierProvider.autoDispose<SelectedDepartmentNotifier, Department?>(
      SelectedDepartmentNotifier.new,
    );

final selectedAcademicLevelProvider =
    NotifierProvider.autoDispose<SelectedAcademicLevelNotifier, int?>(
      SelectedAcademicLevelNotifier.new,
    );

const academicLevels = <int>[1, 2, 3, 4, 5, 6];

class SelectedCollegeNotifier extends Notifier<College?> {
  @override
  College? build() => null;

  void select(College? college) {
    state = college;
  }
}

class SelectedDepartmentNotifier extends Notifier<Department?> {
  @override
  Department? build() => null;

  void select(Department? department) {
    state = department;
  }
}

class SelectedAcademicLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? level) {
    state = level;
  }
}
