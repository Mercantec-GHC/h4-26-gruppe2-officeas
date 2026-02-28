import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/department_utils.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBackground = isDark
        ? scheme.surfaceContainerHigh
        : scheme.primary;
    final headerForeground = isDark ? scheme.onSurface : scheme.onPrimary;
    final user = context.read<AuthBloc>().currentUser;
    final showTickets = isItSupportDepartment(user);
    final showApprovals = canApproveAccounts(user);
    final showAbsenceApprovals = isLedelseDepartment(user);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: headerBackground),
            child: Text(
              'Office A/S',
              style: TextStyle(
                color: headerForeground,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Messages'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.go('/messages');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.go('/calendar');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.go('/notifications');
            },
          ),
          if (showTickets)
            ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: const Text('Tickets'),
              onTap: () {
                Navigator.pop(context);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                context.go('/tickets');
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create ticket'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.go('/tickets/new');
            },
          ),
          if (showApprovals)
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Approve accounts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
                context.go('/users/approvals');
              },
            ),
          if (showApprovals)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('User ratings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
                context.go('/users/ratings');
              },
            ),
          if (showAbsenceApprovals)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Approve absences'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
                context.go('/absence/approvals');
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () {
              final authBloc = context.read<AuthBloc>();
              Navigator.pop(context);
              authBloc.add(LogoutRequested());
            },
          ),
        ],
      ),
    );
  }
}
