import '../entities/college.dart';
import '../entities/department.dart';

abstract class CollegeRepository {
  Future<List<College>> getColleges();

  Future<List<Department>> getDepartments(String collegeId);
}
