class Department {
  final String id;
  final String collegeId;
  final String name;

  const Department({
    required this.id,
    required this.collegeId,
    required this.name,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Department &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            collegeId == other.collegeId;
  }

  @override
  int get hashCode => Object.hash(id, collegeId);
}
