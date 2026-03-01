import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/models/ticket_model.dart';
import '../bloc/tickets_bloc.dart';
import '../bloc/tickets_event.dart';
import '../bloc/tickets_state.dart';

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

class _TicketListBody extends StatefulWidget {
  const _TicketListBody();

  @override
  State<_TicketListBody> createState() => _TicketListBodyState();
}

class _TicketListBodyState extends State<_TicketListBody> {
  String _query = '';
  String _statusFilter = 'ALL';
  String? _selectedTicketId;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectTicket(String id) {
    setState(() {
      _selectedTicketId = id;
    });
  }

  List<TicketModel> _applyFilters(List<TicketModel> tickets) {
    var list = tickets;
    if (_statusFilter != 'ALL') {
      list = list.where((t) => t.status == _statusFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  String _statusLabel(String status) {
    switch (status) {
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
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'IN_PROGRESS':
        return scheme.primary;
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search tickets',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const statuses = ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: statuses.map((s) {
          final selected = s == _statusFilter;
          final label = s == 'ALL'
              ? 'All'
              : (s == 'OPEN'
                    ? 'Open'
                    : s == 'IN_PROGRESS'
                    ? 'In progress'
                    : 'Resolved');
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _statusFilter = s),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    return AppScaffold(
      title: const Text('Tickets'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Opdater',
          onPressed: () =>
              context.read<TicketsBloc>().add(const RefreshTickets()),
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
        },
        builder: (context, state) {
          final bloc = context.read<TicketsBloc>();
          final tickets = state is TicketsListLoaded
              ? state.tickets
              : bloc.cachedTickets;

          if (state is TicketsLoading && tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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

          final filtered = _applyFilters(tickets);

          if (filtered.isEmpty) {
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
                    'No tickets yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first ticket',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final isWide = MediaQuery.of(context).size.width >= 900;

          Widget list = RefreshIndicator(
            onRefresh: () async {
              context.read<TicketsBloc>().add(const RefreshTickets());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ticket = filtered[index];
                return _TicketCard(
                  ticket: ticket,
                  onTap: () {
                    if (isWide) {
                      _selectTicket(ticket.id);
                    } else {
                      context.push('/tickets/${ticket.id}');
                    }
                  },
                );
              },
            ),
          );

          Widget preview;
          if (isWide) {
            final selected = filtered.firstWhere(
              (t) => t.id == _selectedTicketId,
              orElse: () => filtered.first,
            );
            preview = Container(
              color: isDark
                  ? scheme.surfaceContainerHighest
                  : Colors.grey.shade50,
              width: 360,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLabel(selected.status),
                    style: TextStyle(
                      color: _statusColor(context, selected.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selected.createdByName != null)
                    Text(
                      'Created by ${selected.createdByName}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: mutedText),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        selected.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            context.push('/tickets/${selected.id}'),
                        child: const Text('Open'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Assign'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            preview = const SizedBox.shrink();
          }

          return Column(
            children: [
              _buildSearchBar(),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(
                child: isWide
                    ? Row(
                        children: [
                          Expanded(flex: 2, child: list),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 360, child: preview),
                        ],
                      )
                    : list,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-ticket'),
        tooltip: 'Create ticket',
        child: const Icon(Icons.add),
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
    final mutedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
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
                  color: _statusColor(context, ticket.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (ticket.createdByName != null)
                Text(
                  'Created by ${ticket.createdByName} · $created',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: mutedText),
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
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'IN_PROGRESS':
        return scheme.primary;
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
