import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../domain/repositories/shift_repository.dart';
import '../../../domain/entities/shift_entity.dart';

import '../../tickets/bloc/tickets_bloc.dart';
import '../../tickets/bloc/tickets_state.dart';
import '../../tickets/bloc/tickets_event.dart';
import '../../../core/utils/department_utils.dart';
import '../../../data/models/ticket_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Try to load tickets if TicketsBloc is provided in the tree
    try {
      context.read<TicketsBloc>().add(const LoadTickets());
    } catch (_) {}
  }

  void _openTicketsList(BuildContext context) {
    context.push('/tickets');
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;

    return AppScaffold(
      title: const Text('Office A/S'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: _buildBody(context, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic user) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface = isDark ? scheme.surfaceContainerHighest : Colors.white;
    final accentSurface = isDark
        ? scheme.surfaceContainer
        : Colors.blue.shade50;
    final subduedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final showTickets = user != null && isItSupportDepartment(user);
    final showAbsenceApprovals = user != null && isLedelseDepartment(user);

    final welcomeCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business, size: 80, color: scheme.primary),
          const SizedBox(height: 24),
          Text(
            'Welcome to Office A/S!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (user != null) ...[
            Text(
              'Hello, ${user.name}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subduedText),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Successfully authenticated',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/calendar'),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Open calendar'),
              ),
            ],
          ),
        ],
      ),
    );

    // Quick action cards
    final actionCards = [
      () => _actionCard(
        context,
        Icons.calendar_today,
        'Shifts',
        'View your schedule',
        () => context.go('/calendar'),
      ),
      if (showAbsenceApprovals)
        () => _actionCard(
          context,
          Icons.fact_check_outlined,
          'Absences',
          'Approve absence requests',
          () => context.go('/absence/approvals'),
        ),
      () => _actionCard(
        context,
        Icons.confirmation_num_outlined,
        'Tickets',
        'Report an issue',
        () => _openTicketsList(context),
      ),
      () => _actionCard(
        context,
        Icons.feedback_outlined,
        'Feedback',
        'Give feedback',
        () => context.push('/feedback'),
      ),
      () => _actionCard(
        context,
        Icons.settings,
        'Settings',
        'App settings',
        () {},
      ),
    ];

    // Responsive dashboard layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;

        if (narrow) {
          // Mobile / narrow layout: stack content vertically with full-width action cards
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                welcomeCard,
                const SizedBox(height: 20),
                // quick actions as full-width stacked cards
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actionCards
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w(),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _previewPanel(
                  context,
                  'Upcoming shifts',
                  Icons.calendar_month,
                  _buildShiftsPreview(),
                ),
                const SizedBox(height: 12),
                _previewPanel(
                  context,
                  'Recent tickets',
                  Icons.confirmation_num,
                  _buildTicketsPreview(context),
                ),
                const SizedBox(height: 20),
                _buildTicketsSection(context, showTickets),
              ],
            ),
          );
        }

        // Wide layout: welcome, previews, then actions + tickets side-by-side
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome full-width
                  welcomeCard,
                  const SizedBox(height: 24),
                  // Previews row
                  Row(
                    children: [
                      Expanded(
                        child: _previewPanel(
                          context,
                          'Upcoming shifts',
                          Icons.calendar_month,
                          _buildShiftsPreview(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _previewPanel(
                          context,
                          'Recent tickets',
                          Icons.confirmation_num,
                          _buildTicketsPreview(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions (left) and recent tickets (right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // stacked full-width action cards
                                ...[
                                  () => _actionCard(
                                    context,
                                    Icons.calendar_today,
                                    'Shifts',
                                    'View your schedule',
                                    () => context.go('/calendar'),
                                    expand: true,
                                  ),
                                  if (showAbsenceApprovals)
                                    () => _actionCard(
                                      context,
                                      Icons.fact_check_outlined,
                                      'Absences',
                                      'Approve absence requests',
                                      () => context.go('/absence/approvals'),
                                      expand: true,
                                    ),
                                  () => _actionCard(
                                    context,
                                    Icons.confirmation_num_outlined,
                                    'Tickets',
                                    'Report an issue',
                                    () => _openTicketsList(context),
                                    expand: true,
                                  ),
                                  () => _actionCard(
                                    context,
                                    Icons.feedback_outlined,
                                    'Feedback',
                                    'Give feedback',
                                    () => context.push('/feedback'),
                                    expand: true,
                                  ),
                                ].map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: f(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 6,
                        child: BlocBuilder<TicketsBloc, TicketsState>(
                          builder: (context, state) {
                            List<TicketModel> tickets = [];
                            if (state is TicketsListLoaded) {
                              tickets = state.tickets;
                            }

                            final lastThree = tickets.take(6).toList();

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardSurface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.10,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Recent tickets',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                            ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.push('/tickets'),
                                        child: const Text('View all'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (lastThree.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        'No tickets yet. Create one from the tickets page.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: subduedText),
                                      ),
                                    )
                                  else
                                    ...lastThree.map(
                                      (ticket) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          ticket.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${_statusLabel(ticket.status)} · ${DateFormat('dd/MM/yyyy').format(ticket.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subduedText,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                        ),
                                        onTap: () => context.push(
                                          '/tickets/${ticket.id}',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _actionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool expand = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? scheme.surfaceContainerHighest : Colors.white;
    final iconSurface = isDark ? scheme.surfaceContainer : Colors.blue.shade50;
    final mutedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final bool narrow = screenWidth < 520;
        final double cardWidth = expand || narrow ? double.infinity : 260.0;
        return InkWell(
          onTap: onTap,
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: mutedText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewPanel(
    BuildContext context,
    String title,
    IconData icon,
    Widget child,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildShiftsPreview() {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;

    Widget placeholder() {
      return Column(
        children: const [
          ListTile(
            leading: Icon(Icons.access_time),
            title: Text('Morning shift'),
            subtitle: Text('Today • 08:00 - 12:00'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.access_time),
            title: Text('Evening shift'),
            subtitle: Text('Tomorrow • 16:00 - 20:00'),
          ),
        ],
      );
    }

    if (user == null) return placeholder();

    return FutureBuilder(
      future: getIt<ShiftRepository>().getShiftsByUserId(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final apiRes = snapshot.data;
        try {
          final shifts = apiRes?.dataOrNull;
          if (shifts == null || shifts.isEmpty) return placeholder();

          // sort by start time and pick active or next
          shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
          final now = DateTime.now();

          ShiftEntity? selected;
          // prefer active
          for (final s in shifts) {
            if (s.isActive) {
              selected = s;
              break;
            }
          }
          selected ??= shifts.firstWhere(
            (s) => s.startTime.isAfter(now),
            orElse: () => shifts.first,
          );

          final startDate = DateFormat(
            'EEE • dd/MM/yyyy',
          ).format(selected.startTime);
          final timeRange =
              '${DateFormat.Hm().format(selected.startTime)} - ${DateFormat.Hm().format(selected.endTime)}';

          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selected.isActive ? 'Current shift' : 'Next shift'),
                subtitle: Text('$startDate • $timeRange'),
              ),
            ],
          );
        } catch (_) {
          return placeholder();
        }
      },
    );
  }

  Widget _buildTicketsPreview(BuildContext context) {
    try {
      final bloc = context.read<TicketsBloc>();
      final state = bloc.state;
      final tickets = state is TicketsListLoaded
          ? state.tickets
          : bloc.cachedTickets;
      final preview = tickets.isNotEmpty ? tickets.take(2).toList() : null;
      if (preview != null) {
        return Column(
          children: [
            for (var t in preview) ...[
              ListTile(
                title: Text(t.title),
                subtitle: Text(
                  '${_statusLabel(t.status)} · ${DateFormat('dd/MM/yyyy').format(t.createdAt)}',
                ),
                onTap: () => context.push('/tickets/${t.id}'),
              ),
              const Divider(),
            ],
          ],
        );
      }

      // show static placeholders when there are no real tickets
      return Column(
        children: [
          ListTile(
            title: const Text('Printer not working'),
            subtitle: const Text('OPEN • created 2h ago'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Login issue'),
            subtitle: const Text('RESOLVED • yesterday'),
          ),
        ],
      );
    } catch (_) {
      // Fallback static preview when bloc isn't available
      return Column(
        children: [
          ListTile(
            title: const Text('Printer not working'),
            subtitle: const Text('OPEN • created 2h ago'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Login issue'),
            subtitle: const Text('RESOLVED • yesterday'),
          ),
        ],
      );
    }
  }

  Widget _buildTicketsSection(BuildContext context, bool showTickets) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface = isDark ? scheme.surfaceContainerHighest : Colors.white;
    final subduedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    try {
      // If TicketsBloc is not provided this will throw; we catch below
      context.read<TicketsBloc>();
    } catch (_) {
      // Fallback UI when bloc is absent
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent tickets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (showTickets) {
                      context.push('/tickets');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tickets are unavailable'),
                        ),
                      );
                    }
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tickets are unavailable in this context.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: subduedText),
              ),
            ),
          ],
        ),
      );
    }

    return BlocBuilder<TicketsBloc, TicketsState>(
      builder: (context, state) {
        List<TicketModel> tickets = [];
        if (state is TicketsListLoaded) tickets = state.tickets;

        final lastThree = tickets.take(6).toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent tickets',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/tickets'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (lastThree.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No tickets yet. Create one from the tickets page.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: subduedText),
                  ),
                )
              else
                ...lastThree.map(
                  (ticket) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      ticket.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${_statusLabel(ticket.status)} · ${DateFormat('dd/MM/yyyy').format(ticket.createdAt)}',
                      style: TextStyle(fontSize: 12, color: subduedText),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push('/tickets/${ticket.id}'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
