import '../entities/college.dart';
import '../repositories/college_repository.dart';

class GetColleges {
  final CollegeRepository _repository;

  const GetColleges(this._repository);

  Future<List<College>> call() {
    return _repository.getColleges();
  }
}
