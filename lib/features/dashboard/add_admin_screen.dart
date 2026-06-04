import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../features/colleges/domain/entities/college.dart';
import '../../features/colleges/presentation/providers/college_dropdown_providers.dart';

class AddAdminScreen extends ConsumerStatefulWidget {
  const AddAdminScreen({super.key});

  @override
  ConsumerState<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends ConsumerState<AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  UserRole _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _adminCreationErrorMessage(Object error) {
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

    return 'تعذر إنشاء الحساب، حاول مرة أخرى';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final selectedCollege = ref.read(selectedCollegeProvider);
    if (_selectedRole == UserRole.supervisor && selectedCollege == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الكلية')),
      );
      return;
    }

    final authProvider = legacy_provider.Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.createAdminAccount(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        college: _selectedRole == UserRole.supervisor ? selectedCollege?.name : null,
      );

      if (!mounted) return;
      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _selectedRole = UserRole.admin;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedRole == UserRole.admin ? 'تم إنشاء حساب المدير بنجاح' : 'تم إنشاء حساب المشرف بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_adminCreationErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final selectedCollege = ref.watch(selectedCollegeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مدير أو مشرف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<UserRole>(
                key: ValueKey(_selectedRole),
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'نوع الحساب',
                  prefixIcon: Icon(Icons.manage_accounts),
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.admin,
                    child: Text('مدير نظام'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.supervisor,
                    child: Text('مشرف نشاط كلية'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_selectedRole == UserRole.supervisor) ...[
                _CollegeDropdown(selectedCollege: selectedCollege),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'مطلوب';
                  if (!email.contains('@')) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return 'مطلوب';
                  if (password.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'مطلوب';
                  if (value != _passwordController.text) {
                    return 'كلمتا المرور غير متطابقتين';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: Icon(_selectedRole == UserRole.admin ? Icons.admin_panel_settings : Icons.supervisor_account),
                      label: Text(_selectedRole == UserRole.admin ? 'إنشاء حساب مدير' : 'إنشاء حساب مشرف'),
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
          decoration: const InputDecoration(
            labelText: 'الكلية',
            prefixIcon: Icon(Icons.account_balance),
          ),
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
                },
          validator: (value) {
            if (colleges.isEmpty) {
              return 'لا توجد كليات متاحة';
            }
            return value == null ? 'الكلية مطلوبة' : null;
          },
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'الكلية',
          prefixIcon: Icon(Icons.account_balance),
        ),
        child: Row(
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
      ),
      error: (error, stackTrace) => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'الكلية',
          prefixIcon: Icon(Icons.account_balance),
          errorText: 'تعذر تحميل الكليات',
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(collegesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ),
      ),
    );
  }
}

