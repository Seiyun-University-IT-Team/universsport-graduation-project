import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_report_model.dart';

class AdminReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AdminReportModel> getReport() async {
    final sportsFuture = _firestore.collection('sports').get();
    final competitionsFuture = _firestore.collection('competitions').get();
    final teamsFuture = _firestore.collection('teams').get();
    final usersFuture = _firestore.collection('users').get();
    final matchesFuture = _firestore.collection('matches').get();
    final registrationsFuture = _firestore.collection('registrations').get();

    final results = await Future.wait([
      sportsFuture,
      competitionsFuture,
      teamsFuture,
      usersFuture,
      matchesFuture,
      registrationsFuture,
    ]);

    final sports = results[0].docs;
    final competitions = results[1].docs;
    final teams = results[2].docs;
    final users = results[3].docs;
    final matches = results[4].docs;
    final registrations = results[5].docs;

    return AdminReportModel(
      sportsCount: sports.length,
      activeSportsCount: sports.where((doc) {
        final data = doc.data();
        return data['is_active'] != false;
      }).length,
      competitionsCount: competitions.length,
      activeCompetitionsCount: competitions.where((doc) {
        final data = doc.data();
        return data['status'] == 'active';
      }).length,
      teamsCount: teams.length,
      playersCount: teams.fold<int>(0, (total, doc) {
        final data = doc.data();
        final players = data['players'];
        return total + (players is List ? players.length : 0);
      }),
      studentsCount: users.where((doc) {
        final data = doc.data();
        return data['role'] == 'student';
      }).length,
      adminsCount: users.where((doc) {
        final data = doc.data();
        return data['role'] == 'admin';
      }).length,
      matchesCount: matches.length,
      upcomingMatchesCount: matches.where((doc) {
        final data = doc.data();
        return data['status'] == 'scheduled';
      }).length,
      completedMatchesCount: matches.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).length,
      registrationsCount: registrations.length,
      pendingRegistrationsCount: registrations.where((doc) {
        final data = doc.data();
        return data['status'] == 'pending';
      }).length,
      approvedRegistrationsCount: registrations.where((doc) {
        final data = doc.data();
        return data['status'] == 'approved';
      }).length,
      rejectedRegistrationsCount: registrations.where((doc) {
        final data = doc.data();
        return data['status'] == 'rejected';
      }).length,
      competitionsByType: _countByField(competitions, 'type'),
      registrationsByStatus: _countByField(registrations, 'status'),
      matchesByStatus: _countByField(matches, 'status'),
      teamsByCollege: _countByField(teams, 'college'),
    );
  }

  Map<String, int> _countByField(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
  ) {
    final counts = <String, int>{};

    for (final doc in docs) {
      final value = doc.data()[field]?.toString().trim();
      final key = value == null || value.isEmpty ? 'غير محدد' : value;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return counts;
  }
}
