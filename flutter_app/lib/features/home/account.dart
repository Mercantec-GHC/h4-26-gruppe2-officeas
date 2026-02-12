import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/bloc/auth_bloc.dart';




class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: const Color(0xFF0A66FF),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A66FF), Color(0xFF4B7CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: const Color(0xFF0A66FF)),
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final authBloc = context.read<AuthBloc>();
                    final user = authBloc.currentUser;
                    return Column(
                      children: [
                        Text(user?.name ?? 'User Name', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(user?.email ?? 'user@example.com', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0A66FF)),
                    child: const Text('Edit profile'),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Department'),
                      subtitle: const Text('Sales'),
                      trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.work_outline),
                      title: const Text('Role'),
                      subtitle: const Text('Employee'),
                      trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
                    ),
                    const Divider(height: 0),
                    SwitchListTile(
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                      title: const Text('Notifications'),
                      secondary: const Icon(Icons.notifications_outlined),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change password'),
                      onTap: () {},
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Actual logout should be triggered by caller via bloc
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
