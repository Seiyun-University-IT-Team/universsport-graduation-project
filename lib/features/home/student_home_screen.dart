import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/match_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/app_notification_repository.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/registration_repository.dart';
import 'student_tournament_bracket_screen.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  final CompetitionRepository _competitionRepo = CompetitionRepository();
  final MatchRepository _matchRepo = MatchRepository();
  final RegistrationRepository _registrationRepo = RegistrationRepository();
  final AppNotificationRepository _notificationRepo =
      AppNotificationRepository();
  final Set<String> _submittingCompetitionIds = <String>{};

  int _selectedIndex = 2;
  String? _selectedCollegeFilter;
  bool _filtersInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filtersInitialized) {
      final user = legacy_provider.Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (user != null) {
        _selectedCollegeFilter = user.college;
        _filtersInitialized = true;
      }
    }
  }

  Future<void> _registerForCompetition(CompetitionModel competition) async {
    final user = legacy_provider.Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    if (user == null) return;
    if (_submittingCompetitionIds.contains(competition.id)) return;

    setState(() => _submittingCompetitionIds.add(competition.id));

    try {
      await _registrationRepo.addCompetitionRegistrationOnce(
        userId: user.id,
        sportId: competition.sportId,
        competitionId: competition.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال طلب التسجيل في ${competition.name} بنجاح.'),
        ),
      );
    } on DuplicateRegistrationException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبق وأن سجلت في هذه البطولة.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التسجيل: $e')));
    } finally {
      if (mounted) {
        setState(() => _submittingCompetitionIds.remove(competition.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = legacy_provider.Provider.of<AuthProvider>(context).currentUser;
    final titles = ['الجدول', 'النتائج', 'تسجيل', 'البطولات', 'الملف الشخصي'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'الأبطال',
            icon: const Icon(Icons.workspace_premium),
            onPressed: () => context.push('/winners'),
          ),
          if (user != null) _buildNotificationsAction(user.id),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () {
              legacy_provider.Provider.of<AuthProvider>(
                context,
                listen: false,
              ).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildSelectedPage(user)),
      bottomNavigationBar: _StudentBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildSelectedPage(UserModel? user) {
    switch (_selectedIndex) {
      case 0:
        return _buildMatchesPage(showResult: false);
      case 1:
        return _buildMatchesPage(showResult: true);
      case 3:
        return _buildTournamentsPage(user);
      case 4:
        return _buildProfilePage(user);
      case 2:
      default:
        return _buildRegistrationPage(user);
    }
  }

  Widget _buildRegistrationPage(UserModel? user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWelcomeCard(user?.name ?? 'طالب', user?.college),
        const SizedBox(height: 20),
        _buildAvailableCompetitionsSection(user),
        const SizedBox(height: 24),
        if (user != null)
          _buildMyRegistrationsSection(user.id)
        else
          const _MessageCard(
            icon: Icons.lock_outline,
            message: 'سجل الدخول لعرض طلبات التسجيل الخاصة بك.',
          ),
      ],
    );
  }

  Widget _buildNotificationsAction(String userId) {
    return StreamBuilder<int>(
      stream: _notificationRepo.watchUnreadCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: IconButton(
              tooltip: 'الإشعارات',
              icon: const Icon(Icons.notifications),
              onPressed: () => context.push('/notifications'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(String name, String? college) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: const Icon(
                Icons.person,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحبًا، $name',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    college == null || college.trim().isEmpty
                        ? 'تابع بطولاتك وطلباتك ومباريات فريقك من هنا.'
                        : 'تابع بطولاتك ومبارياتك - $college',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableCompetitionsSection(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.emoji_events, 'البطولات المتاحة للتسجيل'),
        const SizedBox(height: 12),
        StreamBuilder<List<CompetitionModel>>(
          stream: _competitionRepo.getActiveCompetitions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const _MessageCard(
                icon: Icons.error_outline,
                message: 'تعذر تحميل البطولات المتاحة.',
              );
            }

            final allCompetitions = snapshot.data ?? [];
            final competitions = allCompetitions
                .where(
                  (c) =>
                      c.college == null ||
                      c.college!.isEmpty ||
                      c.college == user?.college,
                )
                .toList();

            if (competitions.isEmpty) {
              return const _MessageCard(
                icon: Icons.event_busy,
                message: 'لا توجد بطولات نشطة حاليًا.',
              );
            }

            return Column(
              children: competitions.map(_buildCompetitionCard).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompetitionCard(CompetitionModel competition) {
    final isSubmitting = _submittingCompetitionIds.contains(competition.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, size: 32, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    competition.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _formatTournament(competition.tournamentFormat),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'تبدأ: ${_formatDate(competition.startDate)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentTournamentBracketScreen(
                            competition: competition,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.account_tree,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'عرض المسار',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size.fromHeight(38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => _registerForCompetition(competition),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      minimumSize: const Size.fromHeight(38),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تسجيل'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRegistrationsSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.assignment_turned_in, 'طلباتي'),
        const SizedBox(height: 12),
        StreamBuilder<List<RegistrationModel>>(
          stream: _registrationRepo.getRegistrationsByUser(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const _MessageCard(
                icon: Icons.error_outline,
                message: 'تعذر تحميل طلباتك.',
              );
            }

            final registrations = snapshot.data ?? [];
            if (registrations.isEmpty) {
              return const _MessageCard(
                icon: Icons.assignment_outlined,
                message: 'لم ترسل أي طلب تسجيل بعد.',
              );
            }

            return Column(
              children: registrations
                  .take(4)
                  .map(_buildRegistrationCard)
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(RegistrationModel registration) {
    final color = _registrationStatusColor(registration.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                _registrationStatusIcon(registration.status),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'طلب تسجيل بطولة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(registration.registrationDate),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            _StatusChip(
              label: _registrationStatusLabel(registration.status),
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesPage({required bool showResult}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_buildMatchesContent(showResult: showResult)],
    );
  }

  Widget _buildMatchesContent({required bool showResult}) {
    return StreamBuilder<List<CompetitionModel>>(
      stream: _competitionRepo.getAllCompetitions(),
      builder: (context, snapshot) {
        final competitions = snapshot.data ?? [];

        // Build sorted college list from competitions
        final collegeSet = <String>{};
        for (var c in competitions) {
          if (c.college != null && c.college!.isNotEmpty) {
            collegeSet.add(c.college!);
          }
        }
        final colleges = collegeSet.toList()..sort();

        // Filter competitions by selected college
        final filteredCompetitions = competitions.where((c) {
          if (_selectedCollegeFilter == null) return true; // الكل
          return c.college == _selectedCollegeFilter;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فلترة حسب الكلية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // College filter only
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'الكل',
                    selected: _selectedCollegeFilter == null,
                    onTap: () => setState(() => _selectedCollegeFilter = null),
                  ),
                  ...colleges.map(
                    (college) => _FilterChip(
                      label: college,
                      selected: _selectedCollegeFilter == college,
                      onTap: () =>
                          setState(() => _selectedCollegeFilter = college),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(
              showResult ? Icons.scoreboard : Icons.calendar_month,
              showResult ? 'النتائج' : 'جدول المباريات',
            ),
            const SizedBox(height: 12),
            _buildFilteredMatches(
              showResult
                  ? _matchRepo.getCompletedMatches()
                  : _matchRepo.getUpcomingMatches(),
              filteredCompetitions,
              showResult: showResult,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilteredMatches(
    Stream<List<MatchModel>> stream,
    List<CompetitionModel> availableCompetitions, {
    required bool showResult,
  }) {
    return StreamBuilder<List<MatchModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const _MessageCard(
            icon: Icons.error_outline,
            message: 'تعذر تحميل المباريات.',
          );
        }

        final allMatches = snapshot.data ?? [];
        final filteredMatches = allMatches.where((match) {
          return availableCompetitions.any((c) => c.id == match.competitionId);
        }).toList();

        if (filteredMatches.isEmpty) {
          return _MessageCard(
            icon: showResult
                ? Icons.scoreboard_outlined
                : Icons.event_available,
            message: showResult
                ? 'لا توجد نتائج مطابقة.'
                : 'لا توجد مباريات مطابقة.',
          );
        }

        return Column(
          children: filteredMatches
              .map((match) => _buildMatchCard(match, showResult: showResult))
              .toList(),
        );
      },
    );
  }

  Widget _buildTournamentsPage(UserModel? user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(Icons.account_tree, 'البطولات'),
        const SizedBox(height: 12),
        StreamBuilder<List<CompetitionModel>>(
          stream: _competitionRepo.getAllCompetitions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const _MessageCard(
                icon: Icons.error_outline,
                message: 'تعذر تحميل البطولات.',
              );
            }

            final tournaments = (snapshot.data ?? [])
                .where(
                  (competition) =>
                      competition.college == null ||
                      competition.college!.isEmpty ||
                      competition.college == user?.college,
                )
                .toList();

            if (tournaments.isEmpty) {
              return const _MessageCard(
                icon: Icons.event_busy,
                message: 'لا توجد بطولات متاحة للعرض حاليًا.',
              );
            }

            return Column(
              children: tournaments.map(_buildTournamentOverviewCard).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTournamentOverviewCard(CompetitionModel competition) {
    final college = competition.college == null || competition.college!.isEmpty
        ? 'كل الكليات'
        : competition.college!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentTournamentBracketScreen(
              competition: competition,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _tournamentIcon(competition.tournamentFormat),
                  color: AppTheme.primaryColor,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatTournament(competition.tournamentFormat)} • $college',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(competition.startDate)} - ${_formatDate(competition.endDate)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePage(UserModel? user) {
    if (user == null) {
      return const Center(
        child: _MessageCard(
          icon: Icons.lock_outline,
          message: 'لا توجد بيانات طالب لعرضها. سجل الدخول مرة أخرى.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryColor,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildProfileInfoCard(
          icon: Icons.badge_outlined,
          label: 'الرقم الجامعي',
          value: user.studentId,
        ),
        _buildProfileInfoCard(
          icon: Icons.school_outlined,
          label: 'الكلية',
          value: user.college,
        ),
        _buildProfileInfoCard(
          icon: Icons.account_tree_outlined,
          label: 'القسم',
          value: user.department,
        ),
        _buildProfileInfoCard(
          icon: Icons.timeline_outlined,
          label: 'المستوى الدراسي',
          value: user.academicLevel,
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    final displayValue = value == null || value.trim().isEmpty
        ? 'غير محدد'
        : value;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(label),
        subtitle: Text(
          displayValue,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match, {required bool showResult}) {
    final isCompleted = match.status == 'completed';
    final teamAIsWinner = isCompleted && match.winnerId == match.teamAId;
    final teamBIsWinner = isCompleted && match.winnerId == match.teamBId;
    final stageLabel = match.stage;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  showResult ? Icons.check_circle : Icons.schedule,
                  color: showResult ? Colors.green : AppTheme.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDateTime(match.matchTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (stageLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _stageColor(stageLabel).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _stageColor(stageLabel).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      stageLabel,
                      style: TextStyle(
                        color: _stageColor(stageLabel),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TeamName(
                    name: match.teamAName,
                    isWinner: teamAIsWinner,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: showResult
                        ? Colors.green.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    showResult ? '${match.scoreA} - ${match.scoreB}' : 'VS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: showResult
                          ? Colors.green[800]
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: showResult ? 18 : 14,
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamName(
                    name: match.teamBName,
                    isWinner: teamBIsWinner,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color that suits the stage label (round vs knockout round).
  Color _stageColor(String stage) {
    if (stage == 'النهائي') return Colors.amber[700]!;
    if (stage == 'نصف النهائي') return Colors.orange[700]!;
    if (stage.contains('دور')) return Colors.red[600]!;
    if (stage.contains('الجولة')) return AppTheme.primaryColor;
    if (stage.contains('المجموعة')) return Colors.teal;
    return AppTheme.primaryColor;
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _registrationStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_top;
    }
  }

  String _registrationStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'قيد المراجعة';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} - $hour:$minute';
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

  IconData _tournamentIcon(String format) {
    switch (format) {
      case 'knockout':
        return Icons.account_tree;
      case 'mixed':
        return Icons.shuffle;
      case 'league':
      default:
        return Icons.sports_soccer;
    }
  }
}

class _StudentBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _StudentBottomNavigation({
    required this.currentIndex,
    required this.onTap,
  });

  static const _destinations = [
    _StudentNavDestination(Icons.calendar_month, 'الجدول'),
    _StudentNavDestination(Icons.scoreboard, 'النتائج'),
    _StudentNavDestination(Icons.app_registration, 'تسجيل'),
    _StudentNavDestination(Icons.workspace_premium, 'الأبطال'),
    _StudentNavDestination(Icons.person, 'الملف'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 10,
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final selected = currentIndex == index;
              final isCenter = index == 2;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(isCenter ? 16 : 10),
                  child: Center(
                    child: isCenter
                        ? _CenterNavItem(
                            destination: destination,
                            selected: selected,
                          )
                        : _PlainNavItem(
                            destination: destination,
                            selected: selected,
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PlainNavItem extends StatelessWidget {
  final _StudentNavDestination destination;
  final bool selected;

  const _PlainNavItem({required this.destination, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : Colors.grey[600];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(destination.icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CenterNavItem extends StatelessWidget {
  final _StudentNavDestination destination;
  final bool selected;

  const _CenterNavItem({required this.destination, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: selected ? 72 : 64,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primaryColor),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(
                alpha: selected ? 0.28 : 0.12,
              ),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination.icon,
              color: selected ? Colors.white : AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(height: 1),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentNavDestination {
  final IconData icon;
  final String label;

  const _StudentNavDestination(this.icon, this.label);
}

class _TeamName extends StatelessWidget {
  final String name;
  final bool isWinner;

  const _TeamName({required this.name, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isWinner ? Colors.green[800] : Colors.black,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Chip-style filter button for college filter row.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
