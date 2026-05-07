import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../repositories/competition_repository.dart';

class ManageCompetitionsScreen extends StatefulWidget {
  const ManageCompetitionsScreen({super.key});

  @override
  State<ManageCompetitionsScreen> createState() => _ManageCompetitionsScreenState();
}

class _ManageCompetitionsScreenState extends State<ManageCompetitionsScreen> {
  final CompetitionRepository _competitionRepository = CompetitionRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة البطولات'),
      ),
      body: StreamBuilder<List<CompetitionModel>>(
        stream: _competitionRepository.getActiveCompetitions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات'));
          }

          final competitions = snapshot.data ?? [];

          if (competitions.isEmpty) {
            return const Center(child: Text('لا توجد بطولات نشطة حالياً.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: competitions.length,
            itemBuilder: (context, index) {
              final comp = competitions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.emoji_events, color: Colors.white),
                  ),
                  title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('النوع: \${comp.type == "team" ? "فِرق" : "فردي"} | النهاية: \${comp.endDate.year}/\${comp.endDate.month}/\${comp.endDate.day}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    context.push('/competition_details', extra: comp);
                  },
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
}
