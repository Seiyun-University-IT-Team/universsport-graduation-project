import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _selectedType = 'team';
  String _selectedTournamentFormat = 'league';
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
      firstDate: DateTime.now(),
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
      await _notificationRepository.sendToAllStudents(
        title: 'تم بدء بطولة جديدة',
        body:
            'تم إطلاق ${competition.name}. التسجيل متاح الآن من واجهة الطالب.',
        type: 'tournament_started',
        relatedId: competition.id,
      );
    } catch (e) {
      debugPrint('Tournament notification error: $e');
    }
  }

  String _dateLabel(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء بطولة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تفاصيل البطولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم البطولة',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null,
              ),
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, child) {
                  final authProvider = legacy_provider.Provider.of<AuthProvider>(context, listen: false);
                  final user = authProvider.currentUser;
                  if (user?.isSupervisor == true) {
                    return InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'الكلية التابعة لها البطولة',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      child: Text(user?.college ?? 'غير محدد'),
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
                        decoration: const InputDecoration(
                          labelText: 'الكلية (اختياري)',
                          prefixIcon: Icon(Icons.account_balance),
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
                    loading: () => const CircularProgressIndicator(),
                    error: (error, _) => const Text('تعذر تحميل الكليات'),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'الرياضة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_sports.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedSportId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.sports),
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
              const SizedBox(height: 24),
              const Text(
                'نوع المشاركين',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'team',
                    label: Text('فرق'),
                    icon: Icon(Icons.groups),
                  ),
                  ButtonSegment(
                    value: 'individual',
                    label: Text('فردي'),
                    icon: Icon(Icons.person),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (selection) {
                  setState(() => _selectedType = selection.first);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'نظام البطولة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedTournamentFormat,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_tree),
                ),
                items: const [
                  DropdownMenuItem(value: 'league', child: Text('نظام دوري')),
                  DropdownMenuItem(
                    value: 'knockout',
                    child: Text('خروج مغلوب'),
                  ),
                  DropdownMenuItem(
                    value: 'mixed',
                    child: Text('مختلط - مجموعات ثم خروج مغلوب'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTournamentFormat = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'تاريخ البطولة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ البداية',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_dateLabel(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ النهاية',
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(_dateLabel(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitCompetition,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'إنشاء البطولة',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
