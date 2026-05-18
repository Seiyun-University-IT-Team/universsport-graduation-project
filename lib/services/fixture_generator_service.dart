import 'package:flutter/foundation.dart';

import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../repositories/app_notification_repository.dart';
import '../repositories/match_repository.dart';

class FixtureGeneratorService {
  final MatchRepository _matchRepository = MatchRepository();
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();

  Future<void> generateFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
    int matchesPerDay = 2,
  }) async {
    switch (competition.tournamentFormat) {
      case 'knockout':
        await generateKnockoutFixtures(
          competition: competition,
          teams: teams,
          startDate: startDate,
          matchesPerDay: matchesPerDay,
        );
        break;
      case 'mixed':
        await generateMixedFixtures(
          competition: competition,
          teams: teams,
          startDate: startDate,
          matchesPerDay: matchesPerDay,
        );
        break;
      case 'league':
      default:
        await generateGroupFixtures(
          competition: competition,
          teams: teams,
          startDate: startDate,
          matchesPerDay: matchesPerDay,
        );
    }
  }

  Future<void> generateGroupFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
    int matchesPerDay = 2,
  }) async {
    _validateTeams(teams);
    final groups = _buildGroups(teams);
    final cursor = _ScheduleCursor(
      startDate: startDate,
      matchesPerDay: matchesPerDay,
    );

    await _generateGroupMatches(
      competition: competition,
      groups: groups,
      cursor: cursor,
    );
  }

  Future<void> generateMixedFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
    int matchesPerDay = 2,
  }) async {
    _validateTeams(teams);
    final groups = _buildGroups(teams);
    final cursor = _ScheduleCursor(
      startDate: startDate,
      matchesPerDay: matchesPerDay,
    );

    await _generateGroupMatches(
      competition: competition,
      groups: groups,
      cursor: cursor,
    );

    final qualifierLabels = _mixedQualifierLabels(groups);
    await _generateBracketMatches(
      competition: competition,
      startDate: cursor.current,
      matchesPerDay: matchesPerDay,
      participantLabels: qualifierLabels,
    );
  }

  Future<void> generateKnockoutFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
    int matchesPerDay = 2,
  }) async {
    _validateTeams(teams);
    final shuffledTeams = List<TeamModel>.from(teams)..shuffle();

    await _generateBracketMatches(
      competition: competition,
      startDate: startDate,
      matchesPerDay: matchesPerDay,
      seededTeams: shuffledTeams,
    );
  }

  Future<void> advanceWinner({
    required MatchModel match,
    required TeamModel winner,
  }) async {
    final nextMatchId = match.nextMatchId;
    final nextSlot = match.nextSlot;
    if (nextMatchId == null || nextSlot == null) return;

    final nextMatch = await _matchRepository.getMatchById(nextMatchId);
    if (nextMatch == null) return;

    final updated = _copyMatch(
      nextMatch,
      teamAId: nextSlot == 'A' ? winner.id : nextMatch.teamAId,
      teamAName: nextSlot == 'A' ? winner.name : nextMatch.teamAName,
      teamBId: nextSlot == 'B' ? winner.id : nextMatch.teamBId,
      teamBName: nextSlot == 'B' ? winner.name : nextMatch.teamBName,
      status: _matchStatusAfterSlotUpdate(
        teamAId: nextSlot == 'A' ? winner.id : nextMatch.teamAId,
        teamBId: nextSlot == 'B' ? winner.id : nextMatch.teamBId,
      ),
    );

    await _matchRepository.updateMatch(updated);
  }

  Future<void> fillFirstKnockoutRound({
    required List<MatchModel> matches,
    required List<TeamModel> teams,
  }) async {
    final firstRound =
        matches
            .where((match) => match.isKnockoutPhase && match.roundIndex == 0)
            .toList()
          ..sort((a, b) => (a.matchIndex ?? 0).compareTo(b.matchIndex ?? 0));

    if (firstRound.isEmpty) return;
    final alreadyFilled = firstRound.any(
      (match) => match.teamAId.isNotEmpty || match.teamBId.isNotEmpty,
    );
    if (alreadyFilled) return;

    final slots = _spreadTeams(teams, firstRound.length * 2);
    final byeMatches = <MatchModel>[];

    for (var index = 0; index < firstRound.length; index++) {
      final match = firstRound[index];
      final teamA = slots[index * 2];
      final teamB = slots[index * 2 + 1];
      final status = _initialKnockoutStatus(teamA, teamB);
      final winner = status == 'bye' ? (teamA ?? teamB) : null;

      final updated = _copyMatch(
        match,
        teamAId: teamA?.id ?? '',
        teamAName: teamA?.name ?? 'تأهل مباشر',
        teamBId: teamB?.id ?? '',
        teamBName: teamB?.name ?? 'تأهل مباشر',
        status: status,
        winnerId: winner?.id,
      );

      await _matchRepository.updateMatch(updated);
      if (winner != null) byeMatches.add(updated);
    }

    for (final match in byeMatches) {
      final winner = TeamModel(
        id: match.winnerId!,
        name: match.winnerId == match.teamAId
            ? match.teamAName
            : match.teamBName,
        college: '',
        players: const [],
      );
      await advanceWinner(match: match, winner: winner);
    }
  }

  static String knockoutRoundName(int teamsCount) {
    if (teamsCount >= 64) return 'دور الـ64';
    if (teamsCount >= 32) return 'دور الـ32';
    if (teamsCount >= 16) return 'دور الـ16';
    if (teamsCount >= 8) return 'ربع النهائي';
    if (teamsCount >= 4) return 'نصف النهائي';
    return 'النهائي';
  }

  Future<void> _generateGroupMatches({
    required CompetitionModel competition,
    required List<_GeneratedGroup> groups,
    required _ScheduleCursor cursor,
  }) async {
    for (final group in groups) {
      final matches = _roundRobinPairs(group.teams);

      for (final pair in matches) {
        await _addMatch(
          competition: competition,
          teamA: pair.$1,
          teamB: pair.$2,
          matchTime: cursor.takeSlot(),
          stage: group.name,
          phase: 'group',
          groupId: group.id,
          groupName: group.name,
        );
      }
    }
  }

  Future<void> _generateBracketMatches({
    required CompetitionModel competition,
    required DateTime startDate,
    required int matchesPerDay,
    List<TeamModel>? seededTeams,
    List<String>? participantLabels,
  }) async {
    final participantCount =
        seededTeams?.length ?? participantLabels?.length ?? 0;
    final bracketSize = _nextPowerOfTwo(participantCount.clamp(2, 1024));
    final roundsCount = _roundsCount(bracketSize);
    final cursor = _ScheduleCursor(
      startDate: startDate,
      matchesPerDay: matchesPerDay,
    );
    final matchIds = List.generate(roundsCount, (roundIndex) {
      final matchesInRound = bracketSize ~/ (1 << (roundIndex + 1));
      return List.generate(
        matchesInRound,
        (matchIndex) =>
            '${competition.id}_knockout_r${roundIndex}_m$matchIndex',
      );
    });

    final teamSlots = seededTeams == null
        ? null
        : _spreadTeams(seededTeams, bracketSize);
    final labelSlots = participantLabels == null
        ? null
        : _spreadLabels(participantLabels, bracketSize);
    final byeMatches = <MatchModel>[];

    for (var roundIndex = 0; roundIndex < roundsCount; roundIndex++) {
      final teamsInRound = bracketSize ~/ (1 << roundIndex);
      final matchesInRound = bracketSize ~/ (1 << (roundIndex + 1));
      final stageName = knockoutRoundName(teamsInRound);

      for (var matchIndex = 0; matchIndex < matchesInRound; matchIndex++) {
        final matchNumber = _knockoutMatchNumber(
          bracketSize: bracketSize,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        );
        final nextMatchId = roundIndex == roundsCount - 1
            ? null
            : matchIds[roundIndex + 1][matchIndex ~/ 2];
        final nextSlot = roundIndex == roundsCount - 1
            ? null
            : matchIndex.isEven
            ? 'A'
            : 'B';

        late MatchModel match;

        if (roundIndex == 0) {
          final teamA = teamSlots?[matchIndex * 2];
          final teamB = teamSlots?[matchIndex * 2 + 1];
          final labelA = labelSlots?[matchIndex * 2];
          final labelB = labelSlots?[matchIndex * 2 + 1];
          final status = seededTeams == null
              ? 'waiting'
              : _initialKnockoutStatus(teamA, teamB);
          final winner = status == 'bye' ? (teamA ?? teamB) : null;

          match = await _addMatch(
            id: matchIds[roundIndex][matchIndex],
            competition: competition,
            teamA:
                teamA ??
                TeamModel(
                  id: '',
                  name: labelA ?? 'تأهل مباشر',
                  college: '',
                  players: const [],
                ),
            teamB:
                teamB ??
                TeamModel(
                  id: '',
                  name: labelB ?? 'تأهل مباشر',
                  college: '',
                  players: const [],
                ),
            matchTime: cursor.takeSlot(),
            stage: stageName,
            status: status,
            winnerId: winner?.id,
            phase: 'knockout',
            roundIndex: roundIndex,
            matchIndex: matchIndex,
            matchNumber: matchNumber,
            nextMatchId: nextMatchId,
            nextSlot: nextSlot,
            notifyTeams: status == 'scheduled',
          );
        } else {
          final firstSourceMatchNumber = _knockoutMatchNumber(
            bracketSize: bracketSize,
            roundIndex: roundIndex - 1,
            matchIndex: matchIndex * 2,
          );
          final secondSourceMatchNumber = _knockoutMatchNumber(
            bracketSize: bracketSize,
            roundIndex: roundIndex - 1,
            matchIndex: matchIndex * 2 + 1,
          );
          match = await _addMatch(
            id: matchIds[roundIndex][matchIndex],
            competition: competition,
            teamA: TeamModel(
              id: '',
              name: 'الفائز من مباراة $firstSourceMatchNumber',
              college: '',
              players: const [],
            ),
            teamB: TeamModel(
              id: '',
              name: 'الفائز من مباراة $secondSourceMatchNumber',
              college: '',
              players: const [],
            ),
            matchTime: cursor.takeSlot(),
            stage: stageName,
            status: 'waiting',
            phase: 'knockout',
            roundIndex: roundIndex,
            matchIndex: matchIndex,
            matchNumber: matchNumber,
            nextMatchId: nextMatchId,
            nextSlot: nextSlot,
            notifyTeams: false,
          );
        }

        if (match.status == 'bye' && match.winnerId != null) {
          byeMatches.add(match);
        }
      }
    }

    for (final match in byeMatches) {
      final winner = TeamModel(
        id: match.winnerId!,
        name: match.winnerId == match.teamAId
            ? match.teamAName
            : match.teamBName,
        college: '',
        players: const [],
      );
      await advanceWinner(match: match, winner: winner);
    }
  }

  Future<MatchModel> _addMatch({
    String? id,
    required CompetitionModel competition,
    required TeamModel teamA,
    required TeamModel teamB,
    required DateTime matchTime,
    required String stage,
    String status = 'scheduled',
    String? winnerId,
    String phase = 'group',
    String? groupId,
    String? groupName,
    int? roundIndex,
    int? matchIndex,
    int? matchNumber,
    String? nextMatchId,
    String? nextSlot,
    bool notifyTeams = true,
  }) async {
    final match = MatchModel(
      id:
          id ??
          '${DateTime.now().microsecondsSinceEpoch}_${teamA.id}_${teamB.id}',
      competitionId: competition.id,
      sportId: competition.sportId,
      teamAId: teamA.id,
      teamBId: teamB.id,
      teamAName: teamA.name,
      teamBName: teamB.name,
      matchTime: matchTime,
      status: status,
      winnerId: winnerId,
      stage: stage,
      phase: phase,
      groupId: groupId,
      groupName: groupName,
      roundIndex: roundIndex,
      matchIndex: matchIndex,
      matchNumber: matchNumber,
      nextMatchId: nextMatchId,
      nextSlot: nextSlot,
    );

    await _matchRepository.addMatch(match);

    final recipients = {...teamA.players, ...teamB.players};
    if (notifyTeams && recipients.isNotEmpty) {
      try {
        await _notificationRepository.sendToUsers(
          recipientIds: recipients,
          title: 'تم تحديد موعد مباراة فريقك',
          body:
              '${teamA.name} ضد ${teamB.name} في ${competition.name} بتاريخ ${_formatDateTime(matchTime)}.',
          type: 'match_scheduled',
          relatedId: match.id,
        );
      } catch (e) {
        debugPrint('Match notification error: $e');
      }
    }

    return match;
  }

  List<(TeamModel, TeamModel)> _roundRobinPairs(List<TeamModel> teams) {
    final scheduledTeams = List<TeamModel>.from(teams);
    if (scheduledTeams.length.isOdd) {
      scheduledTeams.add(
        TeamModel(id: 'BYE', name: 'BYE', college: '', players: const []),
      );
    }

    final pairs = <(TeamModel, TeamModel)>[];
    final numTeams = scheduledTeams.length;
    final numRounds = numTeams - 1;
    final matchesPerRound = numTeams ~/ 2;

    for (var round = 0; round < numRounds; round++) {
      for (var match = 0; match < matchesPerRound; match++) {
        var homeIndex = (round + match) % (numTeams - 1);
        var awayIndex = (numTeams - 1 - match + round) % (numTeams - 1);
        if (match == 0) awayIndex = numTeams - 1;

        final homeTeam = scheduledTeams[homeIndex];
        final awayTeam = scheduledTeams[awayIndex];
        if (homeTeam.id != 'BYE' && awayTeam.id != 'BYE') {
          pairs.add((homeTeam, awayTeam));
        }
      }
    }

    return pairs;
  }

  List<_GeneratedGroup> _buildGroups(List<TeamModel> teams) {
    final shuffledTeams = List<TeamModel>.from(teams)..shuffle();
    final groupCount = teams.length <= 5 ? 1 : (teams.length / 4).ceil();
    final groups = List.generate(groupCount, (index) {
      final name = 'المجموعة ${_arabicGroupName(index)}';
      return _GeneratedGroup(id: 'group_${index + 1}', name: name, teams: []);
    });

    for (var i = 0; i < shuffledTeams.length; i++) {
      groups[i % groupCount].teams.add(shuffledTeams[i]);
    }

    return groups.where((group) => group.teams.length >= 2).toList();
  }

  List<String> _mixedQualifierLabels(List<_GeneratedGroup> groups) {
    final labels = <String>[];
    for (final group in groups) {
      labels.add('متصدر ${group.name}');
      if (group.teams.length >= 2) {
        labels.add('وصيف ${group.name}');
      }
    }
    return labels;
  }

  List<TeamModel?> _spreadTeams(List<TeamModel> teams, int slotCount) {
    final slots = List<TeamModel?>.filled(slotCount, null);
    for (var index = 0; index < teams.length; index++) {
      var slot = (index * slotCount / teams.length).floor();
      while (slot < slotCount && slots[slot] != null) {
        slot++;
      }
      if (slot >= slotCount) {
        slot = slots.indexWhere((team) => team == null);
      }
      slots[slot] = teams[index];
    }
    return slots;
  }

  List<String?> _spreadLabels(List<String> labels, int slotCount) {
    final slots = List<String?>.filled(slotCount, null);
    for (var index = 0; index < labels.length; index++) {
      var slot = (index * slotCount / labels.length).floor();
      while (slot < slotCount && slots[slot] != null) {
        slot++;
      }
      if (slot >= slotCount) {
        slot = slots.indexWhere((label) => label == null);
      }
      slots[slot] = labels[index];
    }
    return slots;
  }

  int _nextPowerOfTwo(num value) {
    var result = 1;
    while (result < value) {
      result *= 2;
    }
    return result;
  }

  int _roundsCount(int bracketSize) {
    var rounds = 0;
    var size = bracketSize;
    while (size > 1) {
      rounds++;
      size ~/= 2;
    }
    return rounds;
  }

  int _knockoutMatchNumber({
    required int bracketSize,
    required int roundIndex,
    required int matchIndex,
  }) {
    var number = 1;
    for (var index = 0; index < roundIndex; index++) {
      number += bracketSize ~/ (1 << (index + 1));
    }
    return number + matchIndex;
  }

  String _initialKnockoutStatus(TeamModel? teamA, TeamModel? teamB) {
    final hasA = teamA != null;
    final hasB = teamB != null;
    if (hasA && hasB) return 'scheduled';
    if (hasA || hasB) return 'bye';
    return 'waiting';
  }

  String _matchStatusAfterSlotUpdate({
    required String teamAId,
    required String teamBId,
  }) {
    return teamAId.isNotEmpty && teamBId.isNotEmpty ? 'scheduled' : 'waiting';
  }

  MatchModel _copyMatch(
    MatchModel match, {
    String? teamAId,
    String? teamBId,
    String? teamAName,
    String? teamBName,
    String? status,
    String? winnerId,
  }) {
    return MatchModel(
      id: match.id,
      competitionId: match.competitionId,
      sportId: match.sportId,
      teamAId: teamAId ?? match.teamAId,
      teamBId: teamBId ?? match.teamBId,
      teamAName: teamAName ?? match.teamAName,
      teamBName: teamBName ?? match.teamBName,
      matchTime: match.matchTime,
      status: status ?? match.status,
      scoreA: match.scoreA,
      scoreB: match.scoreB,
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

  void _validateTeams(List<TeamModel> teams) {
    if (teams.length < 2) {
      throw Exception('يجب اختيار فريقين على الأقل لإنشاء جدول البطولة.');
    }
  }

  String _arabicGroupName(int index) {
    const names = ['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح'];
    if (index < names.length) return names[index];
    return '${index + 1}';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/$month/$day - $hour:$minute';
  }
}

class _GeneratedGroup {
  final String id;
  final String name;
  final List<TeamModel> teams;

  _GeneratedGroup({required this.id, required this.name, required this.teams});
}

class _ScheduleCursor {
  final DateTime startDate;
  final int matchesPerDay;
  DateTime current;
  int _dailyMatchCount = 0;

  _ScheduleCursor({required this.startDate, required this.matchesPerDay})
    : current = startDate;

  DateTime takeSlot() {
    final slot = current;
    _dailyMatchCount++;

    if (_dailyMatchCount >= matchesPerDay) {
      current = DateTime(
        current.year,
        current.month,
        current.day + 1,
        startDate.hour,
        startDate.minute,
      );
      _dailyMatchCount = 0;
    } else {
      current = current.add(const Duration(hours: 2));
    }

    return slot;
  }
}
