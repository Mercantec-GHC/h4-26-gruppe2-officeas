import 'package:equatable/equatable.dart';

abstract class MessagingEvent extends Equatable {
  const MessagingEvent();

  @override
  List<Object?> get props => [];
}

/// Load the list of conversations.
class LoadConversations extends MessagingEvent {}

/// Create a new conversation.
class CreateConversation extends MessagingEvent {
  final List<String> userIds;
  final bool isGroup;

  const CreateConversation({required this.userIds, this.isGroup = false});

  @override
  List<Object?> get props => [userIds, isGroup];
}

/// Select a conversation and load its messages.
class OpenConversation extends MessagingEvent {
  final String conversationId;

  const OpenConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Load more (older) messages for the current conversation.
class LoadMoreMessages extends MessagingEvent {}

/// Send a message in the current conversation.
class SendMessage extends MessagingEvent {
  final String content;

  const SendMessage({required this.content});

  @override
  List<Object?> get props => [content];
}

/// Mark a message as read.
class MarkMessageRead extends MessagingEvent {
  final String messageId;

  const MarkMessageRead({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

/// Received a real-time event from the WebSocket.
class WebSocketEventReceived extends MessagingEvent {
  final String type;
  final Map<String, dynamic> payload;

  const WebSocketEventReceived({required this.type, required this.payload});

  @override
  List<Object?> get props => [type, payload];
}
