import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  void _openRoute(String route) {
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = context.select<AuthProvider, bool>(
      (auth) => auth.currentUser?.isSupervisor ?? false,
    );
    final actions = <_DashboardAction>[
      if (!isSupervisor)
        _DashboardAction(
          icon: Icons.admin_panel_settings,
          title: 'إضافة مدير',
          description: 'إنشاء حساب مدير أو مشرف',
          color: const Color(0xFF0F6BBD),
          onTap: () => _openRoute('/add_admin'),
        ),
      _DashboardAction(
        icon: Icons.sports_soccer,
        title: 'إضافة رياضة',
        description: 'تعريف رياضة جديدة',
        color: const Color(0xFF00897B),
        onTap: () => _openRoute('/add_sport'),
      ),
      _DashboardAction(
        icon: Icons.emoji_events,
        title: 'إدارة البطولات',
        description: 'إنشاء وتنظيم البطولات',
        color: const Color(0xFFE67E22),
        onTap: () => _openRoute('/manage_competitions'),
      ),
      _DashboardAction(
        icon: Icons.groups,
        title: 'إدارة الفرق',
        description: 'متابعة الفرق والمشاركين',
        color: const Color(0xFF5E35B1),
        onTap: () => _openRoute('/manage_teams'),
      ),
      _DashboardAction(
        icon: Icons.how_to_reg,
        title: 'طلبات التسجيل',
        description: 'مراجعة قبول الطلبات',
        color: const Color(0xFF2E7D32),
        onTap: () => _openRoute('/manage_registrations'),
      ),
      _DashboardAction(
        icon: Icons.campaign,
        title: 'إعلانات الطلاب',
        description: 'إنشاء وحذف الإعلانات',
        color: const Color(0xFFC62828),
        onTap: () => _openRoute('/announcements'),
      ),
      _DashboardAction(
        icon: Icons.insights,
        title: 'التقارير',
        description: 'الإحصائيات وملخص النشاط',
        color: const Color(0xFF455A64),
        onTap: () => _openRoute('/reports'),
      ),
      _DashboardAction(
        icon: Icons.workspace_premium,
        title: 'الفائزون',
        description: 'استعراض أصحاب المراكز',
        color: const Color(0xFFAD7B00),
        onTap: () => _openRoute('/winners'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = switch (constraints.maxWidth) {
              >= 900 => 4,
              >= 620 => 3,
              _ => 2,
            };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (context, index) {
                  return _buildActionCard(actions[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionCard(_DashboardAction action) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: action.color, size: 28),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_left,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
}
