import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;

import '../../features/colleges/domain/entities/college.dart';
import '../../features/colleges/domain/entities/department.dart';
import '../../features/colleges/presentation/providers/college_dropdown_providers.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _registrationErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'البريد الإلكتروني مستخدم مسبقاً';
        case 'invalid-email':
          return 'البريد الإلكتروني غير صحيح';
        case 'weak-password':
          return 'كلمة المرور ضعيفة، يجب أن تكون 6 أحرف على الأقل';
        case 'network-request-failed':
          return 'تعذر الاتصال بالشبكة، حاول مرة أخرى';
      }
    }

    return 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = legacy_provider.Provider.of<AuthProvider>(context);
    final selectedCollege = ref.watch(selectedCollegeProvider);
    final selectedDepartment = ref.watch(selectedDepartmentProvider);
    final selectedAcademicLevel = ref.watch(selectedAcademicLevelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل طالب جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم الرباعي'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'مطلوب';
                  }
                  if (!email.contains('@')) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(labelText: 'الرقم الجامعي'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              _CollegeDropdown(selectedCollege: selectedCollege),
              const SizedBox(height: 16),
              _DepartmentDropdown(
                selectedCollege: selectedCollege,
                selectedDepartment: selectedDepartment,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final maxLevel =
                      selectedCollege?.name.contains('الطب') == true ? 6 : 4;
                  final levelNames = [
                    'الأول',
                    'الثاني',
                    'الثالث',
                    'الرابع',
                    'الخامس',
                    'السادس',
                  ];

                  return DropdownButtonFormField<int>(
                    initialValue:
                        (selectedAcademicLevel != null &&
                            selectedAcademicLevel <= maxLevel)
                        ? selectedAcademicLevel
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'المستوى الدراسي',
                    ),
                    items: List.generate(maxLevel, (index) {
                      final level = index + 1;
                      return DropdownMenuItem<int>(
                        value: level,
                        child: Text('المستوى ${levelNames[index]}'),
                      );
                    }),
                    onChanged: (level) {
                      ref
                          .read(selectedAcademicLevelProvider.notifier)
                          .select(level);
                    },
                    validator: (value) =>
                        value == null ? 'المستوى الدراسي مطلوب' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) {
                    return 'مطلوب';
                  }
                  if (password.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        final isValid = _formKey.currentState!.validate();
                        final college = ref.read(selectedCollegeProvider);
                        final department = ref.read(selectedDepartmentProvider);
                        final academicLevel = ref.read(
                          selectedAcademicLevelProvider,
                        );

                        if (!isValid ||
                            college == null ||
                            department == null ||
                            academicLevel == null) {
                          return;
                        }

                        try {
                          await authProvider.registerStudent(
                            email: _emailController.text.trim(),
                            name: _nameController.text.trim(),
                            studentId: _studentIdController.text.trim(),
                            college: college.name,
                            department: department.name,
                            academicLevel: academicLevel.toString(),
                            password: _passwordController.text,
                          );
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم إنشاء الحساب بنجاح. الرجاء التحقق من بريدك الإلكتروني لتأكيد الحساب قبل تسجيل الدخول.',
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );

                          // Return to login screen since they need to verify email
                          context.pop();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_registrationErrorMessage(e)),
                            ),
                          );
                        }
                      },
                      child: const Text('تسجيل وإنشاء الحساب'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollegeDropdown extends ConsumerWidget {
  final College? selectedCollege;

  const _CollegeDropdown({required this.selectedCollege});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegesAsync = ref.watch(collegesProvider);

    return collegesAsync.when(
      data: (colleges) {
        final selectedValue = colleges.contains(selectedCollege)
            ? selectedCollege
            : null;

        return DropdownButtonFormField<College>(
          initialValue: selectedValue,
          decoration: const InputDecoration(labelText: 'الكلية'),
          items: colleges
              .map(
                (college) => DropdownMenuItem<College>(
                  value: college,
                  child: Text(college.name),
                ),
              )
              .toList(),
          onChanged: colleges.isEmpty
              ? null
              : (college) {
                  ref.read(selectedCollegeProvider.notifier).select(college);
                  ref.read(selectedDepartmentProvider.notifier).select(null);
                  ref.read(selectedAcademicLevelProvider.notifier).select(null);
                },
          validator: (value) {
            if (colleges.isEmpty) {
              return 'لا توجد كليات متاحة';
            }
            return value == null ? 'الكلية مطلوبة' : null;
          },
        );
      },
      loading: () => const _LoadingDropdown(label: 'الكلية'),
      error: (error, stackTrace) => _DropdownError(
        label: 'الكلية',
        message: 'تعذر تحميل الكليات',
        onRetry: () => ref.invalidate(collegesProvider),
      ),
    );
  }
}

class _DepartmentDropdown extends ConsumerWidget {
  final College? selectedCollege;
  final Department? selectedDepartment;

  const _DepartmentDropdown({
    required this.selectedCollege,
    required this.selectedDepartment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final college = selectedCollege;

    if (college == null) {
      return DropdownButtonFormField<Department>(
        initialValue: null,
        decoration: const InputDecoration(labelText: 'القسم'),
        items: const [],
        onChanged: null,
        validator: (_) => 'اختر الكلية أولاً',
      );
    }

    final departmentsAsync = ref.watch(departmentsProvider(college.id));

    return departmentsAsync.when(
      data: (departments) {
        final selectedValue = departments.contains(selectedDepartment)
            ? selectedDepartment
            : null;

        return DropdownButtonFormField<Department>(
          initialValue: selectedValue,
          decoration: const InputDecoration(labelText: 'القسم'),
          items: departments
              .map(
                (department) => DropdownMenuItem<Department>(
                  value: department,
                  child: Text(department.name),
                ),
              )
              .toList(),
          onChanged: departments.isEmpty
              ? null
              : (department) {
                  ref
                      .read(selectedDepartmentProvider.notifier)
                      .select(department);
                },
          validator: (value) {
            if (departments.isEmpty) {
              return 'لا توجد أقسام لهذه الكلية';
            }
            return value == null ? 'القسم مطلوب' : null;
          },
        );
      },
      loading: () => const _LoadingDropdown(label: 'القسم'),
      error: (error, stackTrace) => _DropdownError(
        label: 'القسم',
        message: 'تعذر تحميل الأقسام',
        onRetry: () => ref.invalidate(departmentsProvider(college.id)),
      ),
    );
  }
}

class _LoadingDropdown extends StatelessWidget {
  final String label;

  const _LoadingDropdown({required this.label});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('جاري التحميل...'),
        ],
      ),
    );
  }
}

class _DropdownError extends StatelessWidget {
  final String label;
  final String message;
  final VoidCallback onRetry;

  const _DropdownError({
    required this.label,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: message),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
          style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
        ),
      ),
    );
  }
}
