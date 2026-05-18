import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/app_notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/app_notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();

  Future<void> _markAllAsRead(String userId) async {
    await _notificationRepository.markAllAsRead(userId);
  }

  Future<void> _markAsRead(AppNotificationModel notification) async {
    if (notification.isRead) return;
    await _notificationRepository.markAsRead(notification.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'تحديد الكل كمقروء',
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllAsRead(user.id),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('يلزم تسجيل الدخول لعرض الإشعارات.'))
          : StreamBuilder<List<AppNotificationModel>>(
              stream: _notificationRepository.watchUserNotifications(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('تعذر تحميل الإشعارات حاليًا.'),
                  );
                }

                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [_EmptyNotificationsCard()],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return _NotificationCard(
                      notification: notifications[index],
                      onTap: () => _markAsRead(notifications[index]),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead
          ? Colors.white
          : AppTheme.primaryColor.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_typeIcon(notification.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(notification.body),
                    const SizedBox(height: 10),
                    Text(
                      _formatDateTime(notification.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'registration_approved':
        return Icons.check_circle;
      case 'registration_rejected':
        return Icons.cancel;
      case 'match_scheduled':
        return Icons.sports_score;
      case 'schedule_changed':
        return Icons.edit_calendar;
      case 'tournament_started':
        return Icons.emoji_events;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'registration_approved':
        return Colors.green;
      case 'registration_rejected':
        return Colors.red;
      case 'match_scheduled':
        return Colors.indigo;
      case 'schedule_changed':
        return Colors.deepOrange;
      case 'tournament_started':
        return Colors.amber[800]!;
      case 'announcement':
        return Colors.teal;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/$month/$day - $hour:$minute';
  }
}

class _EmptyNotificationsCard extends StatelessWidget {
  const _EmptyNotificationsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد إشعارات بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر هنا تحديثات الطلبات والمباريات والإعلانات.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
