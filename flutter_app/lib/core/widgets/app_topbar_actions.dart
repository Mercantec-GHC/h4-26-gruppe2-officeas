import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import 'theme_toggle_button.dart';

class AppTopBarActions extends StatefulWidget {
  final bool showNotifications;
  final bool showAccount;
  final bool showLogout;

  const AppTopBarActions({
    super.key,
    this.showNotifications = true,
    this.showAccount = true,
    this.showLogout = true,
  });

  @override
  State<AppTopBarActions> createState() => _AppTopBarActionsState();
}

class _AppTopBarActionsState extends State<AppTopBarActions> {
  final NotificationsRemoteDataSource _notificationsDataSource =
      NotificationsRemoteDataSource();
  late Future<int> _unreadCountFuture;

  @override
  void initState() {
    super.initState();
    _unreadCountFuture = _notificationsDataSource.getUnreadCount();
  }

  void _refreshUnreadCount() {
    setState(() {
      _unreadCountFuture = _notificationsDataSource.getUnreadCount();
    });
  }

  Future<void> _openNotifications() async {
    context.go('/notifications');
    if (!mounted) return;
    _refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ThemeToggleButton(),
        if (widget.showNotifications)
          FutureBuilder<int>(
            future: _unreadCountFuture,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Notifikationer',
                    onPressed: _openNotifications,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        if (widget.showAccount)
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onPressed: () => context.go('/account'),
          ),
        if (widget.showLogout)
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
          ),
      ],
    );
  }
}
