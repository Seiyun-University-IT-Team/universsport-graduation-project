import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/competition_model.dart';
import '../../models/sport_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/app_notification_repository.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/sport_repository.dart';
import '../../features/colleges/domain/entities/college.dart';
import '../../features/colleges/presentation/providers/college_dropdown_providers.dart';

class CreateCompetitionScreen extends ConsumerStatefulWidget {
  const CreateCompetitionScreen({super.key});

  @override
  ConsumerState<CreateCompetitionScreen> createState() =>
      _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends ConsumerState<CreateCompetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();
  final SportRepository _sportRepository = SportRepository();

  bool _isLoading = false;
  String? _selectedSportId;
  final String _selectedType = 'team';
  String _selectedTournamentFormat = 'knockout';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  List<SportModel> _sports = [];

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadSports() {
    _sportRepository.getSports().listen((sports) {
      if (!mounted) return;
      setState(() {
        _sports = sports;
        _selectedSportId ??= _sports.isNotEmpty ? _sports.first.id : null;
      });
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 305)),
      lastDate: DateTime(2101),
    );
    if (picked == null || picked == _startDate) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2101),
    );
    if (picked == null || picked == _endDate) return;
    setState(() => _endDate = picked);
  }

  Future<void> _submitCompetition() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSportId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الرياضة')));
      return;
    }

    final authProvider = legacy_provider.Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    String? collegeName;

    if (user?.isSupervisor == true) {
      collegeName = user?.college;
    } else {
      final selectedCollege = ref.read(selectedCollegeProvider);
      collegeName = selectedCollege?.name;
    }

    setState(() => _isLoading = true);

    try {
      final newCompetition = CompetitionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sportId: _selectedSportId!,
        name: _nameController.text.trim(),
        type: _selectedType,
        tournamentFormat: _selectedTournamentFormat,
        status: 'active',
        startDate: _startDate,
        endDate: _endDate,
        college: collegeName,
      );

      await _competitionRepository.addCompetition(newCompetition);
      await _sendTournamentStartedNotification(newCompetition);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء البطولة بنجاح')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTournamentStartedNotification(
    CompetitionModel competition,
  ) async {
    try {
      if (competition.college != null && competition.college!.trim().isNotEmpty) {
        await _notificationRepository.sendToCollegeStudents(
          title: 'تم بدء بطولة جديدة',
          body:
              'تم إطلاق ${competition.name}. التسجيل متاح الآن من واجهة الطالب.',
          type: 'tournament_started',
          college: competition.college!,
          relatedId: competition.id,
        );
      } else {
        await _notificationRepository.sendToAllStudents(
          title: 'تم بدء بطولة جديدة',
          body:
              'تم إطلاق ${competition.name}. التسجيل متاح الآن من واجهة الطالب.',
          type: 'tournament_started',
          relatedId: competition.id,
        );
      }
    } catch (e) {
      debugPrint('Tournament notification error: $e');
    }
  }

  String _dateLabel(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء بطولة جديدة'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Gradient Banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    Color(0xFF007AD9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 32, top: 12, left: 24, right: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'إنشاء بطولة رياضية جديدة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أدخل تفاصيل البطولة واصنع جدول المباريات تلقائياً للطلاب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form Container
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
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
                              const Icon(Icons.edit_note, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'المعلومات الأساسية',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Competition Name Input
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'اسم البطولة (مثال: دوري كرة القدم)',
                              prefixIcon: const Icon(Icons.workspace_premium),
                              fillColor: Colors.grey.withValues(alpha: 0.02),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'اسم البطولة مطلوب'
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // College Picker
                          Consumer(
                            builder: (context, ref, child) {
                              final authProvider = legacy_provider.Provider.of<AuthProvider>(context, listen: false);
                              final user = authProvider.currentUser;
                              if (user?.isSupervisor == true) {
                                return InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'الكلية التابعة لها البطولة',
                                    prefixIcon: const Icon(Icons.account_balance),
                                    fillColor: Colors.grey.withValues(alpha: 0.02),
                                  ),
                                  child: Text(
                                    user?.college ?? 'غير محدد',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              }
                              
                              final collegesAsync = ref.watch(collegesProvider);
                              final selectedCollege = ref.watch(selectedCollegeProvider);

                              return collegesAsync.when(
                                data: (colleges) {
                                  final selectedValue = colleges.contains(selectedCollege) ? selectedCollege : null;
                                  return DropdownButtonFormField<College?>(
                                    key: ValueKey(selectedValue),
                                    initialValue: selectedValue,
                                    decoration: InputDecoration(
                                      labelText: 'الكلية المنظمة (اختياري)',
                                      prefixIcon: const Icon(Icons.account_balance),
                                      fillColor: Colors.grey.withValues(alpha: 0.02),
                                    ),
                                    items: [
                                      const DropdownMenuItem<College?>(
                                        value: null,
                                        child: Text('عام (لجميع الكليات)'),
                                      ),
                                      ...colleges.map((college) => DropdownMenuItem(
                                        value: college,
                                        child: Text(college.name),
                                      )),
                                    ],
                                    onChanged: (college) {
                                      ref.read(selectedCollegeProvider.notifier).select(college);
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (error, _) => const Text('تعذر تحميل الكليات'),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Sport Category Dropdown
                          const Text(
                            'نوع الرياضة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_sports.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSportId,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.sports),
                                fillColor: Colors.grey.withValues(alpha: 0.02),
                              ),
                              items: _sports.map((sport) {
                                return DropdownMenuItem(
                                  value: sport.id,
                                  child: Text(sport.name),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedSportId = value),
                            ),
                          const SizedBox(height: 20),

                          // Tournament Format Dropdown
                          const Text(
                            'نظام البطولة والجدولة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTournamentFormat,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.account_tree),
                              fillColor: Colors.grey.withValues(alpha: 0.02),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'knockout',
                                child: Text('نظام خروج المغلوب (تصفيات مباشرة)'),
                              ),
                              DropdownMenuItem(
                                value: 'mixed',
                                child: Text('نظام مختلط (مجموعات ثم تصفيات)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedTournamentFormat = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Date Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
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
                              const Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'الفترة الزمنية للبطولة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Start Date Card Button
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectStartDate(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                                            SizedBox(width: 4),
                                            Text(
                                              'تاريخ البدء',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _dateLabel(_startDate),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // End Date Card Button
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectEndDate(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.teal.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.event, size: 14, color: Colors.teal),
                                            SizedBox(width: 4),
                                            Text(
                                              'تاريخ الانتهاء',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.teal,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _dateLabel(_endDate),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Create Button
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              Color(0xFF007AD9),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submitCompetition,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 54),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'إنشاء وإطلاق البطولة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
