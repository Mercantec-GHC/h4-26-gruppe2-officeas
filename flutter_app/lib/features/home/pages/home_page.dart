import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../data/datasources/notifications_remote_datasource.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../account.dart';
import '../dummy_feedback.dart';
import '../dummy_tickets.dart';
import '../../tickets/bloc/tickets_bloc.dart';
import '../../tickets/bloc/tickets_state.dart';
import '../../tickets/bloc/tickets_event.dart';
import '../../tickets/pages/ticket_detail_page.dart';
import '../../tickets/pages/ticket_list_page.dart';
import '../../../core/utils/department_utils.dart';
import '../../../data/models/ticket_model.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NotificationsRemoteDataSource _notificationsDataSource = NotificationsRemoteDataSource();
  late Future<int> _unreadCountFuture;

  @override
  void initState() {
    super.initState();
    // Try to load tickets if TicketsBloc is provided in the tree
    try {
      context.read<TicketsBloc>().add(const LoadTickets());
    } catch (_) {}
    _unreadCountFuture = _notificationsDataSource.getUnreadCount();
  }

  void _openTicketsList(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const TicketListPage()));
  }

  void _openTicketDetailOrList(BuildContext context, bool showTickets) {
    try {
      final bloc = context.read<TicketsBloc>();
      final state = bloc.state;
      if (state is TicketsListLoaded && state.tickets.isNotEmpty) {
        final first = state.tickets.first;
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => TicketDetailPage(ticketId: first.id)));
        return;
      }
    } catch (_) {
      // ignore - fallback to list page
    }

    // fallback: open ticket list (or TicketDetail is not possible)
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const TicketListPage()));
  }

  void _refreshUnreadCount() {
    setState(() {
      _unreadCountFuture = _notificationsDataSource.getUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('OfficeAs'),
        backgroundColor: const Color(0xFF0A66FF),
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<int>(
            future: _unreadCountFuture,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Notifikationer',
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/notifications');
                      _refreshUnreadCount();
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => authBloc.add(LogoutRequested()),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blue.shade50, Colors.white])),
        child: _buildBody(context, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic user) {
    final showTickets = user != null && isItSupportDepartment(user);

    final welcomeCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.business, size: 80, color: Colors.blue.shade700),
        const SizedBox(height: 24),
        Text('Welcome to OfficeAs!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
        const SizedBox(height: 16),
        if (user != null) ...[
          Text('Hello, ${user.name}!', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text('Successfully authenticated', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/calendar'),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Åbn kalender'),
          ),
        ]),
      ]),
    );

    final moreFeaturesText = Padding(padding: const EdgeInsets.only(top: 24), child: Text('More features coming soon...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic)));

    // Quick action cards
    final actionCards = [
      () => _actionCard(context, Icons.calendar_today, 'Shifts', 'View your schedule', () => Navigator.of(context).pushNamed('/calendar')),
      () => _actionCard(context, Icons.confirmation_num_outlined, 'Tickets', 'Report an issue', () => _openTicketsList(context)),
      () => _actionCard(context, Icons.feedback_outlined, 'Feedback', 'Give feedback', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DummyFeedbackPage()))),
      () => _actionCard(context, Icons.settings, 'Settings', 'App settings', () {}),
    ];

    // Responsive dashboard layout
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 900;

      if (narrow) {
        // Mobile / narrow layout: stack content vertically with full-width action cards
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            welcomeCard,
            const SizedBox(height: 20),
            // quick actions as full-width stacked cards
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actionCards.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w())).toList()),
            const SizedBox(height: 20),
            _previewPanel(context, 'Upcoming shifts', Icons.calendar_month, _buildShiftsPreview()),
            const SizedBox(height: 12),
            _previewPanel(context, 'Recent tickets', Icons.confirmation_num, _buildTicketsPreview(context)),
            const SizedBox(height: 20),
            _buildTicketsSection(context, showTickets),
            const SizedBox(height: 24),
            moreFeaturesText,
          ]),
        );
      }

      // Wide layout: welcome, previews, then actions + tickets side-by-side
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Welcome full-width
              welcomeCard,
              const SizedBox(height: 24),
              // Previews row
              Row(children: [Expanded(child: _previewPanel(context, 'Upcoming shifts', Icons.calendar_month, _buildShiftsPreview())), const SizedBox(width: 12), Expanded(child: _previewPanel(context, 'Recent tickets', Icons.confirmation_num, _buildTicketsPreview(context)))]),
              const SizedBox(height: 24),
              // Actions (left) and recent tickets (right)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 4,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // stacked full-width action cards
                        ...[
                          () => _actionCard(context, Icons.calendar_today, 'Shifts', 'View your schedule', () => Navigator.of(context).pushNamed('/calendar'), expand: true),
                          () => _actionCard(context, Icons.confirmation_num_outlined, 'Tickets', 'Report an issue', () => _openTicketsList(context), expand: true),
                          () => _actionCard(context, Icons.feedback_outlined, 'Feedback', 'Give feedback', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DummyFeedbackPage())), expand: true),
                          () => _actionCard(context, Icons.settings, 'Settings', 'App settings', () {}, expand: true),
                        ].map((f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: f())).toList(),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: BlocBuilder<TicketsBloc, TicketsState>(builder: (context, state) {
                    List<TicketModel> tickets = [];
                    if (state is TicketsListLoaded) tickets = state.tickets;

                    final lastThree = tickets.take(6).toList();

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Seneste tickets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const TicketListPage())), child: const Text('Se alle')),
                        ]),
                        const SizedBox(height: 8),
                        if (lastThree.isEmpty)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Ingen tickets endnu. Opret en fra ticket-siden.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)))
                        else
                          ...lastThree.map((ticket) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('${_statusLabel(ticket.status)} · ${DateFormat('dd/MM/yyyy').format(ticket.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                trailing: const Icon(Icons.chevron_right, size: 20),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => TicketDetailPage(ticketId: ticket.id))),
                              ))
                      ]),
                    );
                  }),
                ),
              ]),
            ]),
          ),
        ),
      );
    });
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

  Widget _actionCard(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {bool expand = false}) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final bool narrow = screenWidth < 520;
      final double cardWidth = expand || narrow ? double.infinity : 260.0;
      return InkWell(
        onTap: onTap,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.blue.shade700)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)])),
          ]),
        ),
      );
    });
  }

  Widget _previewPanel(BuildContext context, String title, IconData icon, Widget child) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.blue.shade700), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]), const SizedBox(height: 12), child])));
  }

  Widget _buildShiftsPreview() {
    return Column(children: [ListTile(leading: const Icon(Icons.access_time), title: const Text('Morning shift'), subtitle: const Text('Today • 08:00 - 12:00')), const Divider(), ListTile(leading: const Icon(Icons.access_time), title: const Text('Evening shift'), subtitle: const Text('Tomorrow • 16:00 - 20:00'))]);
  }

  Widget _buildTicketsPreview(BuildContext context) {
    try {
      final bloc = context.read<TicketsBloc>();
      final state = bloc.state;
      final tickets = state is TicketsListLoaded ? state.tickets : bloc.cachedTickets;
      final preview = tickets.isNotEmpty ? tickets.take(2).toList() : null;
      if (preview != null) {
        return Column(children: [
          for (var t in preview) ...[
            ListTile(
              title: Text(t.title),
              subtitle: Text('${_statusLabel(t.status)} · ${DateFormat('dd/MM/yyyy').format(t.createdAt)}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: t.id))),
            ),
            const Divider(),
          ],
        ]);
      }

      // show static placeholders when there are no real tickets
      return Column(children: [ListTile(title: const Text('Printer not working'), subtitle: const Text('OPEN • created 2h ago')), const Divider(), ListTile(title: const Text('Login issue'), subtitle: const Text('RESOLVED • yesterday'))]);
    } catch (_) {
      // Fallback static preview when bloc isn't available
      return Column(children: [ListTile(title: const Text('Printer not working'), subtitle: const Text('OPEN • created 2h ago')), const Divider(), ListTile(title: const Text('Login issue'), subtitle: const Text('RESOLVED • yesterday'))]);
    }
  }

  Widget _buildTicketsSection(BuildContext context, bool showTickets) {
    try {
      // If TicketsBloc is not provided this will throw; we catch below
      context.read<TicketsBloc>();
    } catch (_) {
      // Fallback UI when bloc is absent
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Seneste tickets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => showTickets ? const TicketListPage() : const DummyTicketsPage())), child: const Text('Se alle')),
          ]),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Tickets are unavailable in this context.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600))),
        ]),
      );
    }

    return BlocBuilder<TicketsBloc, TicketsState>(builder: (context, state) {
      List<TicketModel> tickets = [];
      if (state is TicketsListLoaded) tickets = state.tickets;

      final lastThree = tickets.take(6).toList();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Seneste tickets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const TicketListPage())), child: const Text('Se alle')),
          ]),
          const SizedBox(height: 8),
          if (lastThree.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Ingen tickets endnu. Opret en fra ticket-siden.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)))
          else
            ...lastThree.map((ticket) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${_statusLabel(ticket.status)} · ${DateFormat('dd/MM/yyyy').format(ticket.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => TicketDetailPage(ticketId: ticket.id))),
                ))
        ]),
      );
    });
  }
}
