import 'package:flutter/material.dart';

import '../../models/competition_model.dart';
import '../../repositories/competition_repository.dart';

class WinnersScreen extends StatelessWidget {
  const WinnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final competitionRepository = CompetitionRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('الأبطال')),
      body: StreamBuilder<List<CompetitionModel>>(
        stream: competitionRepository.getChampionCompetitions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل قائمة الأبطال.'));
          }

          final competitions = snapshot.data ?? [];
          if (competitions.isEmpty) {
            return const Center(
              child: Text('لم يتم اعتماد أبطال المسابقات بعد.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: competitions.length,
            itemBuilder: (context, index) {
              final competition = competitions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber[700],
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    competition.championName ?? 'غير محدد',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${competition.name} - ${_formatTournament(competition.tournamentFormat)}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTournament(String format) {
    switch (format) {
      case 'knockout':
        return 'خروج مغلوب';
      case 'mixed':
        return 'مختلط';
      case 'league':
      default:
        return 'دوري';
    }
  }
}
