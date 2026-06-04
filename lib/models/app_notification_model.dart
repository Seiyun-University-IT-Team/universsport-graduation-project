import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? relatedId;
  final bool isRead;

  const AppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.relatedId,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipient_id': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'created_at': Timestamp.fromDate(createdAt),
      'related_id': relatedId,
      'is_read': isRead,
    };
  }

  factory AppNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return AppNotificationModel(
      id: doc.id,
      recipientId: map['recipient_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedId: map['related_id'] as String?,
      isRead: map['is_read'] ?? false,
    );
  }
}
