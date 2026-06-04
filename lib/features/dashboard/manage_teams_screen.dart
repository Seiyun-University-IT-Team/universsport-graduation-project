import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/team_model.dart';
import '../../repositories/team_repository.dart';
import '../colleges/domain/entities/college.dart';
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

  @override
  Widget build(BuildContext context) {
    final collegesAsync = ref.watch(collegesProvider);
    final colleges =
        collegesAsync.whenOrNull(data: (colleges) => colleges) ??
        const <College>[];

    final authProvider = legacy_provider.Provider.of<AuthProvider>(
      context,
      listen: false,
    );
    final user = authProvider.currentUser;
    final isSupervisor = user?.isSupervisor == true;
    final targetCollegeName = isSupervisor ? user?.college : null;

    final College? targetCollege = colleges.cast<College?>().firstWhere(
      (c) => c?.name == targetCollegeName,
      orElse: () =>
          colleges.isNotEmpty && !isSupervisor ? colleges.first : null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفِرق')),
      body: targetCollege == null
          ? const Center(child: Text('لا توجد كلية متاحة.'))
          : Consumer(
              builder: (context, ref, child) {
                final departmentsAsync = ref.watch(
                  departmentsProvider(targetCollege.id),
                );

                return departmentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      const Center(child: Text('تعذر تحميل الأقسام')),
                  data: (departments) {
                    if (departments.isEmpty) {
                      return const Center(
                        child: Text('لا توجد أقسام في هذه الكلية.'),
                      );
                    }

                    // For each department, generate teams
                    final maxLevel = targetCollege.name.contains('الطب')
                        ? 6
                        : 4;
                    final dynamicTeams = <TeamModel>[];

                    for (final dept in departments) {
                      for (int level = 1; level <= maxLevel; level++) {
                        final levelNames = [
                          'الأول',
                          'الثاني',
                          'الثالث',
                          'الرابع',
                          'الخامس',
                          'السادس',
                        ];
                        final levelName = levelNames[level - 1];
                        final teamName = '${dept.name} المستوى $levelName';
                        final safeCollege = targetCollege.name.replaceAll(
                          ' ',
                          '_',
                        );
                        final safeDept = dept.name.replaceAll(' ', '_');
                        final safeLevel = levelName.replaceAll(' ', '_');
                        final teamId = '${safeCollege}_${safeDept}_$safeLevel';

                        dynamicTeams.add(
                          TeamModel(
                            id: teamId,
                            name: teamName,
                            college: targetCollege.name,
                            players: const [],
                          ),
                        );
                      }
                    }

                    return StreamBuilder<List<TeamModel>>(
                      stream: _teamRepository.getAllTeams(includeDeleted: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final dbTeams = snapshot.data ?? [];
                        final deletedTeamIds = dbTeams
                            .where((team) => team.isDeleted)
                            .map((team) => team.id)
                            .toSet();
                        final dbTeamsMap = {
                          for (final team in dbTeams.where(
                            (team) => !team.isDeleted,
                          ))
                            team.id: team,
                        };
                        final visibleTeams = dynamicTeams
                            .where((team) => !deletedTeamIds.contains(team.id))
                            .toList();

                        if (visibleTeams.isEmpty) {
                          return const Center(
                            child: Text('لا توجد فرق حالياً.'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleTeams.length,
                          itemBuilder: (context, index) {
                            var team = visibleTeams[index];
                            if (dbTeamsMap.containsKey(team.id)) {
                              team = dbTeamsMap[team.id]!;
                            }

                            final isDeleting = _deletingTeamIds.contains(
                              team.id,
                            );
                            final collegeName = _collegeDisplayName(
                              team.college,
                              colleges,
                            );
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Icon(
                                    Icons.shield,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'الكلية: $collegeName | اللاعبين: ${team.players.length}',
                                ),
                                trailing: isDeleting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
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
                                        context.push(
                                          '/team_details',
                                          extra: team,
                                        );
                                      },
                              ),
                            );
                          },
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
