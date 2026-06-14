import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/team_identity.dart';
import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../repositories/app_notification_repository.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/team_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/fixture_generator_service.dart';
import '../competitions/tournament_structure_view.dart';
import '../colleges/domain/entities/college.dart';
import '../colleges/presentation/providers/college_dropdown_providers.dart';

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
  final RegistrationRepository _registrationRepository =
      RegistrationRepository();
  final UserRepository _userRepository = UserRepository();
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();
  final FixtureGeneratorService _fixtureService = FixtureGeneratorService();
  final Map<String, Future<_MatchTeamPlayers>> _matchPlayersFutures =
      <String, Future<_MatchTeamPlayers>>{};
  Future<List<UserModel>>? _approvedCompetitionPlayersFuture;

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
          final teamId = collegeTeamId(college.name);
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
            final teamName = departmentLevelTeamName(
              department: dept.name,
              academicLevel: levelName,
            );
            final teamId = departmentLevelTeamId(
              college: college.name,
              department: dept.name,
              academicLevel: levelName,
            );

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.groups, color: AppTheme.primaryColor, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اختر الفرق المشاركة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        hintText: 'بحث عن فريق...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        fillColor: Colors.grey.withValues(alpha: 0.02),
                      ),
                      onChanged: (v) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تم اختيار ${selected.length} فريق',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setDialogState(
                                () => selected.addAll(teams.map((t) => t.id)),
                              ),
                              child: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setDialogState(() => selected.clear()),
                              child: const Text('إلغاء الكل', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: team.college.isNotEmpty
                                ? Text(
                                    team.college,
                                    style: const TextStyle(fontSize: 10),
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
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('اعتماد الفرق (${selected.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Record Result Dialog ──────────────────────────────────────────────────
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            match.status == 'completed' ? 'تعديل نتيجة المباراة' : 'تسجيل نتيجة المباراة',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Team A info
                    Expanded(
                      child: Text(
                        match.teamAName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('ضد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    // Team B info
                    Expanded(
                      child: Text(
                        match.teamBName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: scoreAController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'أهداف أ',
                          hintText: '0',
                          fillColor: Colors.grey.withValues(alpha: 0.02),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        validator: _scoreValidator,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextFormField(
                        controller: scoreBController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'أهداف ب',
                          hintText: '0',
                          fillColor: Colors.grey.withValues(alpha: 0.02),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حفظ النتيجة'),
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

  // ── Edit Schedule Dialog ──────────────────────────────────────────────────
  Future<void> _showEditScheduleDialog(MatchModel match) async {
    var selectedDate = match.matchTime;
    var selectedTime = TimeOfDay.fromDateTime(match.matchTime);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'تعديل موعد المباراة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    '${match.teamAName} ضد ${match.teamBName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
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
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_formatDate(selectedDate)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(selectedTime.format(context)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حفظ الموعد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Champion Dialog ───────────────────────────────────────────────────────
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'اعتماد بطل البطولة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.workspace_premium),
                      fillColor: Colors.grey.withValues(alpha: 0.02),
                    ),
                    items: candidates.map((candidate) {
                      return DropdownMenuItem(
                        value: candidate.id,
                        child: Text(candidate.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedId = value);
                      }
                    },
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('اعتماد البطل'),
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
    if (score == null) return 'مطلوب';
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

  Future<_MatchTeamPlayers> _matchTeamPlayers(MatchModel match) {
    final cacheKey =
        '${widget.competition.id}_${match.id}_${match.teamAId}_${match.teamBId}';

    return _matchPlayersFutures.putIfAbsent(cacheKey, () async {
      final approvedPlayers = await _approvedCompetitionPlayers();
      final teams = await Future.wait<TeamModel?>([
        match.teamAId.isEmpty
            ? Future<TeamModel?>.value()
            : _teamRepository.getTeamById(match.teamAId),
        match.teamBId.isEmpty
            ? Future<TeamModel?>.value()
            : _teamRepository.getTeamById(match.teamBId),
      ]);

      return _MatchTeamPlayers(
        teamA: _playersForTeam(
          teamId: match.teamAId,
          team: teams[0],
          approvedPlayers: approvedPlayers,
        ),
        teamB: _playersForTeam(
          teamId: match.teamBId,
          team: teams[1],
          approvedPlayers: approvedPlayers,
        ),
      );
    });
  }

  Future<List<UserModel>> _approvedCompetitionPlayers() {
    return _approvedCompetitionPlayersFuture ??= () async {
      final registrations = await _registrationRepository
          .getApprovedRegistrationsByCompetition(widget.competition.id);
      final userIds = registrations
          .map((registration) => registration.userId)
          .where((userId) => userId.trim().isNotEmpty)
          .toSet()
          .toList();
      final users = await Future.wait(
        userIds.map((userId) => _userRepository.getUserById(userId)),
      );
      final players = users.whereType<UserModel>().toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return players;
    }();
  }

  List<UserModel> _playersForTeam({
    required String teamId,
    required TeamModel? team,
    required List<UserModel> approvedPlayers,
  }) {
    if (teamId.isEmpty) return const [];

    final teamPlayerIds = team?.players.toSet() ?? <String>{};
    final players = approvedPlayers.where((user) {
      return teamPlayerIds.contains(user.id) || _userTeamId(user) == teamId;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return players;
  }

  String? _userTeamId(UserModel user) {
    final college = user.college?.trim();
    final department = user.department?.trim();
    final academicLevel = user.academicLevel?.trim();

    if (college == null ||
        college.isEmpty ||
        department == null ||
        department.isEmpty ||
        academicLevel == null ||
        academicLevel.isEmpty) {
      return null;
    }

    return departmentLevelTeamId(
      college: college,
      department: department,
      academicLevel: academicLevel,
    );
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
    final isKnockout = widget.competition.tournamentFormat == 'knockout';
    final formatLabel = isKnockout ? 'خروج المغلوب' : 'نظام مختلط';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل البطولة'),
        elevation: 0,
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: _matchRepository.getMatchesByCompetition(widget.competition.id),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? [];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Competition Header Card
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        Color(0xFF007AD9),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.only(bottom: 28, top: 12, left: 20, right: 20),
                  child: Column(
                    children: [
                      // Badges Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sports, color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  formatLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (widget.competition.college != null && widget.competition.college!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.competition.college!,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.competition.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Timeline Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white.withValues(alpha: 0.8), size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'من: ${_formatDate(widget.competition.startDate)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.event, color: Colors.white.withValues(alpha: 0.8), size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'إلى: ${_formatDate(widget.competition.endDate)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brackets / Tournament Structure View
                      if (matches.isNotEmpty) ...[
                        const Text(
                          'هيكل البطولة والجدول الزمني',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: TournamentStructureView(
                            competition: widget.competition,
                            matches: matches,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Champion Showcase Card (Gold Gradient)
                      if (_championName != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700), // Gold
                                Color(0xFFFFA500), // Orange-Gold
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'بطل المسابقة المعتمد',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _championName!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 44,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Admin Action Buttons
                      if (_isGenerating)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Container(
                                decoration: matches.isEmpty
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          colors: [AppTheme.primaryColor, Color(0xFF007AD9)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      )
                                    : null,
                                child: ElevatedButton.icon(
                                  onPressed: matches.isEmpty ? _generateFixtures : null,
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('إنشاء الهيكل والجدول', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: matches.isEmpty ? Colors.transparent : Colors.grey.shade300,
                                    foregroundColor: matches.isEmpty ? Colors.white : Colors.grey.shade600,
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: OutlinedButton.icon(
                                onPressed: () => _showChampionDialog(matches),
                                icon: const Icon(Icons.workspace_premium, size: 18),
                                label: const Text('اعتماد البطل', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber.shade800,
                                  side: BorderSide(color: Colors.amber.shade700, width: 1.5),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Matches Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'إدارة المباريات والنتائج',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                          ),
                          if (matches.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${matches.length} مباراة',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Matches List
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (snapshot.hasError)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Text('تعذر تحميل جدول المباريات.', style: TextStyle(color: Colors.red)),
                          ),
                        )
                      else if (matches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.event_note, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'لم يتم جدولة أي مباريات بعد.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'استخدم زر "إنشاء الهيكل والجدول" بالأعلى للبدء.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
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
    final isBye = match.status == 'bye';
    final canRecordResult =
        match.status != 'waiting' &&
        match.teamAId.isNotEmpty &&
        match.teamBId.isNotEmpty;

    // Status Styling details
    Color statusColor = Colors.grey;
    String statusText = 'في الانتظار';
    if (isBye) {
      statusColor = Colors.blue;
      statusText = 'باي (تأهل تلقائي)';
    } else if (match.status == 'completed') {
      statusColor = Colors.green;
      statusText = 'مكتملة';
    } else if (match.status == 'scheduled') {
      statusColor = Colors.orange;
      statusText = 'مجدولة';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Card Bar (Status & Tools)
            Row(
              children: [
                // Status Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(match.matchTime),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (match.stage != null) ...[
                  Text(
                    match.stage!,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Actions
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تعديل الموعد',
                        onPressed: () => _showEditScheduleDialog(match),
                        icon: const Icon(Icons.edit_calendar, size: 16, color: AppTheme.primaryColor),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: isCompleted ? 'تعديل النتيجة' : 'إدخال النتيجة',
                        onPressed: canRecordResult
                            ? () => _showRecordResultDialog(match)
                            : null,
                        icon: Icon(
                          Icons.scoreboard,
                          size: 16,
                          color: canRecordResult ? Colors.teal : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // FIFA-style versus display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Team A
                Expanded(
                  child: Text(
                    match.teamAName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isCompleted && match.winnerId == match.teamAId
                          ? Colors.green.shade700
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                
                // Score or VS Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isCompleted
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    isCompleted
                        ? '${match.scoreA} - ${match.scoreB}'
                        : match.status == 'waiting'
                            ? 'انتظار'
                            : 'VS',
                    style: TextStyle(
                      color: isCompleted ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: isCompleted ? 18 : 12,
                    ),
                  ),
                ),
                
                // Team B
                Expanded(
                  child: Text(
                    match.teamBName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isCompleted && match.winnerId == match.teamBId
                          ? Colors.green.shade700
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            
            // Collapsible Team Rosters
            _CollapsiblePlayersPanel(
              match: match,
              matchTeamPlayers: _matchTeamPlayers,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsiblePlayersPanel extends StatefulWidget {
  final MatchModel match;
  final Future<_MatchTeamPlayers> Function(MatchModel) matchTeamPlayers;

  const _CollapsiblePlayersPanel({
    required this.match,
    required this.matchTeamPlayers,
  });

  @override
  State<_CollapsiblePlayersPanel> createState() => _CollapsiblePlayersPanelState();
}

class _CollapsiblePlayersPanelState extends State<_CollapsiblePlayersPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // If it's a bye match or one of the teams is empty, no need to show rosters
    if (widget.match.status == 'bye' ||
        widget.match.teamAId.isEmpty ||
        widget.match.teamBId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 24, thickness: 1),
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _isExpanded ? 'إخفاء التشكيلة' : 'عرض التشكيلة واللاعبين',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          FutureBuilder<_MatchTeamPlayers>(
            future: widget.matchTeamPlayers(widget.match),
            builder: (context, snapshot) {
              final players = snapshot.data;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TeamPlayersPanel(
                      teamName: widget.match.teamAName,
                      hasTeam: widget.match.teamAId.isNotEmpty,
                      players: players?.teamA ?? const [],
                      isLoading: isLoading,
                      hasError: snapshot.hasError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TeamPlayersPanel(
                      teamName: widget.match.teamBName,
                      hasTeam: widget.match.teamBId.isNotEmpty,
                      players: players?.teamB ?? const [],
                      isLoading: isLoading,
                      hasError: snapshot.hasError,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _MatchTeamPlayers {
  final List<UserModel> teamA;
  final List<UserModel> teamB;

  const _MatchTeamPlayers({required this.teamA, required this.teamB});
}

class _TeamPlayersPanel extends StatelessWidget {
  final String teamName;
  final bool hasTeam;
  final List<UserModel> players;
  final bool isLoading;
  final bool hasError;

  const _TeamPlayersPanel({
    required this.teamName,
    required this.hasTeam,
    required this.players,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_3_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasTeam)
            Text(
              'لم يتم تحديد الفريق بعد',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            )
          else if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (hasError)
            Text(
              'تعذر تحميل اللاعبين',
              style: TextStyle(color: colorScheme.error, fontSize: 11),
            )
          else if (players.isEmpty)
            Text(
              'لا يوجد لاعبون مسجلون',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            )
          else
            ...players.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        size: 11,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
