import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_announcement_model.dart';
import '../models/app_notification_model.dart';
import 'user_repository.dart';

class AppNotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository = UserRepository();
  final String _collection = 'notifications';

  Stream<List<AppNotificationModel>> watchUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('recipient_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotificationModel.fromFirestore(doc))
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  Stream<int> watchUnreadCount(String userId) {
    return watchUserNotifications(userId).map(
      (notifications) => notifications.where((item) => !item.isRead).length,
    );
  }

  Stream<List<AppAnnouncementModel>> watchAnnouncements() {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: 'announcement')
        .snapshots()
        .map((snapshot) {
          final groups = <String, _AnnouncementAccumulator>{};

          for (final doc in snapshot.docs) {
            final notification = AppNotificationModel.fromFirestore(doc);
            final key = _announcementGroupKey(notification);
            groups
                .putIfAbsent(
                  key,
                  () => _AnnouncementAccumulator(
                    id: key,
                    title: notification.title,
                    body: notification.body,
                    createdAt: notification.createdAt,
                  ),
                )
                .add(notification);
          }

          final announcements =
              groups.values.map((group) => group.toModel()).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return announcements;
        });
  }

  Future<void> sendToUser({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    DateTime? createdAt,
  }) async {
    if (recipientId.trim().isEmpty) return;

    final notification = AppNotificationModel(
      id: _firestore.collection(_collection).doc().id,
      recipientId: recipientId,
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
      createdAt: createdAt ?? DateTime.now(),
    );

    await _firestore
        .collection(_collection)
        .doc(notification.id)
        .set(notification.toMap());
  }

  Future<void> sendToUsers({
    required Iterable<String> recipientIds,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    DateTime? createdAt,
  }) async {
    await _sendToUsers(
      recipientIds: recipientIds,
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
      createdAt: createdAt,
    );
  }

  Future<int> _sendToUsers({
    required Iterable<String> recipientIds,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    DateTime? createdAt,
  }) async {
    final uniqueRecipients = recipientIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueRecipients.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    var operationCount = 0;
    final notificationCreatedAt = createdAt ?? DateTime.now();

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final recipientId in uniqueRecipients) {
      final doc = _firestore.collection(_collection).doc();
      final notification = AppNotificationModel(
        id: doc.id,
        recipientId: recipientId,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        createdAt: notificationCreatedAt,
      );

      batch.set(doc, notification.toMap());
      operationCount++;

      if (operationCount >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
    return uniqueRecipients.length;
  }

  Future<void> sendToAllStudents({
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    final students = await _userRepository.getStudents().first;
    await sendToUsers(
      recipientIds: students.map((student) => student.id),
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
    );
  }

  Future<void> sendToCollegeStudents({
    required String title,
    required String body,
    required String type,
    required String college,
    String? relatedId,
  }) async {
    final students = await _userRepository.getStudentsByCollege(college).first;
    await sendToUsers(
      recipientIds: students.map((student) => student.id),
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
    );
  }

  Future<int> sendAnnouncementToAllStudents({
    required String title,
    required String body,
  }) async {
    final students = await _userRepository.getStudents().first;
    final announcementId = _firestore.collection(_collection).doc().id;

    return _sendToUsers(
      recipientIds: students.map((student) => student.id),
      title: title,
      body: body,
      type: 'announcement',
      relatedId: announcementId,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteAnnouncement(AppAnnouncementModel announcement) async {
    await _deleteNotificationsByIds(announcement.notificationIds);
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'is_read': true,
      'read_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('recipient_id', isEqualTo: userId)
        .get();

    WriteBatch batch = _firestore.batch();
    var operationCount = 0;
    final readAt = Timestamp.fromDate(DateTime.now());

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['is_read'] == true) continue;
      batch.update(doc.reference, {'is_read': true, 'read_at': readAt});
      operationCount++;

      if (operationCount >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
  }

  Future<void> _deleteNotificationsByIds(
    Iterable<String> notificationIds,
  ) async {
    final uniqueIds = notificationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    var operationCount = 0;

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final id in uniqueIds) {
      batch.delete(_firestore.collection(_collection).doc(id));
      operationCount++;

      if (operationCount >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
  }

  String _announcementGroupKey(AppNotificationModel notification) {
    final relatedId = notification.relatedId?.trim();
    if (relatedId != null && relatedId.isNotEmpty) return relatedId;

    final legacyMinute = notification.createdAt.millisecondsSinceEpoch ~/ 60000;
    return 'legacy_${notification.title}_${notification.body}_$legacyMinute';
  }
}

class _AnnouncementAccumulator {
  _AnnouncementAccumulator({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  DateTime createdAt;
  final Set<String> _recipientIds = <String>{};
  final List<String> _notificationIds = <String>[];

  void add(AppNotificationModel notification) {
    _notificationIds.add(notification.id);
    if (notification.recipientId.trim().isNotEmpty) {
      _recipientIds.add(notification.recipientId);
    }
    if (notification.createdAt.isAfter(createdAt)) {
      createdAt = notification.createdAt;
    }
  }

  AppAnnouncementModel toModel() {
    return AppAnnouncementModel(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      recipientsCount: _recipientIds.length,
      notificationIds: List.unmodifiable(_notificationIds),
    );
  }
}
