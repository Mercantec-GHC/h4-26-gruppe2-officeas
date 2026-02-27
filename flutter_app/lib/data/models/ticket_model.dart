import 'ticket_comment_model.dart';

class TicketModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String createdByUserId;
  final String? assignedToUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final String? createdByName;
  final String? assignedToName;
  final List<TicketCommentModel> comments;

  TicketModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdByUserId,
    this.assignedToUserId,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.createdByName,
    this.assignedToName,
    this.comments = const [],
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final commentsJson = json['comments'];
    final commentsList = commentsJson is List
        ? commentsJson
              .map(
                (e) => TicketCommentModel.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : <TicketCommentModel>[];

    return TicketModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'OPEN',
      createdByUserId: json['created_by_user_id']?.toString() ?? '',
      assignedToUserId: json['assigned_to_user_id']?.toString(),
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      createdByName: json['created_by_user'] is Map
          ? json['created_by_user']['name']
          : null,
      assignedToName: json['assigned_to_user'] is Map
          ? json['assigned_to_user']['name']
          : null,
      comments: commentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'created_by_user_id': createdByUserId,
      'assigned_to_user_id': assignedToUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  TicketModel copyWith({
    String? title,
    String? description,
    String? status,
    String? assignedToUserId,
    List<TicketCommentModel>? comments,
  }) {
    return TicketModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdByUserId: createdByUserId,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      resolvedAt: resolvedAt,
      createdByName: createdByName,
      assignedToName: assignedToName,
      comments: comments ?? this.comments,
    );
  }
}
