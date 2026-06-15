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
      body: FutureBuilder<AdminReportModel>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('التقارير والإحصائيات'),
                elevation: 0,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 54,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تعذر تحميل التقارير والإحصائيات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final report = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildSliverAppBar(context, report),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildKPISection(context, report),
                      const SizedBox(height: 16),
                      _buildRegistrationSection(context, report),
                      const SizedBox(height: 16),
                      _buildMatchesSection(context, report),
                      const SizedBox(height: 16),
                      _buildCompetitionsSection(context, report),
                      const SizedBox(height: 16),
                      _buildCollegesSection(context, report),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, AdminReportModel report) {
    return SliverAppBar(
      expandedHeight: 195.0,
      floating: false,
      pinned: true,
      centerTitle: true,
      stretch: true,
      backgroundColor: AppTheme.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 14),
        title: const Text(
          'التقارير والإحصائيات',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00386B), // Deep Dark Blue
                    Color(0xFF00529B), // University Blue
                    Color(0xFF007AD9), // Lighter Blue
                  ],
                ),
              ),
            ),
            // Pattern or subtle circle shapes
            Positioned(
              right: -40,
              top: -40,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -20,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متابعة شاملة للأنشطة والبطولات الرياضية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quick Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeaderQuickStat(
                          'طالب مسجل',
                          report.studentsCount.toString(),
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        _buildHeaderQuickStat(
                          'لاعب مشارك',
                          report.playersCount.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24), // spacing for pinned title
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'تحديث البيانات',
        ),
      ],
    );
  }

  Widget _buildHeaderQuickStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildKPISection(BuildContext context, AdminReportModel report) {
    final items = [
      _MetricData(
        Icons.sports_soccer,
        'الرياضات',
        report.sportsCount,
        const Color(0xFF007AD9),
      ),
      _MetricData(
        Icons.emoji_events,
        'البطولات',
        report.competitionsCount,
        const Color(0xFFF59E0B),
      ),
      _MetricData(
        Icons.groups,
        'الفرق',
        report.teamsCount,
        const Color(0xFF10B981),
      ),
      _MetricData(
        Icons.people,
        'الطلاب',
        report.studentsCount,
        const Color(0xFF8B5CF6),
      ),
      _MetricData(
        Icons.person_add,
        'اللاعبون',
        report.playersCount,
        const Color(0xFFEC4899),
      ),
      _MetricData(
        Icons.calendar_today,
        'المباريات',
        report.matchesCount,
        const Color(0xFF06B6D4),
      ),
      _MetricData(
        Icons.how_to_reg,
        'طلبات التسجيل',
        report.registrationsCount,
        const Color(0xFFF97316),
      ),
      _MetricData(
        Icons.admin_panel_settings,
        'المدراء',
        report.adminsCount,
        const Color(0xFFEF4444),
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
        childAspectRatio: 2.15, // fixes overflow by ensuring cards are wide and short
      ),
      itemBuilder: (context, index) => _buildKPICard(context, items[index]),
    );
  }

  Widget _buildKPICard(BuildContext context, _MetricData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    color: data.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.value.toString(),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationSection(BuildContext context, AdminReportModel report) {
    final pending = report.pendingRegistrationsCount;
    final approved = report.approvedRegistrationsCount;
    final rejected = report.rejectedRegistrationsCount;
    final total = report.registrationsCount;

    final double approvedPercent = total == 0 ? 0 : (approved / total) * 100;
    final double pendingPercent = total == 0 ? 0 : (pending / total) * 100;
    final double rejectedPercent = total == 0 ? 0 : (rejected / total) * 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.how_to_reg,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'طلبات التسجيل والانضمام',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: AnimatedDonutChart(
                    values: [
                      approved.toDouble(),
                      pending.toDouble(),
                      rejected.toDouble(),
                    ],
                    colors: const [
                      Color(0xFF10B981), // Approved: Emerald Green
                      Color(0xFFF59E0B), // Pending: Amber
                      Color(0xFFEF4444), // Rejected: Red
                    ],
                    centerValue: total.toString(),
                    centerLabel: 'طلب إجمالي',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      'طلبات مقبولة',
                      approved,
                      approvedPercent,
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      'طلبات معلقة',
                      pending,
                      pendingPercent,
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      'طلبات مرفوضة',
                      rejected,
                      rejectedPercent,
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    int count,
    double percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            '$count طلب',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesSection(BuildContext context, AdminReportModel report) {
    final upcoming = report.upcomingMatchesCount;
    final completed = report.completedMatchesCount;
    final total = report.matchesCount;
    final double completionRate = total == 0 ? 0 : (completed / total) * 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_score,
                  color: Color(0xFF06B6D4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'معدل إنجاز المباريات والفعاليات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : completed / total,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF06B6D4),
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${completionRate.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          Text(
                            'مكتملة',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildMatchStatRow(
                      'المباريات المكتملة',
                      completed.toString(),
                      Icons.check_circle_outline,
                      const Color(0xFF10B981),
                    ),
                    const Divider(height: 12),
                    _buildMatchStatRow(
                      'المباريات القادمة',
                      upcoming.toString(),
                      Icons.schedule,
                      const Color(0xFFF59E0B),
                    ),
                    const Divider(height: 12),
                    _buildMatchStatRow(
                      'إجمالي المباريات',
                      total.toString(),
                      Icons.functions,
                      const Color(0xFF00529B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStatRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCompetitionsSection(BuildContext context, AdminReportModel report) {
    final types = report.competitionsByType;
    final total = report.competitionsCount;
    final teamCount = types['team'] ?? 0;
    final individualCount = types['individual'] ?? 0;

    final double teamPercent = total == 0 ? 0 : (teamCount / total) * 100;
    final double individualPercent = total == 0 ? 0 : (individualCount / total) * 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'البطولات حسب نوع المشاركة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'فرق جماعية ($teamCount)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00529B),
                ),
              ),
              Text(
                'مشاركات فردية ($individualCount)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (teamCount > 0)
                    Expanded(
                      flex: teamCount,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00386B), Color(0xFF00529B)],
                          ),
                        ),
                      ),
                    ),
                  if (individualCount > 0)
                    Expanded(
                      flex: individualCount,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                          ),
                        ),
                      ),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${teamPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${individualPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollegesSection(BuildContext context, AdminReportModel report) {
    final collegesMap = report.teamsByCollege;
    final totalTeams = report.teamsCount;

    if (collegesMap.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('لا توجد فرق مسجلة للكليات بعد'),
        ),
      );
    }

    final sortedColleges = collegesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxTeams = sortedColleges.first.value;

    return _CollegesListWidget(
      colleges: sortedColleges,
      totalTeams: totalTeams,
      maxTeams: maxTeams,
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

class AnimatedDonutChart extends StatefulWidget {
  final List<double> values;
  final List<Color> colors;
  final String centerLabel;
  final String centerValue;

  const AnimatedDonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.centerLabel,
    required this.centerValue,
  });

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedValues = widget.values
            .map((val) => val * _animation.value)
            .toList();
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(120, 120),
              painter: DonutChartPainter(
                values: animatedValues,
                colors: widget.colors,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.centerValue,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  widget.centerLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, val) => sum + val);
    final center = size.center(Offset.zero);
    final double radius = size.width / 2 - 8;

    if (total <= 0) {
      final paint = Paint()
        ..color = Colors.grey.shade100
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -3.141592653589793 / 2; // start from top
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweepAngle = (values[i] / total) * 3.141592653589793 * 2;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      final hasMultipleSegments = values.where((v) => v > 0).length > 1;
      final gap = hasMultipleSegments ? 0.08 : 0.0;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap,
        sweepAngle - (gap * 2),
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _CollegesListWidget extends StatefulWidget {
  final List<MapEntry<String, int>> colleges;
  final int totalTeams;
  final int maxTeams;

  const _CollegesListWidget({
    required this.colleges,
    required this.totalTeams,
    required this.maxTeams,
  });

  @override
  State<_CollegesListWidget> createState() => _CollegesListWidgetState();
}

class _CollegesListWidgetState extends State<_CollegesListWidget> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final displayedColleges = _showAll 
        ? widget.colleges 
        : widget.colleges.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'الفرق الرياضية حسب الكلية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...displayedColleges.map((entry) {
            final collegeName = entry.key;
            final count = entry.value;
            final ratio = widget.maxTeams == 0 ? 0.0 : count / widget.maxTeams;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        collegeName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        '$count فريق',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio == 0 ? 0.01 : ratio,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                Color(0xFF007AD9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (widget.colleges.length > 4) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _showAll = !_showAll;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(double.infinity, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showAll ? 'عرض أقل' : 'عرض المزيد من الكليات',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Icon(
                    _showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
