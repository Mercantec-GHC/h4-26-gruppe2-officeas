import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/department_utils.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().currentUser;
    final showTickets = isItSupportDepartment(user);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            child: Text(
              'Office A/S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Forside'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
          ),
          if (showTickets)
            ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: const Text('Tickets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/tickets');
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Opret ticket'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/tickets/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Skema'),
            subtitle: const Text('Kommer snart'),
            enabled: false,
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log ud'),
            onTap: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
    );
  }
}
