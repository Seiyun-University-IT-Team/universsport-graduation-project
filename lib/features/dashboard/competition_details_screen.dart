import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/competition_model.dart';

import '../../models/match_model.dart';
import '../../repositories/team_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/fixture_generator_service.dart';

class CompetitionDetailsScreen extends StatefulWidget {
  final CompetitionModel competition;

  const CompetitionDetailsScreen({super.key, required this.competition});

  @override
  State<CompetitionDetailsScreen> createState() => _CompetitionDetailsScreenState();
}

class _CompetitionDetailsScreenState extends State<CompetitionDetailsScreen> {
  final TeamRepository _teamRepository = TeamRepository();
  final MatchRepository _matchRepository = MatchRepository();
  final FixtureGeneratorService _fixtureService = FixtureGeneratorService();

  bool _isGenerating = false;

  Future<void> _generateFixtures() async {
    setState(() => _isGenerating = true);

    try {
      // For demonstration, we fetch all teams. In reality, you'd fetch teams registered for this specific competition.
      final teamsSnapshot = await _teamRepository.getAllTeams().first;
      
      if (teamsSnapshot.length < 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نحتاج إلى فريقين على الأقل لإنشاء الجدول!')),
        );
        setState(() => _isGenerating = false);
        return;
      }

      await _fixtureService.generateRoundRobinFixtures(
        competition: widget.competition,
        teams: teamsSnapshot,
        startDate: widget.competition.startDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء جدول المباريات بنجاح!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showRecordResultDialog(MatchModel match) {
    if (match.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نتيجة هذه المباراة مسجلة مسبقاً!')),
      );
      return;
    }

    final scoreAController = TextEditingController();
    final scoreBController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تسجيل نتيجة المباراة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${match.teamAName} ضد ${match.teamBName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: scoreAController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'نقاط ${match.teamAName}'),
                        validator: (value) => value == null || value.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: scoreBController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'نقاط ${match.teamBName}'),
                        validator: (value) => value == null || value.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final scoreA = int.tryParse(scoreAController.text.trim()) ?? 0;
                  final scoreB = int.tryParse(scoreBController.text.trim()) ?? 0;

                  String? winnerId;
                  if (scoreA > scoreB) winnerId = match.teamAId;
                  if (scoreB > scoreA) winnerId = match.teamBId;

                  final updatedMatch = MatchModel(
                    id: match.id,
                    competitionId: match.competitionId,
                    sportId: match.sportId,
                    teamAId: match.teamAId,
                    teamBId: match.teamBId,
                    teamAName: match.teamAName,
                    teamBName: match.teamBName,
                    matchTime: match.matchTime,
                    status: 'completed',
                    scoreA: scoreA,
                    scoreB: scoreB,
                    winnerId: winnerId,
                  );

                  await _matchRepository.updateMatch(updatedMatch);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('حفظ النتيجة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competition.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 60, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      widget.competition.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('الحالة: ${widget.competition.status == "active" ? "نشطة" : "منتهية"}'),
                    const SizedBox(height: 16),
                    _isGenerating
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _generateFixtures,
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('إنشاء جدول المباريات تلقائياً'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'المباريات المجدولة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<MatchModel>>(
              stream: _matchRepository.getMatchesByCompetition(widget.competition.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final matches = snapshot.data ?? [];
                
                if (matches.isEmpty) {
                  return const Center(child: Text('لم يتم جدولة أي مباريات بعد.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    final isCompleted = match.status == 'completed';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _showRecordResultDialog(match),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                '${match.matchTime.day}/${match.matchTime.month}/${match.matchTime.year} - ${match.matchTime.hour}:00',
                                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: Text(
                                      match.teamAName, 
                                      textAlign: TextAlign.center, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted && match.winnerId == match.teamAId ? Colors.green : Colors.black,
                                      )
                                    )
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? Colors.blue.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isCompleted ? '${match.scoreA} - ${match.scoreB}' : 'VS', 
                                      style: TextStyle(
                                        color: isCompleted ? Colors.blue : Colors.red, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: isCompleted ? 18 : 14,
                                      )
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      match.teamBName, 
                                      textAlign: TextAlign.center, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted && match.winnerId == match.teamBId ? Colors.green : Colors.black,
                                      )
                                    )
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
