import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/sport_model.dart';
import '../../repositories/sport_repository.dart';

class AddSportScreen extends StatefulWidget {
  const AddSportScreen({super.key});

  @override
  State<AddSportScreen> createState() => _AddSportScreenState();
}

class _AddSportScreenState extends State<AddSportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final SportRepository _sportRepository = SportRepository();

  bool _isLoading = false;
  String _selectedIcon = 'sports_soccer';

  final Map<String, IconData> _availableIcons = {
    'sports_soccer': Icons.sports_soccer,
    'sports_basketball': Icons.sports_basketball,
    'sports_volleyball': Icons.sports_volleyball,
    'sports_tennis': Icons.sports_tennis,
    'pool': Icons.pool,
    'fitness_center': Icons.fitness_center,
  };

  Future<void> _submitSport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newSport = SportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        iconName: _selectedIcon,
        isActive: true,
      );

      await _sportRepository.addSport(newSport);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الرياضة بنجاح!')),
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
        title: const Text('إضافة رياضة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تفاصيل الرياضة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الرياضة (مثال: كرة القدم)',
                  prefixIcon: Icon(Icons.sports),
                ),
                validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف الرياضة',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40.0),
                    child: Icon(Icons.description),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'اختر أيقونة للرياضة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableIcons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        entry.value,
                        size: 32,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitSport,
                      child: const Text('حفظ وإضافة'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
