import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_announcement_model.dart';
import '../../repositories/app_notification_repository.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();
  final Set<String> _deletingAnnouncementIds = <String>{};

  Future<void> _showCreateAnnouncementDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إنشاء إعلان جديد'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإعلان',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'العنوان مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'نص الإعلان',
                        prefixIcon: Icon(Icons.campaign),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'نص الإعلان مطلوب'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSending = true);
                          final messenger = ScaffoldMessenger.of(this.context);
                          final navigator = Navigator.of(dialogContext);

                          try {
                            final recipientsCount =
                                await _notificationRepository
                                    .sendAnnouncementToAllStudents(
                                      title: titleController.text.trim(),
                                      body: bodyController.text.trim(),
                                    );

                            if (!mounted) return;
                            if (dialogContext.mounted) navigator.pop();

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  recipientsCount == 0
                                      ? 'لا يوجد طلاب لإرسال الإعلان لهم'
                                      : 'تم إرسال الإعلان إلى $recipientsCount طالب',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSending = false);
                            }
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('تعذر إرسال الإعلان: $e')),
                            );
                          }
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
  }

  Future<void> _deleteAnnouncement(AppAnnouncementModel announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف إعلان'),
        content: Text(
          'هل تريد حذف إعلان "${announcement.title}" من جميع المستخدمين؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true ||
        _deletingAnnouncementIds.contains(announcement.id)) {
      return;
    }

    setState(() => _deletingAnnouncementIds.add(announcement.id));
    try {
      await _notificationRepository.deleteAnnouncement(announcement);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الإعلان بالكامل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف الإعلان: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingAnnouncementIds.remove(announcement.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعلانات الطلاب')),
      body: StreamBuilder<List<AppAnnouncementModel>>(
        stream: _notificationRepository.watchAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل الإعلانات حالياً.'));
          }

          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [_EmptyAnnouncementsCard()],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              final isDeleting = _deletingAnnouncementIds.contains(
                announcement.id,
              );

              return _AnnouncementCard(
                announcement: announcement,
                isDeleting: isDeleting,
                onDelete: () => _deleteAnnouncement(announcement),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إنشاء إعلان',
        onPressed: _showCreateAnnouncementDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.isDeleting,
    required this.onDelete,
  });

  final AppAnnouncementModel announcement;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: const Icon(Icons.campaign, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(announcement.body),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.schedule,
                        label: _formatDateTime(announcement.createdAt),
                      ),
                      _InfoChip(
                        icon: Icons.groups,
                        label: '${announcement.recipientsCount} مستلم',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isDeleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'حذف الإعلان',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/$month/$day - $hour:$minute';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnnouncementsCard extends StatelessWidget {
  const _EmptyAnnouncementsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد إعلانات بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'استخدم زر الإضافة لإنشاء إعلان جديد وإرساله لجميع الطلاب.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
