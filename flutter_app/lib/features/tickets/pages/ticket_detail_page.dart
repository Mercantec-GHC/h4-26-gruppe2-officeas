import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/department_utils.dart';
import '../../../data/models/ticket_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/tickets_bloc.dart';
import '../bloc/tickets_event.dart';
import '../bloc/tickets_state.dart';

class TicketDetailPage extends StatefulWidget {
  final String ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final user = context.read<AuthBloc>().currentUser;

      final canEdit = isItSupportDepartment(user);
      context.read<TicketsBloc>().add(LoadTicketDetail(widget.ticketId));
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TicketsBloc>().add(
              LoadTicketDetail(widget.ticketId),
            ),
          ),
        ],
      ),
      body: BlocConsumer<TicketsBloc, TicketsState>(
        listener: (context, state) {
          if (state is TicketsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is CommentAddSuccess) {
            _commentController.clear();
          }
        },
        builder: (context, state) {
          if (state is TicketsLoading && state is! TicketDetailLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TicketDetailLoaded) {
              final canEdit = isItSupportDepartment(context.read<AuthBloc>().currentUser);
              return _DetailContent(
                ticket: state.ticket,
                commentController: _commentController,
                canChangeStatus: canEdit,
                onStatusChanged: (status) => context.read<TicketsBloc>().add(
                  UpdateTicketStatus(ticketId: widget.ticketId, status: status),
                ),
              onSendComment: () {
                final userId = context.read<AuthBloc>().currentUser?.id;

                if (userId == null) return;

                final content = _commentController.text.trim();

                if (content.isEmpty) return;

                context.read<TicketsBloc>().add(
                  AddComment(
                    ticketId: widget.ticketId,
                    content: content,
                    userId: userId,
                  ),
                );
              },
            );
          }

          if (state is TicketUpdateSuccess) {
            final canEdit = isItSupportDepartment(context.read<AuthBloc>().currentUser);
            return _DetailContent(
              ticket: state.ticket,
              commentController: _commentController,
              canChangeStatus: canEdit,
              onStatusChanged: (status) => context.read<TicketsBloc>().add(
                UpdateTicketStatus(ticketId: widget.ticketId, status: status),
              ),
              onSendComment: () {
                final userId = context.read<AuthBloc>().currentUser?.id;

                if (userId == null) return;

                final content = _commentController.text.trim();

                if (content.isEmpty) return;

                context.read<TicketsBloc>().add(
                  AddComment(
                    ticketId: widget.ticketId,
                    content: content,
                    userId: userId,
                  ),
                );
              },
            );
          }
          if (state is CommentAddSuccess) {
            final canEdit = isItSupportDepartment(context.read<AuthBloc>().currentUser);
            return _DetailContent(
              ticket: state.ticket,
              commentController: _commentController,
              canChangeStatus: canEdit,
              onStatusChanged: (status) => context.read<TicketsBloc>().add(
                UpdateTicketStatus(ticketId: widget.ticketId, status: status),
              ),
              onSendComment: () {
                final userId = context.read<AuthBloc>().currentUser?.id;

                if (userId == null) return;

                final content = _commentController.text.trim();

                if (content.isEmpty) return;

                context.read<TicketsBloc>().add(
                  AddComment(
                    ticketId: widget.ticketId,
                    content: content,
                    userId: userId,
                  ),
                );
              },
            );
          }

          return const Center(child: Text('Kunne ikke loade ticket'));
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final TicketModel ticket;
  final TextEditingController commentController;
  final ValueChanged<String> onStatusChanged;
  final bool canChangeStatus;
  final VoidCallback onSendComment;

  const _DetailContent({
    required this.ticket,
    required this.commentController,
    required this.onStatusChanged,
    required this.canChangeStatus,
    required this.onSendComment,
  });

  static const List<String> _statuses = [
    'OPEN',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'CANCELLED',
  ];

  static String _statusLabel(String s) {
    switch (s) {
      case 'OPEN':
        return 'Åben';
      case 'IN_PROGRESS':
        return 'I gang';
      case 'RESOLVED':
        return 'Løst';
      case 'CLOSED':
        return 'Lukket';
      case 'CANCELLED':
        return 'Annulleret';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text('Status:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: ticket.status,
                items: _statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_statusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: canChangeStatus ? (s) => s != null ? onStatusChanged(s) : null : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ticket.createdByName != null)
            Text(
              'Oprettet af ${ticket.createdByName} · ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          if (ticket.assignedToName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tildelt til ${ticket.assignedToName}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Kommentarer (${ticket.comments.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...ticket.comments.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.userName ?? 'Bruger',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(c.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.content),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Skriv en kommentar...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onSubmitted: (_) => onSendComment(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSendComment, child: const Text('Send')),
            ],
          ),
        ],
      ),
    );
  }
}
