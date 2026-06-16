import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin_report_model.dart';
import '../../repositories/admin_report_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminReportRepository _reportRepository = AdminReportRepository();
  late Future<AdminReportModel> _reportFuture;

  @override
  void initState() {
    super.initState();
    // جلب البيانات الحقيقية والديناميكية عند تشغيل الواجهة
    _reportFuture = _reportRepository.getReport();
  }

  // دالة لتحديث البيانات عند سحب الشاشة أو الضغط على زر التحديث
  Future<void> _refresh() async {
    setState(() {
      _reportFuture = _reportRepository.getReport();
    });
    await _reportFuture;
  }

  void _openRoute(String route) {
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.select<AuthProvider, dynamic>(
          (auth) => auth.currentUser,
    );
    final isSupervisor = currentUser?.isSupervisor ?? false;
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
        title: Text(isSupervisor ? 'لوحة تحكم المشرف' : 'لوحة تحكم المدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: _refresh,
          ),
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
        child: FutureBuilder<AdminReportModel>(
          future: _reportFuture,
          builder: (context, snapshot) {
            // حالة الانتظار وجاري تحميل البيانات الديناميكية
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // في حال حدوث خطأ أثناء جلب الإحصائيات
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        'تعذر تحميل البيانات الحية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // استخراج كائن التقرير الحقيقي القادم من السيرفر
            final report = snapshot.data!;

            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppTheme.primaryColor,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = switch (constraints.maxWidth) {
                    >= 900 => 4,
                    >= 620 => 3,
                    _ => 2,
                  };

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentUser != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, color: Colors.white, size: 36),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مرحباً بك، ${currentUser.name}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isSupervisor 
                                            ? 'مشرف كلية ${currentUser.college ?? "غير محدد"}'
                                            : 'مدير النظام',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // عنوان قسم الإحصائيات
                        Text(
                          'نظرة عامة والإحصائيات الحية',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ويدجت عرض الإحصائيات الديناميكية مباشرة
                        _buildStatisticsSection(crossAxisCount, report),
                        const SizedBox(height: 24),

                        // عنوان قسم الإدارات والأيقونات
                        Text(
                          'العمليات والتحكم الإداري',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // شبكة التحكم والأيقونات الأصلية
                        GridView.builder(
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
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // تمرير كائن الـ report لجعل الخصائص حية وديناميكية بالكامل
  Widget _buildStatisticsSection(int crossAxisCount, AdminReportModel report) {
    final stats = [
      _StatItem(
        title: 'البطولات النشطة',
        value: report.competitionsCount.toString(), // ربط حقيقي
        icon: Icons.emoji_events,
        color: const Color(0xFFE67E22),
      ),
      _StatItem(
        title: 'إجمالي الفرق',
        value: report.teamsCount.toString(), // ربط حقيقي
        icon: Icons.groups,
        color: const Color(0xFF5E35B1),
      ),
      _StatItem(
        title: 'طلبات معلقة',
        value: report.pendingRegistrationsCount.toString(), // ربط حقيقي
        icon: Icons.pending_actions,
        color: const Color(0xFF2E7D32),
      ),
      _StatItem(
        title: 'الألعاب المتاحة',
        value: report.sportsCount.toString(), // ربط حقيقي
        icon: Icons.sports,
        color: const Color(0xFF00897B),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 90,
      ),
      itemBuilder: (context, index) {
        final item = stats[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}