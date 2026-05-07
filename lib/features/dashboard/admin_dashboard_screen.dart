import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
        actions: [
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
            const Text(
              'نظرة عامة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(context, Icons.sports_soccer, 'الرياضات', '3 رياضات', Colors.blue),
                _buildStatCard(context, Icons.emoji_events, 'البطولات', '2 نشطة', Colors.orange),
                _buildStatCard(context, Icons.group, 'الطلاب', '120 طالب', Colors.green),
                _buildStatCard(context, Icons.calendar_today, 'المباريات', '5 قادمة', Colors.purple),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'إجراءات سريعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActionTile(context, Icons.add_circle, 'إضافة رياضة جديدة', () {
              context.push('/add_sport');
            }),
            _buildActionTile(context, Icons.emoji_events, 'إدارة البطولات', () {
              context.push('/manage_competitions');
            }),
            _buildActionTile(context, Icons.people, 'إدارة الفِرق', () {
              context.push('/manage_teams');
            }),
            _buildActionTile(context, Icons.check_circle, 'طلبات التسجيل', () {
              context.push('/manage_registrations');
            }),
            _buildActionTile(context, Icons.analytics, 'التقارير والإحصائيات', () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
