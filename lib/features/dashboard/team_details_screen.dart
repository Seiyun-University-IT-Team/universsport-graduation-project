import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;

import '../../core/theme.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/team_repository.dart';
import '../../repositories/user_repository.dart';
import '../colleges/domain/entities/college.dart';
import '../colleges/presentation/providers/college_dropdown_providers.dart';

class TeamDetailsScreen extends ConsumerStatefulWidget {
  final TeamModel team;

  const TeamDetailsScreen({super.key, required this.team});

  @override
  ConsumerState<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends ConsumerState<TeamDetailsScreen> {
  final TeamRepository _teamRepository = TeamRepository();
  final UserRepository _userRepository = UserRepository();
  String? _selectedStudentId;
  bool _isSaving = false;

  String _collegeDisplayName(String collegeValue, List<College> colleges) {
    final trimmedValue = collegeValue.trim();
    if (trimmedValue.isEmpty) return 'غير محددة';

    for (final college in colleges) {
      if (college.id == trimmedValue || college.name == trimmedValue) {
        return college.name;
      }
    }

    return trimmedValue;
  }

  bool _canManageTeam(TeamModel team) {
    final user = legacy_provider.Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    return user?.isSupervisor == true &&
        user?.college?.trim() == team.college.trim();
  }

  Future<void> _addPlayer(TeamModel team) async {
    final studentId = _selectedStudentId;
    if (studentId == null) return;
    if (!_canManageTeam(team)) return;

    setState(() => _isSaving = true);
    try {
      final existingTeam = await _teamRepository.getTeamById(team.id);
      if (existingTeam == null) {
        await _teamRepository.addTeam(
          TeamModel(
            id: team.id,
            name: team.name,
            college: team.college,
            captainId: team.captainId,
            players: [studentId],
          ),
        );
      } else if (!existingTeam.players.contains(studentId)) {
        await _teamRepository.addPlayer(team.id, studentId);
      }
      if (!mounted) return;
      setState(() => _selectedStudentId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة اللاعب إلى الفريق')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذرت إضافة اللاعب: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removePlayer(TeamModel team, String userId) async {
    if (!_canManageTeam(team)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة لاعب'),
        content: const Text('هل تريد إزالة هذا اللاعب من الفريق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _teamRepository.removePlayer(team.id, userId);
      if (team.captainId == userId) {
        await _teamRepository.setCaptain(team.id, null);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إزالة اللاعب')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذرت إزالة اللاعب: $e')));
    }
  }

  Future<void> _setCaptain(TeamModel team, String userId) async {
    if (!_canManageTeam(team)) return;

    try {
      await _teamRepository.setCaptain(team.id, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعيين قائد الفريق')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تعيين القائد: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final collegesAsync = ref.watch(collegesProvider);
    final colleges =
        collegesAsync.whenOrNull(data: (colleges) => colleges) ??
        const <College>[];
    final currentUser = legacy_provider.Provider.of<AuthProvider>(
      context,
    ).currentUser;

    return StreamBuilder<TeamModel?>(
      stream: _teamRepository.watchTeam(widget.team.id),
      builder: (context, teamSnapshot) {
        final team = teamSnapshot.data ?? widget.team;
        final collegeName = _collegeDisplayName(team.college, colleges);
        final canManagePlayers =
            currentUser?.isSupervisor == true &&
            currentUser?.college?.trim() == team.college.trim();

        return Scaffold(
          appBar: AppBar(title: Text(team.name)),
          body: StreamBuilder<List<UserModel>>(
            stream: _userRepository.getStudents(),
            builder: (context, studentsSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting ||
                  studentsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (studentsSnapshot.hasError) {
                return const Center(child: Text('تعذر تحميل قائمة الطلاب'));
              }

              final students = studentsSnapshot.data ?? [];
              final studentsById = {
                for (final student in students) student.id: student,
              };
              final teamPlayers = team.players
                  .map((id) => studentsById[id])
                  .whereType<UserModel>()
                  .toList();
              final availableStudents = students
                  .where(
                    (student) =>
                        student.college?.trim() == team.college.trim() &&
                        !team.players.contains(student.id),
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TeamSummary(
                    team: team,
                    collegeName: collegeName,
                    captain: studentsById[team.captainId],
                  ),
                  const SizedBox(height: 16),
                  if (canManagePlayers) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إضافة لاعب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  availableStudents.any(
                                    (student) =>
                                        student.id == _selectedStudentId,
                                  )
                                  ? _selectedStudentId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'اختر طالباً',
                                prefixIcon: Icon(Icons.person_add),
                              ),
                              items: availableStudents
                                  .map(
                                    (student) => DropdownMenuItem(
                                      value: student.id,
                                      child: Text(student.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _selectedStudentId = value,
                                      );
                                    },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _selectedStudentId == null || _isSaving
                                    ? null
                                    : () => _addPlayer(team),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: const Text('إضافة إلى الفريق'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'إضافة اللاعبين وتعديلهم متاحة لمشرف الكلية فقط.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'لاعبو الفريق',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (teamPlayers.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا يوجد لاعبون في هذا الفريق بعد'),
                      ),
                    )
                  else
                    ...teamPlayers.map(
                      (player) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              player.name.isEmpty ? '?' : player.name[0],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              if (player.studentId != null) player.studentId!,
                              if (player.college != null) player.college!,
                            ].join(' | '),
                          ),
                          trailing: canManagePlayers
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'captain') {
                                      _setCaptain(team, player.id);
                                    }
                                    if (value == 'remove') {
                                      _removePlayer(team, player.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'captain',
                                      enabled: team.captainId != player.id,
                                      child: const Text('تعيين كقائد'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('إزالة من الفريق'),
                                    ),
                                  ],
                                )
                              : null,
                          selected: team.captainId == player.id,
                          selectedTileColor: AppTheme.primaryColor.withValues(
                            alpha: 0.08,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TeamSummary extends StatelessWidget {
  final TeamModel team;
  final String collegeName;
  final UserModel? captain;

  const _TeamSummary({
    required this.team,
    required this.collegeName,
    required this.captain,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.shield, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(collegeName),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryRow(
              icon: Icons.groups,
              label: 'عدد اللاعبين',
              value: team.players.length.toString(),
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.star,
              label: 'قائد الفريق',
              value: captain?.name ?? 'لم يتم التعيين',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
