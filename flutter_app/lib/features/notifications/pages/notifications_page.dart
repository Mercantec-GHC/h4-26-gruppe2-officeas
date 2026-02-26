import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/messaging_remote_datasource.dart';
import '../../../data/datasources/notifications_remote_datasource.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/messaging_models.dart';
import '../../../core/widgets/app_topbar_actions.dart';
import '../../messaging/bloc/messaging_bloc.dart';
import '../../messaging/pages/chat_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsRemoteDataSource _dataSource =
      NotificationsRemoteDataSource();
  final MessagingRemoteDataSource _messagingDataSource =
      MessagingRemoteDataSource();

  bool _isLoading = true;
  String? _error;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _dataSource.getNotifications(limit: 100);
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kunne ikke hente notifikationer.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _dataSource.markAsRead(notification.id);
      if (!mounted) return;

      setState(() {
        _notifications = _notifications
            .map(
              (n) => n.id == notification.id
                  ? n.copyWith(readAt: DateTime.now())
                  : n,
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunne ikke markere notifikation som læst'),
        ),
      );
    }
  }

  Future<void> _markUnread(NotificationModel notification) async {
    if (!notification.isRead) return;

    try {
      await _dataSource.markAsUnread(notification.id);
      if (!mounted) return;

      setState(() {
        _notifications = _notifications
            .map(
              (n) =>
                  n.id == notification.id ? n.copyWith(clearReadAt: true) : n,
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunne ikke markere notifikation som ulæst'),
        ),
      );
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await _dataSource.deleteNotification(notification.id);
      if (!mounted) return;

      setState(() {
        _notifications = _notifications
            .where((n) => n.id != notification.id)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunne ikke slette notifikation')),
      );
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // First tap behaves like inboxes usually do: open + mark as read.
    if (!notification.isRead) {
      await _markRead(notification);
    }

    if (!mounted) return;

    final relatedType = notification.relatedEntityType;
    final relatedId = notification.relatedEntityId;

    if ((relatedType == 'conversation' ||
            notification.type == 'MESSAGE_RECEIVED') &&
        relatedId != null &&
        relatedId.isNotEmpty) {
      try {
        // We only store conversation id on message notifications, so resolve it here.
        final conversations = await _messagingDataSource.getConversations();
        if (!mounted) return;

        ConversationModel? conversation;
        for (final conv in conversations) {
          if (conv.id == relatedId) {
            conversation = conv;
            break;
          }
        }

        if (conversation != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MessagingBloc>(),
                child: ChatPage(conversation: conversation!),
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Silent fallback below keeps tap behavior stable even if fetch fails.
        if (!mounted) return;
      }
    }

    if (relatedType == 'shift') {
      await Navigator.pushNamed(context, '/calendar');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      // Friendly fallback until ticket/absence detail pages exist.
      const SnackBar(
        content: Text(
          'Detaljevisning for denne notifikation er ikke tilgængelig endnu',
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'MESSAGE_RECEIVED':
        return Icons.chat_bubble_outline;
      case 'TICKET_ASSIGNED':
      case 'TICKET_UPDATED':
      case 'TICKET_COMMENTED':
        return Icons.confirmation_num_outlined;
      case 'ABSENCE_APPROVED':
      case 'ABSENCE_REJECTED':
      case 'ABSENCE_COMMENTED':
        return Icons.event_note_outlined;
      case 'SHIFT_CREATED':
      case 'SHIFT_CANCELLED':
        return Icons.calendar_today_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikationer'),
        actions: const [AppTopBarActions(showNotifications: false)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _notifications.isEmpty
          ? const Center(child: Text('Ingen notifikationer endnu'))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final createdAt = DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(notification.createdAt.toLocal());

                  return ListTile(
                    onTap: () => _handleNotificationTap(notification),
                    leading: Icon(_iconForType(notification.type)),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${notification.message}\n$createdAt',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'read') {
                          await _markRead(notification);
                        } else if (value == 'unread') {
                          await _markUnread(notification);
                        } else if (value == 'delete') {
                          await _deleteNotification(notification);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: notification.isRead ? 'unread' : 'read',
                          child: Text(
                            notification.isRead
                                ? 'Markér som ulæst'
                                : 'Markér som læst',
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Slet notifikation'),
                        ),
                      ],
                      child: notification.isRead
                          ? const Icon(Icons.more_vert)
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 10),
                                SizedBox(width: 4),
                                Icon(Icons.more_vert),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
