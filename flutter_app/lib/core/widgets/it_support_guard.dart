import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/department_utils.dart';
import '../../features/auth/bloc/auth_bloc.dart';

/// Wraps a widget and redirects to home if the current user is not allowed
/// to access ticket pages.
/// Allowed departments: IT-Support, Ledelse, and HR.
class ItSupportGuard extends StatefulWidget {
  final Widget child;

  const ItSupportGuard({super.key, required this.child});

  @override
  State<ItSupportGuard> createState() => _ItSupportGuardState();
}

class _ItSupportGuardState extends State<ItSupportGuard> {
  bool _hasTicketAccess() {
    final user = context.read<AuthBloc>().currentUser;
    return isItSupportDepartment(user) ||
        isLedelseDepartment(user) ||
        isHrDepartment(user);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRedirect());
  }

  void _checkAndRedirect() {
    if (!mounted) return;

    if (!_hasTicketAccess()) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasTicketAccess()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}
