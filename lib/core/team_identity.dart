const _academicLevelNames = <String>[
  'الأول',
  'الثاني',
  'الثالث',
  'الرابع',
  'الخامس',
  'السادس',
];

String academicLevelName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final withoutPrefix = trimmed.replaceFirst('المستوى ', '').trim();

  final numericLevel = int.tryParse(withoutPrefix);
  if (numericLevel != null &&
      numericLevel >= 1 &&
      numericLevel <= _academicLevelNames.length) {
    return _academicLevelNames[numericLevel - 1];
  }

  for (final levelName in _academicLevelNames) {
    if (trimmed == levelName || trimmed.contains(levelName)) {
      return levelName;
    }
  }

  return withoutPrefix;
}

String departmentLevelTeamName({
  required String department,
  required String academicLevel,
}) {
  return '${department.trim()} المستوى ${academicLevelName(academicLevel)}';
}

String departmentLevelTeamId({
  required String college,
  required String department,
  required String academicLevel,
}) {
  return [
    college,
    department,
    academicLevelName(academicLevel),
  ].map(_safeTeamSegment).join('_');
}

String _safeTeamSegment(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), '_');
}
