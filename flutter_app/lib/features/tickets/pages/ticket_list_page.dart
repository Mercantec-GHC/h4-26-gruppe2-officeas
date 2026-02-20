import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../data/models/ticket_model.dart';
import '../bloc/tickets_bloc.dart';
import '../bloc/tickets_event.dart';
import '../bloc/tickets_state.dart';
import 'ticket_detail_page.dart';
import 'create_ticket_page.dart';

class TicketListPage extends StatefulWidget {
  const TicketListPage({super.key});

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  @override
  void initState() {
    super.initState();
    context.read<TicketsBloc>().add(const LoadTickets());
  }

  @override
  Widget build(BuildContext context) {
    return const _TicketListBody();
  }
}

class _TicketListBody extends StatelessWidget {
  const _TicketListBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikationer',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Opdater',
            onPressed: () =>
                context.read<TicketsBloc>().add(const RefreshTickets()),
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
        },
        builder: (context, state) {
          if (state is TicketsLoading) {
            final hasList =
                state is TicketsListLoaded ||
                context.read<TicketsBloc>().cachedTickets.isNotEmpty;

            if (!hasList) {
              return const Center(child: CircularProgressIndicator());
            }
          }

          if (state is TicketsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        context.read<TicketsBloc>().add(const LoadTickets()),
                    child: const Text('Prøv igen'),
                  ),
                ],
              ),
            );
          }

          final bloc = context.read<TicketsBloc>();

          final tickets = state is TicketsListLoaded
              ? state.tickets
              : bloc.cachedTickets;

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ingen tickets endnu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Opret din første ticket',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TicketsBloc>().add(const RefreshTickets());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];

                return _TicketCard(
                  ticket: ticket,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          TicketDetailPage(ticketId: ticket.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const CreateTicketPage(),
          ),
        ),
        child: const Icon(Icons.add),
        tooltip: 'Opret ticket',
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('dd/MM/yyyy').format(ticket.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          ticket.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusLabel(ticket.status),
                style: TextStyle(
                  fontSize: 12,
                  color: _statusColor(ticket.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (ticket.createdByName != null)
                Text(
                  'Oprettet af ${ticket.createdByName} · $created',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
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
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
