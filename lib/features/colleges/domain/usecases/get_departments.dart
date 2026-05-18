import '../entities/department.dart';
import '../repositories/college_repository.dart';

class GetDepartments {
  final CollegeRepository _repository;

  const GetDepartments(this._repository);

  Future<List<Department>> call(String collegeId) {
    return _repository.getDepartments(collegeId);
  }
}
