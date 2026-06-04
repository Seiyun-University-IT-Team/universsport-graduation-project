import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';

enum _TournamentTab { groups, bracket, matches }

class TournamentStructureView extends StatefulWidget {
  final CompetitionModel competition;
  final List<MatchModel> matches;
  final bool showHeader;

  const TournamentStructureView({
    super.key,
    required this.competition,
    required this.matches,
    this.showHeader = true,
  });

  @override
  State<TournamentStructureView> createState() =>
      _TournamentStructureViewState();
}

class _TournamentStructureViewState extends State<TournamentStructureView> {
  late _TournamentTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = _defaultTab;
  }

  @override
  void didUpdateWidget(covariant TournamentStructureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_availableTabs.contains(_selectedTab)) {
      _selectedTab = _defaultTab;
    }
  }

  _TournamentTab get _defaultTab {
    if (widget.competition.tournamentFormat == 'knockout') {
      return _TournamentTab.bracket;
    }
    return _TournamentTab.groups;
  }

  List<_TournamentTab> get _availableTabs {
    switch (widget.competition.tournamentFormat) {
      case 'knockout':
        return const [_TournamentTab.bracket, _TournamentTab.matches];
      case 'mixed':
        return const [
          _TournamentTab.groups,
          _TournamentTab.bracket,
          _TournamentTab.matches,
        ];
      case 'league':
      default:
        return const [_TournamentTab.groups, _TournamentTab.matches];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _availableTabs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          _TournamentHeader(competition: widget.competition),
          const SizedBox(height: 16),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((tab) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _TabPill(
                  icon: _tabIcon(tab),
                  label: _tabLabel(tab),
                  selected: _selectedTab == tab,
                  onTap: () => setState(() => _selectedTab = tab),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildSelectedContent(),
        ),
      ],
    );
  }

  Widget _buildSelectedContent() {
    switch (_selectedTab) {
      case _TournamentTab.groups:
        return _GroupsView(matches: widget.matches);
      case _TournamentTab.bracket:
        return _BracketView(matches: widget.matches);
      case _TournamentTab.matches:
        return _MatchesView(matches: widget.matches);
    }
  }

  IconData _tabIcon(_TournamentTab tab) {
    switch (tab) {
      case _TournamentTab.groups:
        return Icons.groups;
      case _TournamentTab.bracket:
        return Icons.account_tree;
      case _TournamentTab.matches:
        return Icons.calendar_month;
    }
  }

  String _tabLabel(_TournamentTab tab) {
    switch (tab) {
      case _TournamentTab.groups:
        return 'المجموعات';
      case _TournamentTab.bracket:
        return 'خروج المغلوب';
      case _TournamentTab.matches:
        return 'المباريات';
    }
  }
}

class _TournamentHeader extends StatelessWidget {
  final CompetitionModel competition;

