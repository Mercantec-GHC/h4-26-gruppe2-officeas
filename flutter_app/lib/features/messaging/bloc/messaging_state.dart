import 'package:equatable/equatable.dart';
import '../../../data/models/messaging_models.dart';

abstract class MessagingState extends Equatable {
  const MessagingState();

  @override
  List<Object?> get props => [];
}

/// Initial state — nothing loaded yet.
class MessagingInitial extends MessagingState {}

/// Loading the conversation list.
class ConversationsLoading extends MessagingState {}

/// Conversations loaded successfully.
class ConversationsLoaded extends MessagingState {
  final List<ConversationModel> conversations;

  const ConversationsLoaded({required this.conversations});

  @override
  List<Object?> get props => [conversations];
}

/// Loading messages for a conversation.
class MessagesLoading extends MessagingState {
  final String conversationId;

  const MessagesLoading({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Messages loaded for a conversation.
class MessagesLoaded extends MessagingState {
  final String conversationId;
  final List<MessageModel> messages;
  final bool hasMore;
  final int total;

  const MessagesLoaded({
    required this.conversationId,
    required this.messages,
    this.hasMore = false,
    this.total = 0,
  });

  MessagesLoaded copyWith({
    List<MessageModel>? messages,
    bool? hasMore,
    int? total,
  }) {
    return MessagesLoaded(
      conversationId: conversationId,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }

  @override
  List<Object?> get props => [conversationId, messages, hasMore, total];
}

/// A messaging operation failed.
class MessagingError extends MessagingState {
  final String message;

  const MessagingError({required this.message});

  @override
  List<Object?> get props => [message];
}
