class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? relatedEntityId;
  final String? relatedEntityType;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.readAt,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'].toString())
          : null,
      relatedEntityId: json['related_entity_id']?.toString(),
      relatedEntityType: json['related_entity_type']?.toString(),
    );
  }

  bool get isRead => readAt != null;

  NotificationModel copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
    );
  }
}
