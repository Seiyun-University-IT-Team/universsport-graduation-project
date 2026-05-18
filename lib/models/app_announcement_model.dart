class AppAnnouncementModel {
  const AppAnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.recipientsCount,
    required this.notificationIds,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final int recipientsCount;
  final List<String> notificationIds;
}
