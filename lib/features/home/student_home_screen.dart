import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/team_identity.dart';
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
  String? _selectedCompetitionFilterId;
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
        _selectedCollegeFilter = _cleanFilterValue(user.college);
        _filtersInitialized = true;
      }
    }
  }

  String? _cleanFilterValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _competitionMatchesCollege(
    CompetitionModel competition,
    String? selectedCollege,
  ) {
    if (selectedCollege == null) return true;
    return _cleanFilterValue(competition.college) == selectedCollege;
  }

  Future<void> _registerForCompetition(CompetitionModel competition) async {
    final user = legacy_provider.Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    if (user == null) return;

    if (competition.college != null &&
        competition.college!.isNotEmpty &&
        competition.college != user.college) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك التسجيل في بطولة تابعة لكلية أخرى.'),
        ),
      );
      return;
    }

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
      extendBody: true,
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'الأبطال',
            icon: const Icon(Icons.workspace_premium),
            onPressed: () => context.push('/winners'),
          ),
          if (user != null) _buildNotificationsAction(user.id),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildWelcomeCard(user?.name ?? 'طالب', user?.college, user?.id),
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

  Widget _buildWelcomeCard(String name, String? college, String? userId) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withValues(alpha: 0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.sports_handball_rounded,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحبًا، $name 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            college == null || college.trim().isEmpty
                                ? 'تابع بطولاتك وطلباتك ومباريات فريقك من هنا.'
                                : 'كلية $college 🎓',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (userId != null) ...[
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),
                  StreamBuilder<List<RegistrationModel>>(
                    stream: _registrationRepo.getRegistrationsByUser(userId),
                    builder: (context, snapshot) {
                      final regs = snapshot.data ?? [];
                      final approvedCount = regs.where((r) => r.status == 'approved').length;
                      final pendingCount = regs.where((r) => r.status == 'pending').length;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.assignment_rounded,
                            label: 'طلباتي الكلية',
                            value: '${regs.length}',
                          ),
                          _buildStatItem(
                            icon: Icons.check_circle_rounded,
                            label: 'المقبولة',
                            value: '$approvedCount',
                          ),
                          _buildStatItem(
                            icon: Icons.hourglass_empty_rounded,
                            label: 'قيد الانتظار',
                            value: '$pendingCount',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
      ],
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
                      user?.college != null &&
                      user!.college!.trim().isNotEmpty &&
                      c.college == user.college,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Colors.blueAccent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _tournamentIcon(competition.tournamentFormat),
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              competition.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              competition.college != null && competition.college!.isNotEmpty
                                  ? 'البطولة الرسمية لكلية ${competition.college}'
                                  : 'بطولة عامة مفتوحة للجميع',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('نظام البطولة', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  Text(
                                    _formatTournament(competition.tournamentFormat),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ البدء', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  Text(
                                    _formatDate(competition.startDate),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                            Icons.account_tree_outlined,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          label: const Text(
                            'عرض المسار',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () => _registerForCompetition(competition),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'تسجيل بالبطولة',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

        final collegeSet = <String>{};
        for (final competition in competitions) {
          final college = _cleanFilterValue(competition.college);
          if (college != null) {
            collegeSet.add(college);
          }
        }
        final colleges = collegeSet.toList()..sort();
        final selectedCollege = colleges.contains(_selectedCollegeFilter)
            ? _selectedCollegeFilter
            : null;

        final collegeCompetitions = competitions
            .where(
              (competition) =>
                  _competitionMatchesCollege(competition, selectedCollege),
            )
            .toList();
        final selectedCompetitionId =
            collegeCompetitions.any(
              (competition) => competition.id == _selectedCompetitionFilterId,
            )
            ? _selectedCompetitionFilterId
            : null;
        final filteredCompetitions = selectedCompetitionId == null
            ? collegeCompetitions
            : collegeCompetitions
                  .where(
                    (competition) => competition.id == selectedCompetitionId,
                  )
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchFilters(
              colleges: colleges,
              competitions: collegeCompetitions,
              selectedCollege: selectedCollege,
              selectedCompetitionId: selectedCompetitionId,
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

  Widget _buildMatchFilters({
    required List<String> colleges,
    required List<CompetitionModel> competitions,
    required String? selectedCollege,
    required String? selectedCompetitionId,
  }) {
    final collegeItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('جميع الكليات')),
      ...colleges.map(
        (college) => DropdownMenuItem<String?>(
          value: college,
          child: Text(college, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    final competitionItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('كل البطولات')),
      ...competitions.map(
        (competition) => DropdownMenuItem<String?>(
          value: competition.id,
          child: Text(
            competition.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final collegeDropdown = _buildFilterDropdown(
          label: 'الكلية',
          hint: 'جميع الكليات',
          icon: Icons.school_outlined,
          value: selectedCollege,
          items: collegeItems,
          onChanged: (value) {
            setState(() {
              _selectedCollegeFilter = value;
              _selectedCompetitionFilterId = null;
            });
          },
        );
        final competitionDropdown = _buildFilterDropdown(
          label: 'البطولة',
          hint: 'كل البطولات',
          icon: Icons.emoji_events_outlined,
          value: selectedCompetitionId,
          items: competitionItems,
          onChanged: (value) {
            setState(() => _selectedCompetitionFilterId = value);
          },
        );

        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              collegeDropdown,
              const SizedBox(height: 12),
              competitionDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: collegeDropdown),
            const SizedBox(width: 12),
            Expanded(child: competitionDropdown),
          ],
        );
      },
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      key: ValueKey<String>('match-filter-$label-${value ?? 'all'}'),
      initialValue: value,
      isExpanded: true,
      hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: items,
      onChanged: onChanged,
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
                      user?.college != null &&
                      user!.college!.trim().isNotEmpty &&
                      competition.college == user.college,
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
            builder: (_) =>
                StudentTournamentBracketScreen(competition: competition),
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
          value: _academicLevelDisplayValue(user.academicLevel),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            legacy_provider.Provider.of<AuthProvider>(
              context,
              listen: false,
            ).logout();
            context.go('/');
          },
          icon: const Icon(Icons.logout, size: 24),
          label: const Text(
            'تسجيل الخروج',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 24),
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

  String? _academicLevelDisplayValue(String? academicLevel) {
    if (academicLevel == null || academicLevel.trim().isEmpty) {
      return null;
    }

    return 'المستوى ${academicLevelName(academicLevel)}';
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
    _StudentNavDestination(Icons.calendar_month_outlined, 'الجدول'),
    _StudentNavDestination(Icons.scoreboard_outlined, 'النتائج'),
    _StudentNavDestination(Icons.app_registration_rounded, 'تسجيل'),
    _StudentNavDestination(Icons.workspace_premium_outlined, 'البطولات'),
    _StudentNavDestination(Icons.person_outline_rounded, 'الملف'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final selected = currentIndex == index;
              final isCenter = index == 2;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
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
    final color = selected ? AppTheme.primaryColor : Colors.grey[400];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            destination.icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? AppTheme.primaryColor : Colors.grey[600],
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        if (selected) ...[
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? [AppTheme.primaryColor, const Color(0xFF00386B)]
              : [Colors.white, const Color(0xFFF0F4F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.transparent : AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(
              alpha: selected ? 0.35 : 0.1,
            ),
            blurRadius: selected ? 12 : 6,
            offset: const Offset(0, 4),
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
            size: 24,
          ),
          const SizedBox(height: 1),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.primaryColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
