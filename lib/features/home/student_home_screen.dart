import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';
import '../../models/registration_model.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/registration_repository.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final CompetitionRepository _competitionRepo = CompetitionRepository();
  final MatchRepository _matchRepo = MatchRepository();
  final RegistrationRepository _registrationRepo = RegistrationRepository();

  Future<void> _registerForCompetition(String sportId, String competitionId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      final reg = RegistrationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        sportId: sportId,
        competitionId: competitionId,
        status: 'pending',
        registrationDate: DateTime.now(),
      );
      
      await _registrationRepo.addRegistration(reg);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب التسجيل بنجاح!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التسجيل: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to profile
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً، ${user?.name ?? "طالب"}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            const Text(
              'البطولات الحالية المتاحة للتسجيل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: StreamBuilder<List<CompetitionModel>>(
                stream: _competitionRepo.getActiveCompetitions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comps = snapshot.data ?? [];
                  if (comps.isEmpty) {
                    return const Center(child: Text('لا توجد بطولات نشطة حالياً.'));
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: comps.length,
                    itemBuilder: (context, index) {
                      final comp = comps[index];
                      return _buildCompetitionCard(comp);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'المباريات القادمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<MatchModel>>(
              stream: _matchRepo.getUpcomingMatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final matches = snapshot.data ?? [];
                if (matches.isEmpty) {
                  return const Center(child: Text('لا توجد مباريات قادمة.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    return _buildMatchCard(matches[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitionCard(CompetitionModel comp) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            comp.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _registerForCompetition(comp.sportId, comp.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              minimumSize: const Size(100, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('تسجيل الان'),
          )
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '${match.matchTime.day}/${match.matchTime.month}/${match.matchTime.year} - ${match.matchTime.hour}:00',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(match.teamAName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('VS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Text(match.teamBName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
