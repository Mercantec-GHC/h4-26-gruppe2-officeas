/// Data models for the messaging module.
/// Maps directly to the Go backend JSON responses.

class ConversationModel {
  final String id;
  final String departmentId;
  final bool isGroup;
  final DateTime? lastMessageAt;
  final String lastMessagePreview;
  final int unreadCount;
  final List<ConversationMemberModel> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.departmentId,
    required this.isGroup,
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.unreadCount = 0,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      departmentId: json['department_id'] ?? '',
      isGroup: json['is_group'] ?? false,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      lastMessagePreview: json['last_message_preview'] ?? '',
      unreadCount: json['unread_count'] ?? 0,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => ConversationMemberModel.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Returns a display name for the conversation.
  /// For 1:1 chats, shows the other person's name.
  String displayName(String currentUserId) {
    if (isGroup) return 'Group (${members.length})';
    final other = members.where((m) => m.userId != currentUserId);
    if (other.isNotEmpty) return other.first.userName;
    return 'Conversation';
  }

  ConversationModel copyWith({
    int? unreadCount,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) {
    return ConversationModel(
      id: id,
      departmentId: departmentId,
      isGroup: isGroup,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      members: members,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ConversationMemberModel {
  final String userId;
  final String userName;
  final DateTime joinedAt;

  const ConversationMemberModel({
    required this.userId,
    required this.userName,
    required this.joinedAt,
  });

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    return ConversationMemberModel(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      joinedAt: DateTime.parse(
        json['joined_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }

  bool get isRead => readAt != null;

  MessageModel copyWith({DateTime? readAt}) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class PaginatedMessagesModel {
  final List<MessageModel> messages;
  final int total;
  final int limit;
  final int offset;

  const PaginatedMessagesModel({
    required this.messages,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PaginatedMessagesModel.fromJson(Map<String, dynamic> json) {
    return PaginatedMessagesModel(
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => MessageModel.fromJson(e))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
    );
  }

  bool get hasMore => offset + messages.length < total;
}

/// WebSocket event received from the server.
class WebSocketEventModel {
  final String type;
  final Map<String, dynamic> payload;

  const WebSocketEventModel({required this.type, required this.payload});

  factory WebSocketEventModel.fromJson(Map<String, dynamic> json) {
    return WebSocketEventModel(
      type: json['type'] ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}