  const _TournamentHeader({required this.competition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  competition.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatTournament(competition.tournamentFormat)} • ${_collegeLabel(competition.college)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _collegeLabel(String? college) {
    if (college == null || college.trim().isEmpty) return 'كل الكليات';
    return college;
  }

  String _formatTournament(String format) {
    switch (format) {
      case 'knockout':
        return 'خروج مغلوب';
      case 'mixed':
        return 'مجموعات ثم خروج مغلوب';
      case 'league':
      default:
        return 'مجموعات';
    }
  }
}

class _GroupsView extends StatelessWidget {
  final List<MatchModel> matches;

  const _GroupsView({required this.matches});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MatchModel>>{};
    for (final match in matches.where((match) => match.isGroupPhase)) {
      final key = match.groupName ?? match.stage ?? 'المجموعة';
      groups.putIfAbsent(key, () => []).add(match);
    }

    if (groups.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_outlined,
        message: 'لم يتم إنشاء مجموعات لهذه البطولة بعد.',
      );
    }

    final groupNames = groups.keys.toList()..sort();
    return Column(
      key: const ValueKey('groups'),
      children: groupNames.map((groupName) {
        final groupMatches = groups[groupName]!
          ..sort((a, b) => a.matchTime.compareTo(b.matchTime));
        final standings = _buildStandings(groupMatches);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    const Icon(Icons.groups, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('الفريق')),
                    DataColumn(label: Text('لعب')),
                    DataColumn(label: Text('+/-')),
                    DataColumn(label: Text('فارق')),
                    DataColumn(label: Text('نقاط')),
                  ],
                  rows: standings.map((standing) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              standing.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('${standing.played}')),
                        DataCell(
                          Text('${standing.goalsFor}:${standing.goalsAgainst}'),
                        ),
                        DataCell(Text('${standing.goalDifference}')),
                        DataCell(Text('${standing.points}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: groupMatches
                      .map((match) => _CompactMatchCard(match: match))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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

      teamA.played++;
      teamB.played++;
      teamA.goalsFor += match.scoreA;
      teamA.goalsAgainst += match.scoreB;
      teamB.goalsFor += match.scoreB;
      teamB.goalsAgainst += match.scoreA;

      if (match.scoreA > match.scoreB) {
        teamA.wins++;
        teamB.losses++;
        teamA.points += 3;
      } else if (match.scoreB > match.scoreA) {
        teamB.wins++;
        teamA.losses++;
        teamB.points += 3;
      } else {
        teamA.draws++;
        teamB.draws++;
        teamA.points++;
        teamB.points++;
      }
    }

    final sorted = standings.values.toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        final goalDifference = b.goalDifference.compareTo(a.goalDifference);
        if (goalDifference != 0) return goalDifference;
        return b.goalsFor.compareTo(a.goalsFor);
      });
    return sorted;
  }
}

class _BracketView extends StatelessWidget {
  final List<MatchModel> matches;

  const _BracketView({required this.matches});

  @override
  Widget build(BuildContext context) {
    final knockoutMatches =
        matches.where((match) => match.isKnockoutPhase).toList()..sort((a, b) {
          final round = (a.roundIndex ?? 99).compareTo(b.roundIndex ?? 99);
          if (round != 0) return round;
          return (a.matchIndex ?? 0).compareTo(b.matchIndex ?? 0);
        });

    if (knockoutMatches.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_tree_outlined,
        message: 'لم يتم إنشاء مسار خروج المغلوب بعد.',
      );
    }

    final rounds = <int, List<MatchModel>>{};
    for (final match in knockoutMatches) {
      rounds.putIfAbsent(match.roundIndex ?? 0, () => []).add(match);
    }
    final roundIndexes = rounds.keys.toList()..sort();
    for (final roundMatches in rounds.values) {
      roundMatches.sort((a, b) {
        final storedNumber = (a.matchNumber ?? 0).compareTo(b.matchNumber ?? 0);
        if (a.matchNumber != null &&
            b.matchNumber != null &&
            storedNumber != 0) {
          return storedNumber;
        }
        return (a.matchIndex ?? 0).compareTo(b.matchIndex ?? 0);
      });
    }
    final matchNumbers = _buildMatchNumbers(roundIndexes, rounds);

    return LayoutBuilder(
      key: const ValueKey('bracket'),
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width - 32;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < roundIndexes.length; index++) ...[
                _BracketRoundSection(
                  roundMatches: rounds[roundIndexes[index]]!,
                  matchNumbers: matchNumbers,
                  isFinal: index == roundIndexes.length - 1,
                  availableWidth: availableWidth,
                  sourceNumbers: _sourceNumbersForRound(
                    roundIndexes[index],
                    rounds,
                    matchNumbers,
                  ),
                ),
                if (index != roundIndexes.length - 1) const _RoundConnector(),
              ],
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _buildMatchNumbers(
    List<int> roundIndexes,
    Map<int, List<MatchModel>> rounds,
  ) {
    final numbers = <String, int>{};
    var fallbackNumber = 1;

    for (final roundIndex in roundIndexes) {
      for (final match in rounds[roundIndex]!) {
        numbers[match.id] = match.matchNumber ?? fallbackNumber;
        fallbackNumber++;
      }
    }

    return numbers;
  }

