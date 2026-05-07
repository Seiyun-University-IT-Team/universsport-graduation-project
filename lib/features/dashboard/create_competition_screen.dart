import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/competition_model.dart';
import '../../models/sport_model.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/sport_repository.dart';

class CreateCompetitionScreen extends StatefulWidget {
  const CreateCompetitionScreen({super.key});

  @override
  State<CreateCompetitionScreen> createState() => _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends State<CreateCompetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final SportRepository _sportRepository = SportRepository();

  bool _isLoading = false;
  String? _selectedSportId;
  String _selectedType = 'team'; // 'team' or 'individual'
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  List<SportModel> _sports = [];

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    // This is a bit simplified, in a real app we might want to handle the stream properly or use a Future based getter
    _sportRepository.getSports().listen((sports) {
      if (mounted) {
        setState(() {
          _sports = sports;
          if (_sports.isNotEmpty && _selectedSportId == null) {
            _selectedSportId = _sports.first.id;
          }
        });
      }
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submitCompetition() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSportId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار رياضة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newCompetition = CompetitionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sportId: _selectedSportId!,
        name: _nameController.text.trim(),
        type: _selectedType,
        status: 'active', // active, completed, upcoming
        startDate: _startDate,
        endDate: _endDate,
      );

      await _competitionRepository.addCompetition(newCompetition);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء البطولة بنجاح!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء بطولة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                  labelText: 'اسم البطولة (مثال: دوري الكليات لكرة القدم)',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
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
                  onChanged: (value) {
                    setState(() {
                      _selectedSportId = value;
                    });
                  },
                ),
              const SizedBox(height: 24),
              const Text(
                'نوع البطولة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'team',
                      label: Text('فِرق'),
                      icon: Icon(Icons.groups),
                    ),
                    ButtonSegment<String>(
                      value: 'individual',
                      label: Text('فردي'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: <String>{_selectedType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                    });
                  },
                ),
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
                        child: Text(
                          "\${_startDate.year}-\${_startDate.month.toString().padLeft(2, '0')}-\${_startDate.day.toString().padLeft(2, '0')}",
                        ),
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
                        child: Text(
                           "\${_endDate.year}-\${_endDate.month.toString().padLeft(2, '0')}-\${_endDate.day.toString().padLeft(2, '0')}",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitCompetition,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('إنشاء البطولة', style: TextStyle(fontSize: 18)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
