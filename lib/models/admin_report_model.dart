class AdminReportModel {
  final int sportsCount;
  final int activeSportsCount;
  final int competitionsCount;
  final int activeCompetitionsCount;
  final int teamsCount;
  final int playersCount;
  final int studentsCount;
  final int adminsCount;
  final int matchesCount;
  final int upcomingMatchesCount;
  final int completedMatchesCount;
  final int registrationsCount;
  final int pendingRegistrationsCount;
  final int approvedRegistrationsCount;
  final int rejectedRegistrationsCount;
  final Map<String, int> competitionsByType;
  final Map<String, int> registrationsByStatus;
  final Map<String, int> matchesByStatus;
  final Map<String, int> teamsByCollege;

  const AdminReportModel({
    required this.sportsCount,
    required this.activeSportsCount,
    required this.competitionsCount,
    required this.activeCompetitionsCount,
    required this.teamsCount,
    required this.playersCount,
    required this.studentsCount,
    required this.adminsCount,
    required this.matchesCount,
    required this.upcomingMatchesCount,
    required this.completedMatchesCount,
    required this.registrationsCount,
    required this.pendingRegistrationsCount,
    required this.approvedRegistrationsCount,
    required this.rejectedRegistrationsCount,
    required this.competitionsByType,
    required this.registrationsByStatus,
    required this.matchesByStatus,
    required this.teamsByCollege,
  });
}
