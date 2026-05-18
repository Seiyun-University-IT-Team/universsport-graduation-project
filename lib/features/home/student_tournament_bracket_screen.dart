import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';
import '../competitions/tournament_structure_view.dart';

class StudentTournamentBracketScreen extends StatelessWidget {
  final CompetitionModel competition;

  const StudentTournamentBracketScreen({super.key, required this.competition});

  @override
  Widget build(BuildContext context) {
    final matchRepo = MatchRepository();

    return Scaffold(
      appBar: AppBar(
        title: Text(competition.name),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: matchRepo.getMatchesByCompetition(competition.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل بيانات البطولة.'));
          }

          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'لم يتم إنشاء جدول البطولة بعد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TournamentStructureView(
              competition: competition,
              matches: matches,
            ),
          );
        },
      ),
    );
  }
}
