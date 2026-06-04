class College {
  final String id;
  final String name;

  const College({required this.id, required this.name});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is College && runtimeType == other.runtimeType && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
