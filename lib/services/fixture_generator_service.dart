import 'package:flutter/foundation.dart';
import '../models/team_model.dart';
import '../models/match_model.dart';
import '../models/competition_model.dart';
import '../repositories/match_repository.dart';

class FixtureGeneratorService {
  final MatchRepository _matchRepository = MatchRepository();

  /// Generates a Round Robin tournament schedule automatically
  /// Every team plays every other team exactly once.
  Future<void> generateRoundRobinFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
    int matchesPerDay = 2,
  }) async {
    if (teams.length < 2) {
      throw Exception('يجب أن يكون هناك فريقين على الأقل لإنشاء الجدول');
    }

    final List<TeamModel> scheduledTeams = List.from(teams);
    
    // Add a dummy team for bye if the number of teams is odd
    if (scheduledTeams.length % 2 != 0) {
      scheduledTeams.add(TeamModel(id: 'BYE', name: 'BYE', college: '', players: []));
    }

    int numTeams = scheduledTeams.length;
    int numRounds = numTeams - 1;
    int matchesPerRound = numTeams ~/ 2;

    DateTime currentMatchTime = startDate;
    int dailyMatchCount = 0;

    for (int round = 0; round < numRounds; round++) {
      for (int match = 0; match < matchesPerRound; match++) {
        int homeIndex = (round + match) % (numTeams - 1);
        int awayIndex = (numTeams - 1 - match + round) % (numTeams - 1);

        if (match == 0) {
          awayIndex = numTeams - 1;
        }

        final homeTeam = scheduledTeams[homeIndex];
        final awayTeam = scheduledTeams[awayIndex];

        // Skip if it's a BYE match
        if (homeTeam.id == 'BYE' || awayTeam.id == 'BYE') {
          continue;
        }

        final newMatch = MatchModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          competitionId: competition.id,
          sportId: competition.sportId,
          teamAId: homeTeam.id,
          teamBId: awayTeam.id,
          teamAName: homeTeam.name,
          teamBName: awayTeam.name,
          matchTime: currentMatchTime,
          status: 'scheduled',
        );

        await _matchRepository.addMatch(newMatch);

        dailyMatchCount++;
        
        // Increment time for the next match on the same day
        currentMatchTime = currentMatchTime.add(const Duration(hours: 2));

        if (dailyMatchCount >= matchesPerDay) {
          // Move to next day
          currentMatchTime = DateTime(
            currentMatchTime.year,
            currentMatchTime.month,
            currentMatchTime.day + 1,
            startDate.hour, // Reset to original start hour
            startDate.minute,
          );
          dailyMatchCount = 0;
        }
      }
    }
  }

  /// Generates a single-elimination knockout bracket
  Future<void> generateKnockoutFixtures({
    required CompetitionModel competition,
    required List<TeamModel> teams,
    required DateTime startDate,
  }) async {
    if (teams.length < 2) {
      throw Exception('يجب أن يكون هناك فريقين على الأقل لإنشاء الجدول');
    }

    // Shuffle for random seeding (optional, but good for fairness if no ranking exists)
    final List<TeamModel> shuffledTeams = List.from(teams)..shuffle();
    
    DateTime currentMatchTime = startDate;

    // Just creating the first round (Quarter finals / Semi finals etc based on count)
    // Subsequent rounds usually depend on winners.
    for (int i = 0; i < shuffledTeams.length; i += 2) {
      if (i + 1 < shuffledTeams.length) {
        final homeTeam = shuffledTeams[i];
        final awayTeam = shuffledTeams[i + 1];

        final newMatch = MatchModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          competitionId: competition.id,
          sportId: competition.sportId,
          teamAId: homeTeam.id,
          teamBId: awayTeam.id,
          teamAName: homeTeam.name,
          teamBName: awayTeam.name,
          matchTime: currentMatchTime,
          status: 'scheduled',
        );

        await _matchRepository.addMatch(newMatch);
        currentMatchTime = currentMatchTime.add(const Duration(hours: 2));
      } else {
        // Handle bye for the odd team out
        debugPrint('\${shuffledTeams[i].name} gets a BYE to the next round');
      }
    }
  }
}
