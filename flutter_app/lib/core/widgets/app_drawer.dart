import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/department_utils.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _goFromDrawer(BuildContext context, String path) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBackground = isDark
        ? scheme.surfaceContainerHigh
        : scheme.primary;
    final headerForeground = isDark ? scheme.onSurface : scheme.onPrimary;
    final appBarTitleStyle = Theme.of(
      context,
    ).appBarTheme.titleTextStyle?.copyWith(color: headerForeground);
    final user = context.read<AuthBloc>().currentUser;
    final showTickets = isItSupportDepartment(user);
    final showApprovals = canApproveAccounts(user);
    final showAbsenceApprovals = isLedelseDepartment(user);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 56,
            width: double.infinity,
            color: headerBackground,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Office A/S', style: appBarTitleStyle),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              _goFromDrawer(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Messages'),
            onTap: () {
              _goFromDrawer(context, '/messages');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendar'),
            onTap: () {
              _goFromDrawer(context, '/calendar');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            onTap: () {
              _goFromDrawer(context, '/notifications');
            },
          ),
          if (showTickets)
            ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: const Text('Tickets'),
              onTap: () {
                _goFromDrawer(context, '/tickets');
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create ticket'),
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.goNamed('ticketCreateStandalone');
            },
          ),
          if (showApprovals)
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Approve accounts'),
              onTap: () {
                _goFromDrawer(context, '/users/approvals');
              },
            ),
          if (showApprovals)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('User ratings'),
              onTap: () {
                _goFromDrawer(context, '/users/ratings');
              },
            ),
          if (showAbsenceApprovals)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Approve absences'),
              onTap: () {
                _goFromDrawer(context, '/absence/approvals');
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
