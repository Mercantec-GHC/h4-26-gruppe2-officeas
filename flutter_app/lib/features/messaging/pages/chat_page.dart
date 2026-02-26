import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_topbar_actions.dart';
import '../../../data/models/messaging_models.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/messaging_bloc.dart';
import '../bloc/messaging_event.dart';
import '../bloc/messaging_state.dart';

/// Chat page — shows messages for a single conversation.
class ChatPage extends StatefulWidget {
  final ConversationModel conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  static const int _maxMessageLength = 2000;

  @override
  void initState() {
    super.initState();
    context.read<MessagingBloc>().add(
      OpenConversation(conversationId: widget.conversation.id),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<MessagingBloc>().add(LoadMoreMessages());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthBloc>().currentUser?.id.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conversation.displayNameWithDepartment(currentUserId),
        ),
        actions: const [AppTopBarActions()],
      ),
      body: BlocListener<MessagingBloc, MessagingState>(
        listenWhen: (prev, curr) => curr is MessagingError,
        listener: (context, state) {
          if (state is MessagingError) {
            final scheme = Theme.of(context).colorScheme;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: scheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<MessagingBloc, MessagingState>(
                buildWhen: (prev, curr) =>
                    curr is MessagesLoading || curr is MessagesLoaded,
                builder: (context, state) {
                  if (state is MessagesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is MessagesLoaded) {
                    if (state.messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Skriv den første besked!',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.72),
                          ),
                        ),
                      );
                    }
                    return _MessageList(
                      messages: state.messages,
                      currentUserId: currentUserId,
                      scrollController: _scrollController,
                      hasMore: state.hasMore,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            _MessageInput(controller: _controller, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > _maxMessageLength) return;
    context.read<MessagingBloc>().add(SendMessage(content: text));
    _controller.clear();
  }
}

// ─── Message list ─────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<MessageModel> messages;
  final String currentUserId;
  final ScrollController scrollController;
  final bool hasMore;

  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final msg = messages[index];
        final isMe = msg.senderId == currentUserId;

        // Mark unread messages from others as read.
        if (!isMe && msg.readAt == null) {
          context.read<MessagingBloc>().add(MarkMessageRead(messageId: msg.id));
        }

        return _MessageBubble(message: msg, isMe: isMe);
      },
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? scheme.onPrimary : scheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? scheme.onPrimary.withValues(alpha: 0.7)
                        : subtitleColor,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: scheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Message input ────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 2000,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Skriv en besked...',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded),
            color: scheme.primary,
          ),
        ],
      ),
    );
  }
}
