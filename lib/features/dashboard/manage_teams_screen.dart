import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/team_model.dart';
import '../../repositories/team_repository.dart';

class ManageTeamsScreen extends StatefulWidget {
  const ManageTeamsScreen({super.key});

  @override
  State<ManageTeamsScreen> createState() => _ManageTeamsScreenState();
}

class _ManageTeamsScreenState extends State<ManageTeamsScreen> {
  final TeamRepository _teamRepository = TeamRepository();

  void _showAddTeamDialog() {
    final nameController = TextEditingController();
    final collegeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة فريق جديد'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الفريق'),
                  validator: (value) => value == null || value.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: collegeController,
                  decoration: const InputDecoration(labelText: 'الكلية التابع لها'),
                  validator: (value) => value == null || value.isEmpty ? 'مطلوب' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newTeam = TeamModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    college: collegeController.text.trim(),
                    players: [],
                  );
                  await _teamRepository.addTeam(newTeam);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفِرق'),
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: _teamRepository.getAllTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات'));
          }

          final teams = snapshot.data ?? [];

          if (teams.isEmpty) {
            return const Center(child: Text('لا توجد فِرق مسجلة حتى الآن.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.shield, color: Colors.white),
                  ),
                  title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الكلية: \${team.college} | اللاعبين: \${team.players.length}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: const Text('هل أنت متأكد من حذف هذا الفريق؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _teamRepository.deleteTeam(team.id);
                      }
                    },
                  ),
                  onTap: () {
                    // Navigate to team details to manage players
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTeamDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
