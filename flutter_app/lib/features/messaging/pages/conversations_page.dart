import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/messaging_models.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/messaging_bloc.dart';
import '../bloc/messaging_event.dart';
import '../bloc/messaging_state.dart';

/// Page that displays the list of conversations.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<MessagingBloc>().add(LoadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('Messages'),
      body: BlocBuilder<MessagingBloc, MessagingState>(
        buildWhen: (prev, curr) =>
            curr is ConversationsLoading ||
            curr is ConversationsLoaded ||
            curr is MessagingError,
        builder: (context, state) {
          if (state is ConversationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MessagingError) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<MessagingBloc>().add(LoadConversations()),
            );
          }
          if (state is ConversationsLoaded) {
            if (state.conversations.isEmpty) {
              return const _EmptyView();
            }
            return _ConversationList(conversations: state.conversations);
          }
          // MessagingInitial — trigger load
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/messages/new');
          if (context.mounted) {
            context.read<MessagingBloc>().add(LoadConversations());
          }
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// ─── Conversation list ────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final List<ConversationModel> conversations;

  const _ConversationList({required this.conversations});

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthBloc>().currentUser?.id.toString() ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MessagingBloc>().add(LoadConversations());
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return _ConversationTile(
            conversation: conv,
            currentUserId: currentUserId,
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final name = conversation.displayNameWithDepartment(currentUserId);
    final preview = conversation.lastMessagePreview.isEmpty
        ? 'No messages yet'
        : conversation.lastMessagePreview;
    final time = _formatTime(conversation.lastMessageAt);
    final unread = conversation.unreadCount;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primary,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: subtitleColor,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: unread > 0 ? scheme.primary : subtitleColor,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await context.push(
          '/messages/chat/${conversation.id}',
          extra: conversation,
        );
        // Refresh conversations after returning from chat
        // (state was MessagesLoaded, which buildWhen ignores).
        if (context.mounted) {
          context.read<MessagingBloc>().add(LoadConversations());
        }
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Empty & Error views ──────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: subtitleColor),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(fontSize: 16, color: subtitleColor),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Prøv igen')),
          ],
        ),
      ),
    );
  }
}
