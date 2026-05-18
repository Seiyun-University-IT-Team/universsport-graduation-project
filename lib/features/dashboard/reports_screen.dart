import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/admin_report_model.dart';
import '../../repositories/admin_report_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminReportRepository _reportRepository = AdminReportRepository();
  late Future<AdminReportModel> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _reportRepository.getReport();
  }

  Future<void> _refresh() async {
    setState(() {
      _reportFuture = _reportRepository.getReport();
    });
    await _reportFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<AdminReportModel>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text('تعذر تحميل التقارير'),
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

          final report = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OverviewGrid(report: report),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'طلبات التسجيل',
                  icon: Icons.how_to_reg,
                  children: [
                    _ProgressRow(
                      label: 'معلقة',
                      value: report.pendingRegistrationsCount,
                      total: report.registrationsCount,
                      color: Colors.orange,
                    ),
                    _ProgressRow(
                      label: 'مقبولة',
                      value: report.approvedRegistrationsCount,
                      total: report.registrationsCount,
                      color: Colors.green,
                    ),
                    _ProgressRow(
                      label: 'مرفوضة',
                      value: report.rejectedRegistrationsCount,
                      total: report.registrationsCount,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'المباريات',
                  icon: Icons.sports_score,
                  children: [
                    _ProgressRow(
                      label: 'قادمة',
                      value: report.upcomingMatchesCount,
                      total: report.matchesCount,
                      color: Colors.blue,
                    ),
                    _ProgressRow(
                      label: 'مكتملة',
                      value: report.completedMatchesCount,
                      total: report.matchesCount,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BreakdownCard(
                  title: 'البطولات حسب النوع',
                  icon: Icons.emoji_events,
                  items: report.competitionsByType,
                  total: report.competitionsCount,
                  labelBuilder: _competitionTypeLabel,
                ),
                const SizedBox(height: 16),
                _BreakdownCard(
                  title: 'الفرق حسب الكلية',
                  icon: Icons.account_balance,
                  items: report.teamsByCollege,
                  total: report.teamsCount,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _competitionTypeLabel(String value) {
    if (value == 'team') return 'فرق';
    if (value == 'individual') return 'فردي';
    return value;
  }
}

class _OverviewGrid extends StatelessWidget {
  final AdminReportModel report;

  const _OverviewGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        Icons.sports_soccer,
        'الرياضات',
        report.sportsCount,
        Colors.blue,
      ),
      _MetricData(
        Icons.emoji_events,
        'البطولات',
        report.competitionsCount,
        Colors.orange,
      ),
      _MetricData(Icons.groups, 'الفرق', report.teamsCount, Colors.teal),
      _MetricData(Icons.people, 'الطلاب', report.studentsCount, Colors.green),
      _MetricData(
        Icons.person_add,
        'اللاعبون',
        report.playersCount,
        Colors.purple,
      ),
      _MetricData(
        Icons.calendar_today,
        'المباريات',
        report.matchesCount,
        Colors.indigo,
      ),
      _MetricData(
        Icons.how_to_reg,
        'طلبات التسجيل',
        report.registrationsCount,
        Colors.brown,
      ),
      _MetricData(
        Icons.admin_panel_settings,
        'المدراء',
        report.adminsCount,
        Colors.red,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => _MetricCard(data: items[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: data.color, size: 30),
            const SizedBox(height: 8),
            Text(data.label, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              data.value.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> items;
  final int total;
  final String Function(String value)? labelBuilder;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.total,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final sortedItems = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SectionCard(
      title: title,
      icon: icon,
      children: sortedItems.isEmpty
          ? [const Text('لا توجد بيانات بعد')]
          : sortedItems
                .map(
                  (entry) => _ProgressRow(
                    label: labelBuilder?.call(entry.key) ?? entry.key,
                    value: entry.value,
                    total: total,
                    color: AppTheme.primaryColor,
                  ),
                )
                .toList(),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$value من $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _MetricData(this.icon, this.label, this.value, this.color);
}
