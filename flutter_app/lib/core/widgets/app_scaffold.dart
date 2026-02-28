import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'app_topbar_actions.dart';

/// Shared scaffold for app views: drawer (sidebar), app bar with title and
/// standard actions (theme, notifications, account, logout), plus optional
/// extra actions. Use this so all views share the same top bar and navigation.
class AppScaffold extends StatefulWidget {
  final Widget title;
  final Widget body;
  final bool showDrawer;
  final bool showAccount;
  final bool showNotifications;
  final bool showLogout;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showDrawer = true,
    this.showAccount = true,
    this.showNotifications = true,
    this.showLogout = true,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appBarBackground = isDark ? scheme.surface : scheme.primary;
    final appBarForeground = isDark ? scheme.onSurface : scheme.onPrimary;

    final barActions = <Widget>[
      if (widget.actions != null) ...widget.actions!,
      AppTopBarActions(
        showAccount: widget.showAccount,
        showNotifications: widget.showNotifications,
        showLogout: widget.showLogout,
      ),
    ];
    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.showDrawer ? const AppDrawer() : null,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        leading: widget.showDrawer
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Open menu',
              )
            : null,
        title: widget.title,
        actions: barActions,
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }
}
