import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../repositories/competition_repository.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageCompetitionsScreen extends StatefulWidget {
  const ManageCompetitionsScreen({super.key});

  @override
  State<ManageCompetitionsScreen> createState() =>
      _ManageCompetitionsScreenState();
}

class _ManageCompetitionsScreenState extends State<ManageCompetitionsScreen> {
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final Set<String> _deletingCompetitionIds = <String>{};

  Future<void> _deleteCompetition(CompetitionModel competition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف بطولة'),
        content: Text(
          'هل تريد حذف بطولة "${competition.name}" بالكامل؟ سيتم حذف المباريات وطلبات التسجيل المرتبطة بها.',
        ),
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

    if (confirmed != true || _deletingCompetitionIds.contains(competition.id)) {
      return;
    }

    setState(() => _deletingCompetitionIds.add(competition.id));
    try {
      await _competitionRepository.deleteCompetition(competition.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف البطولة بالكامل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف البطولة: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingCompetitionIds.remove(competition.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final isSupervisor = currentUser?.isSupervisor == true;
    final supervisorCollege = currentUser?.college;
    
    final stream = (isSupervisor && supervisorCollege != null)
        ? _competitionRepository.getCompetitionsByCollege(supervisorCollege)
        : _competitionRepository.getAllCompetitions();

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة البطولات')),
      body: StreamBuilder<List<CompetitionModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات'));
          }

          final competitions = snapshot.data ?? [];

          if (competitions.isEmpty) {
            return const Center(child: Text('لا توجد بطولات حاليًا.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: competitions.length,
            itemBuilder: (context, index) {
              final competition = competitions[index];
              final isDeleting = _deletingCompetitionIds.contains(
                competition.id,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: competition.championName == null
                        ? AppTheme.primaryColor
                        : Colors.amber[700],
                    child: const Icon(Icons.emoji_events, color: Colors.white),
                  ),
                  title: Text(
                    competition.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'النظام: ${_formatTournament(competition.tournamentFormat)} | النهاية: ${competition.endDate.year}/${competition.endDate.month}/${competition.endDate.day}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDeleting)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          tooltip: 'حذف البطولة',
                          onPressed: () => _deleteCompetition(competition),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: isDeleting
                      ? null
                      : () => context.push(
                          '/competition_details',
                          extra: competition,
                        ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create_competition'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
}
