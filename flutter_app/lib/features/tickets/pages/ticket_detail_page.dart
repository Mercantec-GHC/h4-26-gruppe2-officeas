import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/utils/department_utils.dart';
import '../../../core/utils/pick_image_bytes.dart';
import '../../../core/widgets/auth_image.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/repositories/user_repository.dart';
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
    return AppScaffold(
      title: const Text('Ticket'),
      showBackButtonWhenPossible: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<TicketsBloc>().add(
            LoadTicketDetail(widget.ticketId),
          ),
        ),
      ],
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
          if (state is TicketUpdateSuccess && state.ticket.imagePath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TicketsLoading && state is! TicketDetailLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TicketDetailLoaded) {
            final canEdit = isItSupportDepartment(
              context.read<AuthBloc>().currentUser,
            );
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
              onUploadImage: (bytes, filename) =>
                  context.read<TicketsBloc>().add(
                    UploadTicketImage(
                      ticketId: widget.ticketId,
                      imageBytes: bytes,
                      filename: filename,
                    ),
                  ),
            );
          }

          if (state is TicketUpdateSuccess) {
            final canEdit = isItSupportDepartment(
              context.read<AuthBloc>().currentUser,
            );
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
              onUploadImage: (bytes, filename) =>
                  context.read<TicketsBloc>().add(
                    UploadTicketImage(
                      ticketId: widget.ticketId,
                      imageBytes: bytes,
                      filename: filename,
                    ),
                  ),
            );
          }
          if (state is CommentAddSuccess) {
            final canEdit = isItSupportDepartment(
              context.read<AuthBloc>().currentUser,
            );
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
              onUploadImage: (bytes, filename) =>
                  context.read<TicketsBloc>().add(
                    UploadTicketImage(
                      ticketId: widget.ticketId,
                      imageBytes: bytes,
                      filename: filename,
                    ),
                  ),
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
  final void Function(List<int> bytes, String filename)? onUploadImage;

  const _DetailContent({
    required this.ticket,
    required this.commentController,
    required this.onStatusChanged,
    required this.canChangeStatus,
    required this.onSendComment,
    this.onUploadImage,
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
        return 'Open';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    try {
      final result = await pickImageBytes(context);
      if (result != null && context.mounted) {
        onUploadImage!(result.bytes, result.filename);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
                onChanged: canChangeStatus
                    ? (s) => s != null ? onStatusChanged(s) : null
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ticket.createdByName != null)
            Text(
              'Created by ${ticket.createdByName} · ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          if (ticket.assignedToName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Assigned to ${ticket.assignedToName}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ],
          if (ticket.imagePath != null && ticket.imagePath!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Problem image',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: AuthImage(
                  imageUrl: UserRepository.imageUrl(
                    '/tickets/${ticket.id}/image?v=${ticket.updatedAt.millisecondsSinceEpoch}',
                  ),
                  token: context.read<AuthBloc>().currentToken,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
          if (onUploadImage != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickAndUploadImage(context),
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                ticket.imagePath != null && ticket.imagePath!.isNotEmpty
                    ? 'Skift billede'
                    : 'Tilføj billede af problemet',
              ),
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
                          c.userName ?? 'User',
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
