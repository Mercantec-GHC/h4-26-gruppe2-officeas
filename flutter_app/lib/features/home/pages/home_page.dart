import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../calendar/pages/calendar_page.dart';
import '../account.dart';
import '../dummy_feedback.dart';
import '../dummy_tickets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OfficeAs'),
        backgroundColor: const Color(0xFF0A66FF),
        foregroundColor: Colors.white,
        actions: [
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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFEFF6FF), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)]),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 36, backgroundColor: Colors.blue.shade50, child: Text(user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user?.name ?? 'Guest', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                          ]),
                        ),
                        ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())), icon: const Icon(Icons.person), label: const Text('Profile'))
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _actionCard(context, Icons.calendar_today, 'Shifts', 'View your schedule', () => Navigator.of(context).pushNamed('/calendar')),
                      _actionCard(context, Icons.confirmation_num_outlined, 'Tickets', 'Report an issue', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DummyTicketsPage()))),
                      _actionCard(context, Icons.feedback_outlined, 'Feedback', 'Give feedback', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DummyFeedbackPage()))),
                      _actionCard(context, Icons.settings, 'Settings', 'App settings', () {}),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Preview panels (responsive)
                  LayoutBuilder(builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 700;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _previewPanel(context, 'Upcoming shifts', Icons.calendar_month, _buildShiftsPreview()),
                          const SizedBox(height: 12),
                          _previewPanel(context, 'Recent tickets', Icons.confirmation_num, _buildTicketsPreview()),
                        ],
                      );
                    }
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _previewPanel(context, 'Upcoming shifts', Icons.calendar_month, _buildShiftsPreview())),
                      const SizedBox(width: 12),
                      Expanded(child: _previewPanel(context, 'Recent tickets', Icons.confirmation_num, _buildTicketsPreview())),
                    ]);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final double cardWidth = screenWidth < 520 ? screenWidth - 48.0 : 260.0;
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
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    return Column(children: [
      ListTile(leading: const Icon(Icons.access_time), title: const Text('Morning shift'), subtitle: const Text('Today • 08:00 - 12:00')),
      const Divider(),
      ListTile(leading: const Icon(Icons.access_time), title: const Text('Evening shift'), subtitle: const Text('Tomorrow • 16:00 - 20:00')),
    ]);
  }

  Widget _buildTicketsPreview() {
    return Column(children: [
      ListTile(title: const Text('Printer not working'), subtitle: const Text('OPEN • created 2h ago')),
      const Divider(),
      ListTile(title: const Text('Login issue'), subtitle: const Text('RESOLVED • yesterday')),
    ]);
  }
}
