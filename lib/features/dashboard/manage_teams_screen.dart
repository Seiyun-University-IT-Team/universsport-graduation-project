import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/team_identity.dart';
import '../../core/theme.dart';
import '../../models/team_model.dart';
import '../../repositories/team_repository.dart';
import '../colleges/domain/entities/college.dart';
import '../colleges/domain/entities/department.dart';
import '../colleges/presentation/providers/college_dropdown_providers.dart';

import 'package:provider/provider.dart' as legacy_provider;
import '../../providers/auth_provider.dart';

class ManageTeamsScreen extends ConsumerStatefulWidget {
  const ManageTeamsScreen({super.key});

  @override
  ConsumerState<ManageTeamsScreen> createState() => _ManageTeamsScreenState();
}

class _ManageTeamsScreenState extends ConsumerState<ManageTeamsScreen> {
  final TeamRepository _teamRepository = TeamRepository();
  final Set<String> _deletingTeamIds = <String>{};

  Future<void> _deleteTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فريق'),
        content: Text('هل تريد حذف فريق "${team.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || _deletingTeamIds.contains(team.id)) return;

    setState(() => _deletingTeamIds.add(team.id));
    try {
      await _teamRepository.deleteTeam(team.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الفريق')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف الفريق: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingTeamIds.remove(team.id));
      }
    }
  }

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

  TeamModel _collegeTeamFor(College college) {
    return TeamModel(
      id: collegeTeamId(college.name),
      name: college.name,
      college: college.name,
      players: const [],
    );
  }

  List<TeamModel> _departmentLevelTeamsFor(
    College college,
    List<Department> departments,
  ) {
    final maxLevel = college.name.contains('الطب') ? 6 : 4;
    final teams = <TeamModel>[];

    for (final department in departments) {
      for (var level = 1; level <= maxLevel; level++) {
        final academicLevel = level.toString();
        teams.add(
          TeamModel(
            id: departmentLevelTeamId(
              college: college.name,
              department: department.name,
              academicLevel: academicLevel,
            ),
            name: departmentLevelTeamName(
              department: department.name,
              academicLevel: academicLevel,
            ),
            college: college.name,
            players: const [],
          ),
        );
      }
    }

    return teams;
  }

  Widget _buildTeamsList({
    required List<TeamModel> generatedTeams,
    required List<College> colleges,
  }) {
    return StreamBuilder<List<TeamModel>>(
      stream: _teamRepository.getAllTeams(includeDeleted: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dbTeams = snapshot.data ?? [];
        final deletedTeamIds = dbTeams
            .where((team) => team.isDeleted)
            .map((team) => team.id)
            .toSet();
        final dbTeamsMap = {
          for (final team in dbTeams.where((team) => !team.isDeleted))
            team.id: team,
        };
        final visibleTeams = generatedTeams
            .where((team) => !deletedTeamIds.contains(team.id))
            .toList();

        if (visibleTeams.isEmpty) {
          return const Center(child: Text('لا توجد فرق حالياً.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visibleTeams.length,
          itemBuilder: (context, index) {
            var team = visibleTeams[index];
            if (dbTeamsMap.containsKey(team.id)) {
              team = dbTeamsMap[team.id]!;
            }

            final isDeleting = _deletingTeamIds.contains(team.id);
            final collegeName = _collegeDisplayName(team.college, colleges);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.shield, color: Colors.white),
                ),
                title: Text(
                  team.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'الكلية: $collegeName | اللاعبين: ${team.players.length}',
                ),
                trailing: isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'حذف الفريق',
                        onPressed: () => _deleteTeam(team),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                onTap: isDeleting
                    ? null
                    : () {
                        context.push('/team_details', extra: team);
                      },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final collegesAsync = ref.watch(collegesProvider);

    final authProvider = legacy_provider.Provider.of<AuthProvider>(
      context,
      listen: true,
    );
    final user = authProvider.currentUser;
    final isSupervisor = user?.isSupervisor == true;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفِرق')),
      body: collegesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(child: Text('تعذر تحميل الكليات')),
        data: (colleges) {
          if (colleges.isEmpty) {
            return const Center(child: Text('لا توجد كلية متاحة.'));
          }

          if (!isSupervisor) {
            return _buildTeamsList(
              generatedTeams: colleges.map(_collegeTeamFor).toList(),
              colleges: colleges,
            );
          }

          final targetCollegeName = user?.college?.trim();
          final targetCollege = colleges.cast<College?>().firstWhere(
            (college) => college?.name.trim() == targetCollegeName,
            orElse: () => null,
          );

          if (targetCollege == null) {
            return const Center(
              child: Text('لا توجد كلية مرتبطة بهذا الحساب.'),
            );
          }

          return Consumer(
            builder: (context, ref, child) {
              final departmentsAsync = ref.watch(
                departmentsProvider(targetCollege.id),
              );

              return departmentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    const Center(child: Text('تعذر تحميل الأقسام')),
                data: (departments) {
                  final generatedTeams = [
                    _collegeTeamFor(targetCollege),
                    ..._departmentLevelTeamsFor(targetCollege, departments),
                  ];

                  return _buildTeamsList(
                    generatedTeams: generatedTeams,
                    colleges: colleges,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