  Map<String, (int, int)> _sourceNumbersForRound(
    int roundIndex,
    Map<int, List<MatchModel>> rounds,
    Map<String, int> matchNumbers,
  ) {
    final previousRound = rounds[roundIndex - 1];
    if (previousRound == null) return const {};

    final result = <String, (int, int)>{};
    final currentRound = rounds[roundIndex] ?? const <MatchModel>[];

    for (final match in currentRound) {
      final matchIndex = match.matchIndex ?? currentRound.indexOf(match);
      final firstSourceIndex = matchIndex * 2;
      final secondSourceIndex = firstSourceIndex + 1;
      if (secondSourceIndex >= previousRound.length) continue;

      final firstSource = previousRound[firstSourceIndex];
      final secondSource = previousRound[secondSourceIndex];
      result[match.id] = (
        matchNumbers[firstSource.id] ?? firstSourceIndex + 1,
        matchNumbers[secondSource.id] ?? secondSourceIndex + 1,
      );
    }

    return result;
  }
}

class _BracketRoundSection extends StatelessWidget {
  final List<MatchModel> roundMatches;
  final Map<String, int> matchNumbers;
  final Map<String, (int, int)> sourceNumbers;
  final bool isFinal;
  final double availableWidth;

  const _BracketRoundSection({
    required this.roundMatches,
    required this.matchNumbers,
    required this.sourceNumbers,
    required this.isFinal,
    required this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    final stage = roundMatches.first.stage ?? 'الدور';
    final cardWidth = _cardWidth(availableWidth, roundMatches.length);

    return Column(
      children: [
        _RoundHeader(
          label: stage,
          isFinal: isFinal,
          matchCount: roundMatches.length,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: roundMatches.map((match) {
            final numbers = sourceNumbers[match.id];
            return SizedBox(
              width: cardWidth,
              child: _BracketMatchCard(
                match: match,
                matchNumber: matchNumbers[match.id] ?? 0,
                isFinal: isFinal,
                sourceMatchANumber: numbers?.$1,
                sourceMatchBNumber: numbers?.$2,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  double _cardWidth(double maxWidth, int matchCount) {
    final width = math.max(0.0, maxWidth - 24);
    if (width <= 440) return width;

    final desiredColumns = matchCount >= 8
        ? 4
        : matchCount >= 4
        ? 3
        : matchCount >= 2
        ? 2
        : 1;
    final maxColumns = math.max(1, ((width + 12) / 232).floor());
    final columns = math.min(math.min(desiredColumns, matchCount), maxColumns);
    final cardWidth = (width - (columns - 1) * 12) / columns;
    return cardWidth.clamp(220.0, 280.0).toDouble();
  }
}

class _MatchesView extends StatelessWidget {
  final List<MatchModel> matches;

  const _MatchesView({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_month,
        message: 'لا توجد مباريات مجدولة بعد.',
      );
    }

    final sorted = List<MatchModel>.from(matches)
      ..sort((a, b) => a.matchTime.compareTo(b.matchTime));
    return Column(
      key: const ValueKey('matches'),
      children: sorted.map((match) => _CompactMatchCard(match: match)).toList(),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  final MatchModel match;
  final int matchNumber;
  final bool isFinal;
  final int? sourceMatchANumber;
  final int? sourceMatchBNumber;

  const _BracketMatchCard({
    required this.match,
    required this.matchNumber,
    required this.isFinal,
    this.sourceMatchANumber,
    this.sourceMatchBNumber,
  });

  @override
  Widget build(BuildContext context) {
    final completed = match.status == 'completed' || match.status == 'bye';
    final teamAWin = completed && match.winnerId == match.teamAId;
    final teamBWin = completed && match.winnerId == match.teamBId;
    final teamAName = _teamDisplayName(
      match.teamAName,
      match.teamAId,
      sourceMatchANumber,
    );
    final teamBName = _teamDisplayName(
      match.teamBName,
      match.teamBId,
      sourceMatchBNumber,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFinal
                  ? Colors.amber.withValues(alpha: 0.72)
                  : AppTheme.primaryColor.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 82),
                child: Row(
                  children: [
                    Icon(
                      isFinal ? Icons.emoji_events : Icons.sports,
                      size: 16,
                      color: isFinal
                          ? Colors.amber[700]
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDateTime(match.matchTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _BracketTeamLine(
                name: teamAName,
                score: completed ? '${match.scoreA}' : null,
                isWinner: teamAWin,
              ),
              const SizedBox(height: 8),
              _BracketTeamLine(
                name: teamBName,
                score: completed ? '${match.scoreB}' : null,
                isWinner: teamBWin,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _StatusBadge(status: match.status),
              ),
            ],
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _MatchNumberBadge(number: matchNumber),
        ),
      ],
    );
  }

  String _teamDisplayName(String name, String teamId, int? sourceMatchNumber) {
    if (teamId.isNotEmpty || sourceMatchNumber == null) return name;
    if (!name.trim().startsWith('الفائز من مباراة')) return name;
    return 'الفائز من مباراة $sourceMatchNumber';
  }
}

class _CompactMatchCard extends StatelessWidget {
  final MatchModel match;

  const _CompactMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final completed = match.status == 'completed' || match.status == 'bye';
    final teamAWin = completed && match.winnerId == match.teamAId;
    final teamBWin = completed && match.winnerId == match.teamBId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.schedule,
                size: 16,
                color: completed ? Colors.green : AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${match.stage ?? ''} • ${_formatDateTime(match.matchTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              _StatusBadge(status: match.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamText(name: match.teamAName, winner: teamAWin),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: completed
                      ? Colors.green.withValues(alpha: 0.09)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  completed ? '${match.scoreA} - ${match.scoreB}' : 'VS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: completed
                        ? Colors.green[800]
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _TeamText(name: match.teamBName, winner: teamBWin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final String label;
  final bool isFinal;
  final int matchCount;

  const _RoundHeader({
    required this.label,
    required this.isFinal,
    required this.matchCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFinal ? Colors.amber[700]! : AppTheme.primaryColor;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFinal ? Icons.workspace_premium : Icons.timeline,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _matchCountLabel(matchCount),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _matchCountLabel(int count) {
    if (count == 1) return 'مباراة واحدة';
    if (count == 2) return 'مباراتان';
    return '$count مباريات';
  }
}

class _RoundConnector extends StatelessWidget {
  const _RoundConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchNumberBadge extends StatelessWidget {
  final int number;

  const _MatchNumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'مباراة $number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BracketTeamLine extends StatelessWidget {
  final String name;
  final String? score;
  final bool isWinner;

  const _BracketTeamLine({
    required this.name,
    required this.score,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
              color: isWinner ? Colors.green[800] : Colors.black87,
            ),
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          Text(
            score!,
            style: TextStyle(
              color: isWinner ? Colors.green[800] : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamText extends StatelessWidget {
  final String name;
  final bool winner;

  const _TeamText({required this.name, required this.winner});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: winner ? Colors.green[800] : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'bye':
        return Colors.blueGrey;
      case 'waiting':
        return Colors.orange;
      case 'scheduled':
      default:
        return AppTheme.primaryColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'انتهت';
      case 'bye':
        return 'تأهل مباشر';
      case 'waiting':
        return 'بانتظار المتأهل';
      case 'scheduled':
      default:
        return 'مجدولة';
    }
  }
}

class _TabPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(message),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _Standing {
  final String id;
  final String name;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  _Standing({required this.id, required this.name});

  int get goalDifference => goalsFor - goalsAgainst;
}

String _formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}/$month/$day - $hour:$minute';
}
