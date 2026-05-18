import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';
import '../../repositories/app_notification_repository.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/team_repository.dart';
import '../../services/fixture_generator_service.dart';
import '../competitions/tournament_structure_view.dart';
import '../colleges/domain/entities/college.dart';
import '../colleges/presentation/providers/college_dropdown_providers.dart';
import '../../models/team_model.dart';

class CompetitionDetailsScreen extends ConsumerStatefulWidget {
  final CompetitionModel competition;

  const CompetitionDetailsScreen({super.key, required this.competition});

  @override
  ConsumerState<CompetitionDetailsScreen> createState() =>
      _CompetitionDetailsScreenState();
}

class _CompetitionDetailsScreenState
    extends ConsumerState<CompetitionDetailsScreen> {
  final TeamRepository _teamRepository = TeamRepository();
  final MatchRepository _matchRepository = MatchRepository();
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();
  final FixtureGeneratorService _fixtureService = FixtureGeneratorService();

  bool _isGenerating = false;
  String? _championName;

  @override
  void initState() {
    super.initState();
    _championName = widget.competition.championName;
  }

  // ── Step 1: build candidate teams, show selection dialog ──────────────────
  Future<void> _generateFixtures() async {
    setState(() => _isGenerating = true);

    try {
      final existingMatches = await _matchRepository
          .getMatchesByCompetition(widget.competition.id)
          .first;
      if (existingMatches.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يوجد جدول لهذه البطولة بالفعل.')),
        );
        return;
      }

      final collegeName = widget.competition.college;
      final isAdminCompetition = collegeName == null || collegeName.isEmpty;

      List<TeamModel> candidateTeams;

      if (isAdminCompetition) {
        // Admin: one team per college
        final colleges = await ref.read(collegesProvider.future);
        final existingDbTeams = await _teamRepository.getAllTeams().first;
        final existingDbTeamsMap = {for (var t in existingDbTeams) t.id: t};
        candidateTeams = [];
        for (final college in colleges) {
          final teamId = 'college_${college.name.replaceAll(' ', '_')}';
          if (existingDbTeamsMap.containsKey(teamId)) {
            candidateTeams.add(existingDbTeamsMap[teamId]!);
          } else {
            final newTeam = TeamModel(
              id: teamId,
              name: college.name,
              college: college.name,
              players: const [],
            );
            await _teamRepository.addTeam(newTeam);
            candidateTeams.add(newTeam);
          }
        }
      } else {
        // Supervisor: dept + level teams for their college
        final colleges = await ref.read(collegesProvider.future);
        final college = colleges.cast<College?>().firstWhere(
          (c) => c?.name == collegeName,
          orElse: () => null,
        );
        if (college == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الكلية المرتبطة بهذه البطولة غير موجودة.'),
            ),
          );
          return;
        }

        final departments = await ref.read(
          departmentsProvider(college.id).future,
        );
        if (departments.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد أقسام في هذه الكلية لإنشاء فرق.'),
            ),
          );
          return;
        }

        final existingDbTeams = await _teamRepository.getAllTeams().first;
        final existingDbTeamsMap = {for (var t in existingDbTeams) t.id: t};
        final maxLevel = college.name.contains('الطب') ? 6 : 4;
        candidateTeams = [];

        for (final dept in departments) {
          for (int level = 1; level <= maxLevel; level++) {
            const levelNames = [
              'الأول',
              'الثاني',
              'الثالث',
              'الرابع',
              'الخامس',
              'السادس',
            ];
            final levelName = levelNames[level - 1];
            final teamName = '${dept.name} المستوى $levelName';
            final teamId =
                '${college.name.replaceAll(' ', '_')}_${dept.name.replaceAll(' ', '_')}_${levelName.replaceAll(' ', '_')}';

            if (existingDbTeamsMap.containsKey(teamId)) {
              candidateTeams.add(existingDbTeamsMap[teamId]!);
            } else {
              final newTeam = TeamModel(
                id: teamId,
                name: teamName,
                college: college.name,
                players: const [],
              );
              await _teamRepository.addTeam(newTeam);
              candidateTeams.add(newTeam);
            }
          }
        }
      }

      if (candidateTeams.length < 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نحتاج إلى فريقين على الأقل لإنشاء الجدول.'),
          ),
        );
        return;
      }

      // Step 2: show selection dialog
      if (!mounted) return;
      setState(() => _isGenerating = false);

      final selectedTeams = await _showTeamSelectionDialog(candidateTeams);
      if (selectedTeams == null || selectedTeams.length < 2) {
        if (!mounted) return;
        if (selectedTeams != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب اختيار فريقين على الأقل.')),
          );
        }
        return;
      }

      // Step 3: generate fixtures
      setState(() => _isGenerating = true);
      await _fixtureService.generateFixtures(
        competition: widget.competition,
        teams: selectedTeams,
        startDate: widget.competition.startDate,
      );
      await _sendScheduleAnnouncement(
        title: 'تم إنشاء جدول مباريات جديد',
        body: 'تم إنشاء جدول مباريات ${widget.competition.name}.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء جدول المباريات بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Team selection dialog ─────────────────────────────────────────────────
  Future<List<TeamModel>?> _showTeamSelectionDialog(
    List<TeamModel> teams,
  ) async {
    final selected = <String>{};
    final searchController = TextEditingController();

    return showDialog<List<TeamModel>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? teams
                : teams
                      .where((t) => t.name.toLowerCase().contains(query))
                      .toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.groups, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اختر الفرق المشاركة',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'بحث عن فريق...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تم اختيار ${selected.length} فريق',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setDialogState(
                                () => selected.addAll(teams.map((t) => t.id)),
                              ),
                              child: const Text('تحديد الكل'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setDialogState(() => selected.clear()),
                              child: const Text('إلغاء الكل'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final team = filtered[i];
                          final isSelected = selected.contains(team.id);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            activeColor: AppTheme.primaryColor,
                            title: Text(
                              team.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: team.college.isNotEmpty
                                ? Text(
                                    team.college,
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selected.add(team.id);
                                } else {
                                  selected.remove(team.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: selected.length >= 2
                      ? () {
                          final result = teams
                              .where((t) => selected.contains(t.id))
                              .toList();
                          Navigator.pop(dialogContext, result);
                        }
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text('إنشاء الجدول (${selected.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordResultDialog(MatchModel match) {
    final scoreAController = TextEditingController(
      text: match.scoreA.toString(),
    );
    final scoreBController = TextEditingController(
      text: match.scoreB.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            match.status == 'completed' ? 'تعديل النتيجة' : 'إدخال النتيجة',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${match.teamAName} ضد ${match.teamBName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: scoreAController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'نتيجة ${match.teamAName}',
                        ),
                        validator: _scoreValidator,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: scoreBController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'نتيجة ${match.teamBName}',
                        ),
                        validator: _scoreValidator,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final scoreA = int.parse(scoreAController.text.trim());
                final scoreB = int.parse(scoreBController.text.trim());
                if (match.isKnockoutPhase && scoreA == scoreB) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لا يمكن تسجيل تعادل في خروج المغلوب.'),
                    ),
                  );
                  return;
                }

                String? winnerId;
                if (scoreA > scoreB) winnerId = match.teamAId;
                if (scoreB > scoreA) winnerId = match.teamBId;

                final updatedMatch = _copyMatch(
                  match,
                  status: 'completed',
                  scoreA: scoreA,
                  scoreB: scoreB,
                  winnerId: winnerId,
                );

                await _matchRepository.updateMatch(updatedMatch);
                await _applyResultSideEffects(updatedMatch);

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyResultSideEffects(MatchModel match) async {
    final winnerId = match.winnerId;

    if (match.isKnockoutPhase && winnerId != null) {
      final winnerName = winnerId == match.teamAId
          ? match.teamAName
          : match.teamBName;
      final winner = TeamModel(
        id: winnerId,
        name: winnerName,
        college: widget.competition.college ?? '',
        players: const [],
      );

      await _fixtureService.advanceWinner(match: match, winner: winner);

      if (match.nextMatchId == null) {
        await _competitionRepository.updateChampion(
          competitionId: widget.competition.id,
          championId: winner.id,
          championName: winner.name,
        );
        if (mounted) setState(() => _championName = winner.name);
      }

      return;
    }

    if (widget.competition.tournamentFormat == 'mixed' && match.isGroupPhase) {
      await _fillMixedKnockoutWhenGroupsFinish();
    }
  }

  Future<void> _fillMixedKnockoutWhenGroupsFinish() async {
    final matches = await _matchRepository
        .getMatchesByCompetition(widget.competition.id)
        .first;
    final groupMatches = matches.where((match) => match.isGroupPhase).toList();
    if (groupMatches.isEmpty) return;
    if (groupMatches.any((match) => match.status != 'completed')) return;

    final qualifiers = _buildGroupQualifiers(groupMatches);
    if (qualifiers.length < 2) return;

    await _fixtureService.fillFirstKnockoutRound(
      matches: matches,
      teams: qualifiers,
    );
  }

  Future<void> _showEditScheduleDialog(MatchModel match) async {
    var selectedDate = match.matchTime;
    var selectedTime = TimeOfDay.fromDateTime(match.matchTime);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل موعد المباراة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${match.teamAName} ضد ${match.teamBName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formatDate(selectedDate)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(selectedTime.format(context)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updatedTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    await _matchRepository.updateMatch(
                      _copyMatch(match, matchTime: updatedTime),
                    );
                    await _sendMatchScheduleUpdate(match, updatedTime);

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('حفظ الموعد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChampionDialog(List<MatchModel> matches) async {
    final candidates = _buildChampionCandidates(matches);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فرق في جدول البطولة بعد.')),
      );
      return;
    }

    var selectedId = candidates.first.id;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اعتماد بطل المسابقة'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.workspace_premium),
                ),
                items: candidates.map((candidate) {
                  return DropdownMenuItem(
                    value: candidate.id,
                    child: Text(candidate.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedId = value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final winner = candidates.firstWhere(
                      (item) => item.id == selectedId,
                    );
                    await _competitionRepository.updateChampion(
                      competitionId: widget.competition.id,
                      championId: winner.id,
                      championName: winner.name,
                    );
                    if (!mounted) return;
                    setState(() => _championName = winner.name);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('اعتماد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _scoreValidator(String? value) {
    final score = int.tryParse(value?.trim() ?? '');
    if (score == null) return 'رقم مطلوب';
    if (score < 0) return 'غير صالح';
    return null;
  }

  MatchModel _copyMatch(
    MatchModel match, {
    DateTime? matchTime,
    String? status,
    int? scoreA,
    int? scoreB,
    String? winnerId,
  }) {
    return MatchModel(
      id: match.id,
      competitionId: match.competitionId,
      sportId: match.sportId,
      teamAId: match.teamAId,
      teamBId: match.teamBId,
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      matchTime: matchTime ?? match.matchTime,
      status: status ?? match.status,
      scoreA: scoreA ?? match.scoreA,
      scoreB: scoreB ?? match.scoreB,
      winnerId: winnerId ?? match.winnerId,
      stage: match.stage,
      phase: match.phase,
      groupId: match.groupId,
      groupName: match.groupName,
      roundIndex: match.roundIndex,
      matchIndex: match.matchIndex,
      matchNumber: match.matchNumber,
      nextMatchId: match.nextMatchId,
      nextSlot: match.nextSlot,
    );
  }

  Future<void> _sendScheduleAnnouncement({
    required String title,
    required String body,
  }) async {
    try {
      await _notificationRepository.sendToAllStudents(
        title: title,
        body: body,
        type: 'schedule_changed',
        relatedId: widget.competition.id,
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  Future<void> _sendMatchScheduleUpdate(
    MatchModel match,
    DateTime updatedTime,
  ) async {
    try {
      final teamA = await _teamRepository.getTeamById(match.teamAId);
      final teamB = await _teamRepository.getTeamById(match.teamBId);
      final recipients = {...?teamA?.players, ...?teamB?.players};
      final body =
          '${match.teamAName} ضد ${match.teamBName} في ${widget.competition.name} بتاريخ ${_formatDateTime(updatedTime)}.';

      await _notificationRepository.sendToAllStudents(
        title: 'تم تعديل جدول المباريات',
        body: body,
        type: 'schedule_changed',
        relatedId: match.id,
      );

      await _notificationRepository.sendToUsers(
        recipientIds: recipients,
        title: 'تم تحديث موعد مباراة فريقك',
        body: body,
        type: 'match_scheduled',
        relatedId: match.id,
      );
    } catch (e) {
      debugPrint('Match schedule notification error: $e');
    }
  }

  List<TeamModel> _buildGroupQualifiers(List<MatchModel> groupMatches) {
    final matchesByGroup = <String, List<MatchModel>>{};
    for (final match in groupMatches) {
      final groupKey = match.groupName ?? match.stage ?? 'المجموعة';
      matchesByGroup.putIfAbsent(groupKey, () => []).add(match);
    }

    final qualifiers = <TeamModel>[];
    final groupNames = matchesByGroup.keys.toList()..sort();
    for (final groupName in groupNames) {
      final standings = _buildStandings(matchesByGroup[groupName]!);
      qualifiers.addAll(
        standings
            .take(2)
            .map(
              (standing) => TeamModel(
                id: standing.id,
                name: standing.name,
                college: widget.competition.college ?? '',
                players: const [],
              ),
            ),
      );
    }

    return qualifiers;
  }

  List<_Standing> _buildStandings(List<MatchModel> matches) {
    final standings = <String, _Standing>{};

    void ensureTeam(String id, String name) {
      if (id.isEmpty) return;
      standings.putIfAbsent(id, () => _Standing(id: id, name: name));
    }

    for (final match in matches) {
      ensureTeam(match.teamAId, match.teamAName);
      ensureTeam(match.teamBId, match.teamBName);

      if (match.status != 'completed') continue;

      final teamA = standings[match.teamAId];
      final teamB = standings[match.teamBId];
      if (teamA == null || teamB == null) continue;

      teamA.goalsFor += match.scoreA;
      teamA.goalsAgainst += match.scoreB;
      teamB.goalsFor += match.scoreB;
      teamB.goalsAgainst += match.scoreA;

      if (match.scoreA > match.scoreB) {
        teamA.points += 3;
        teamA.wins += 1;
      } else if (match.scoreB > match.scoreA) {
        teamB.points += 3;
        teamB.wins += 1;
      } else {
        teamA.points += 1;
        teamB.points += 1;
      }
    }

    final sorted = standings.values.toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        final wins = b.wins.compareTo(a.wins);
        if (wins != 0) return wins;
        final goalDifference = b.goalDifference.compareTo(a.goalDifference);
        if (goalDifference != 0) return goalDifference;
        return b.goalsFor.compareTo(a.goalsFor);
      });

    return sorted;
  }

  List<_ChampionCandidate> _buildChampionCandidates(List<MatchModel> matches) {
    final sorted = _buildStandings(matches);

    return sorted.map((standing) {
      return _ChampionCandidate(
        id: standing.id,
        name: standing.name,
        label: '${standing.name} - ${standing.points} نقطة',
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${_formatDate(date)} - $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.competition.name)),
      body: StreamBuilder<List<MatchModel>>(
        stream: _matchRepository.getMatchesByCompetition(widget.competition.id),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TournamentStructureView(
                  competition: widget.competition,
                  matches: matches,
                ),
                const SizedBox(height: 24),
                if (_championName != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber[700],
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                        ),
                      ),
                      title: const Text('بطل البطولة'),
                      subtitle: Text(
                        _championName!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (_isGenerating)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: matches.isEmpty ? _generateFixtures : null,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('إنشاء الهيكل والجدول'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showChampionDialog(matches),
                          icon: const Icon(Icons.workspace_premium),
                          label: const Text('اعتماد البطل'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                const Text(
                  'إدارة المباريات والنتائج',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  const Center(child: Text('تعذر تحميل جدول المباريات.'))
                else if (matches.isEmpty)
                  const Center(child: Text('لم يتم جدولة أي مباريات بعد.'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: matches.length,
                    itemBuilder: (context, index) =>
                        _buildMatchCard(matches[index]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    final isCompleted = match.status == 'completed' || match.status == 'bye';
    final canRecordResult =
        match.status != 'waiting' &&
        match.teamAId.isNotEmpty &&
        match.teamBId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateTime(match.matchTime),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (match.stage != null)
                        Text(
                          match.stage!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل الموعد',
                  onPressed: () => _showEditScheduleDialog(match),
                  icon: const Icon(Icons.edit_calendar),
                ),
                IconButton(
                  tooltip: isCompleted ? 'تعديل النتيجة' : 'إدخال النتيجة',
                  onPressed: canRecordResult
                      ? () => _showRecordResultDialog(match)
                      : null,
                  icon: const Icon(Icons.scoreboard),
                ),
              ],
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
                      color: isCompleted && match.winnerId == match.teamAId
                          ? Colors.green
                          : Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted
                        ? '${match.scoreA} - ${match.scoreB}'
                        : match.status == 'waiting'
                        ? 'انتظار'
                        : 'VS',
                    style: TextStyle(
                      color: isCompleted ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: isCompleted ? 18 : 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.teamBName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted && match.winnerId == match.teamBId
                          ? Colors.green
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Standing {
  final String id;
  final String name;
  int points = 0;
  int wins = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  _Standing({required this.id, required this.name});

  int get goalDifference => goalsFor - goalsAgainst;
}

class _ChampionCandidate {
  final String id;
  final String name;
  final String label;

  _ChampionCandidate({
    required this.id,
    required this.name,
    required this.label,
  });
}
