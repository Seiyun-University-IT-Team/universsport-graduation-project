import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/competition_model.dart';
import '../../models/registration_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../repositories/app_notification_repository.dart';
import '../../repositories/competition_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/team_repository.dart';
import '../../repositories/user_repository.dart';

class ManageRegistrationsScreen extends StatefulWidget {
  const ManageRegistrationsScreen({super.key});

  @override
  State<ManageRegistrationsScreen> createState() =>
      _ManageRegistrationsScreenState();
}

class _ManageRegistrationsScreenState extends State<ManageRegistrationsScreen> {
  final RegistrationRepository _registrationRepository =
      RegistrationRepository();
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();
  final CompetitionRepository _competitionRepository = CompetitionRepository();
  final UserRepository _userRepository = UserRepository();
  final Map<String, Future<_RegistrationDetails>> _detailsFutures =
      <String, Future<_RegistrationDetails>>{};
  final Set<String> _updatingRegistrationIds = <String>{};
  bool _isApprovingAll = false;

  Future<void> _updateRegistrationStatus(
    RegistrationModel registration,
    String status,
  ) async {
    if (_updatingRegistrationIds.contains(registration.id)) return;

    final isApproved = status == 'approved';
    setState(() => _updatingRegistrationIds.add(registration.id));

    try {
      await _registrationRepository.updateRegistrationStatus(
        registration.id,
        status,
      );

      if (isApproved && registration.competitionId != null) {
        final competition = await _competitionRepository.getCompetitionById(
          registration.competitionId!,
        );
        if (competition != null && competition.type == 'team') {
          final user = await _userRepository.getUserById(registration.userId);
          if (user != null &&
              user.college != null &&
              user.department != null &&
              user.academicLevel != null) {
            final teamRepo = TeamRepository();
            final safeCollege = user.college!.replaceAll(' ', '_');
            final safeDept = user.department!.replaceAll(' ', '_');
            final safeLevel = user.academicLevel!.replaceAll(' ', '_');
            final teamId = '${safeCollege}_${safeDept}_$safeLevel';
            final teamName = '${user.department} ${user.academicLevel}';

            final existingTeam = await teamRepo.getTeamById(teamId);
            if (existingTeam == null) {
              await teamRepo.addTeam(
                TeamModel(
                  id: teamId,
                  name: teamName,
                  college: user.college!,
                  players: [user.id],
                ),
              );
            } else {
              if (!existingTeam.players.contains(user.id)) {
                await teamRepo.addPlayer(teamId, user.id);
              }
            }
          }
        }
      }

      var notificationSent = true;
      try {
        await _notificationRepository.sendToUser(
          recipientId: registration.userId,
          title: isApproved ? 'تم قبول طلبك' : 'تم رفض طلبك',
          body: isApproved
              ? 'تم قبول طلب التسجيل الخاص بك. يمكنك متابعة جدول المباريات من واجهة الطالب.'
              : 'تم رفض طلب التسجيل الخاص بك. راجع إدارة النشاط الرياضي إذا احتجت إلى توضيح.',
          type: isApproved ? 'registration_approved' : 'registration_rejected',
          relatedId: registration.competitionId ?? registration.sportId,
        );
      } catch (e) {
        notificationSent = false;
        debugPrint('Registration notification error: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationSent
                ? (isApproved
                      ? 'تم قبول الطلب وإشعار الطالب'
                      : 'تم رفض الطلب وإشعار الطالب')
                : (isApproved
                      ? 'تم قبول الطلب، لكن تعذر إرسال الإشعار'
                      : 'تم رفض الطلب، لكن تعذر إرسال الإشعار'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث الطلب: $e')));
    } finally {
      if (mounted) {
        setState(() => _updatingRegistrationIds.remove(registration.id));
      }
    }
  }

  Future<void> _approveAll(List<RegistrationModel> registrations) async {
    if (_isApprovingAll) return;
    final pending = registrations.where((r) => r.status == 'pending').toList();
    if (pending.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قبول جميع الطلبات'),
        content: Text('هل تريد قبول ${pending.length} طلب معلق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول الكل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isApprovingAll = true);
    int successCount = 0;
    for (final reg in pending) {
      try {
        await _updateRegistrationStatus(reg, 'approved');
        successCount++;
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isApprovingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم قبول $successCount طلب بنجاح.')),
      );
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin_dashboard');
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    Color? color,
  }) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: iconColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_RegistrationDetails> _registrationDetails(
    RegistrationModel registration,
  ) {
    final cacheKey =
        '${registration.id}_${registration.userId}_${registration.competitionId ?? ''}';

    return _detailsFutures.putIfAbsent(cacheKey, () async {
      final futures = await Future.wait<Object?>([
        _userRepository.getUserById(registration.userId),
        if (registration.competitionId != null)
          _competitionRepository.getCompetitionById(registration.competitionId!)
        else
          Future<CompetitionModel?>.value(),
      ]);

      final user = futures[0] as UserModel?;
      final competition = futures[1] as CompetitionModel?;

      return _RegistrationDetails(
        studentName: _safeText(user?.name, fallback: 'طالب غير معروف'),
        collegeName: _safeText(user?.college, fallback: 'غير محددة'),
        competitionName: _safeText(
          competition?.name,
          fallback: registration.competitionId == null
              ? 'غير محددة'
              : 'بطولة غير معروفة',
        ),
      );
    });
  }

  String _safeText(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  Widget _buildRegistrationCard({
    required RegistrationModel registration,
    required bool isUpdating,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_ind_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'طلب تسجيل جديد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  _formatDate(registration.registrationDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<_RegistrationDetails>(
              future: _registrationDetails(registration),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _RegistrationInfoBlock(
                    studentName: 'تعذر تحميل بيانات الطالب',
                    collegeName: 'تعذر تحميل بيانات الكلية',
                    competitionName: 'تعذر تحميل بيانات البطولة',
                    muted: true,
                  );
                }

                final details = snapshot.data;
                return _RegistrationInfoBlock(
                  studentName:
                      details?.studentName ?? 'جاري تحميل اسم الطالب...',
                  collegeName: details?.collegeName ?? 'جاري تحميل الكلية...',
                  competitionName:
                      details?.competitionName ?? 'جاري تحميل البطولة...',
                  muted: details == null,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            await _updateRegistrationStatus(
                              registration,
                              'rejected',
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            await _updateRegistrationStatus(
                              registration,
                              'approved',
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('قبول'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التسجيل'),
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          StreamBuilder<List<RegistrationModel>>(
            stream: _registrationRepository.getPendingRegistrations(),
            builder: (context, snapshot) {
              final regs = snapshot.data ?? [];
              final hasPending = regs.any((r) => r.status == 'pending');
              if (!hasPending) return const SizedBox.shrink();
              return _isApprovingAll
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () => _approveAll(regs),
                      icon: const Icon(Icons.done_all, color: Colors.white),
                      label: const Text(
                        'قبول الكل',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: _registrationRepository.getPendingRegistrations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.error_outline,
              message:
                  'تعذر جلب طلبات التسجيل. تأكد من الاتصال والصلاحيات ثم حاول مرة أخرى.',
              color: Colors.red,
            );
          }

          final registrations = snapshot.data ?? [];

          if (registrations.isEmpty) {
            return _buildMessage(
              icon: Icons.fact_check_outlined,
              message: 'لا توجد طلبات تسجيل معلقة حالياً.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: registrations.length,
            itemBuilder: (context, index) {
              final reg = registrations[index];
              final isUpdating = _updatingRegistrationIds.contains(reg.id);

              return _buildRegistrationCard(
                registration: reg,
                isUpdating: isUpdating,
              );
            },
          );
        },
      ),
    );
  }
}

class _RegistrationInfoBlock extends StatelessWidget {
  final String studentName;
  final String collegeName;
  final String competitionName;
  final bool muted;

  const _RegistrationInfoBlock({
    required this.studentName,
    required this.collegeName,
    required this.competitionName,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: 'اسم الطالب',
            value: studentName,
            muted: muted,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.account_balance_outlined,
            label: 'اسم الكلية',
            value: collegeName,
            muted: muted,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.emoji_events_outlined,
            label: 'اسم البطولة',
            value: competitionName,
            muted: muted,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? Colors.grey[600] : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: muted ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationDetails {
  final String studentName;
  final String collegeName;
  final String competitionName;

  const _RegistrationDetails({
    required this.studentName,
    required this.collegeName,
    required this.competitionName,
  });
}
