import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/pending_approval_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/home/account.dart';
import '../../features/home/feedback_page.dart';
import '../../features/calendar/pages/calendar_page.dart';
import '../../features/calendar/pages/absence_approvals_page.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/messaging/pages/conversations_page.dart';
import '../../features/messaging/pages/new_conversation_page.dart';
import '../../features/messaging/pages/chat_page.dart';
import '../../features/tickets/pages/ticket_list_page.dart';
import '../../features/tickets/pages/create_ticket_page.dart';
import '../../features/tickets/pages/ticket_detail_page.dart';
import '../../features/users/pages/user_approvals_page.dart';
import '../../features/users/pages/user_ratings_overview_page.dart';
import '../../data/models/messaging_models.dart';
import '../di/injection.dart';
import '../utils/department_utils.dart';
import '../widgets/it_support_guard.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/repositories/absence_request_repository.dart';
import '../../features/auth/bloc/auth_bloc.dart';

/// Paths that do not require authentication.
const _publicPaths = ['/login', '/pending-approval'];

/// All valid route paths (exact or prefix). Unknown paths redirect to /login.
bool _isValidPath(String path) {
  if (path.isEmpty || path == '/') return true;
  if (_publicPaths.contains(path)) return true;
  const allowed = [
    '/account',
    '/feedback',
    '/create-ticket',
    '/messages',
    '/calendar',
    '/notifications',
    '/tickets',
    '/absence/approvals',
    '/users/approvals',
    '/users/ratings',
  ];
  if (allowed.contains(path)) return true;
  if (path.startsWith('/messages/')) return true;
  if (path.startsWith('/tickets/')) return true;
  return false;
}

/// Builds the app [GoRouter] with auth-aware redirects.
/// [authNotifier] should be updated whenever auth state changes so redirects run.
GoRouter createAppRouter(ValueNotifier<bool> authNotifier) {
  return GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthenticated = authNotifier.value;

      // /home → /
      if (path == '/home') return '/';

      // Unknown path → /login (404 behaviour)
      if (!_isValidPath(path)) return '/login';

      // Protected route while unauthenticated → /login
      if (!isAuthenticated && !_publicPaths.contains(path)) {
        return '/login';
      }

      // Public auth pages while authenticated → /
      if (isAuthenticated && _publicPaths.contains(path)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/pending-approval',
        builder: (_, state) => PendingApprovalPage(
          message:
              state.extra as String? ??
              'Your account is pending HR/Ledelse approval. You can sign in once approved.',
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const _MainNavShell(initialIndex: 0),
      ),
      GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
      GoRoute(path: '/feedback', builder: (_, __) => const FeedbackPage()),
      GoRoute(
        path: '/create-ticket',
        name: 'ticketCreateStandalone',
        builder: (_, __) => const CreateTicketPage(),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, __) => const _MainNavShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/messages/new',
        builder: (_, __) => const NewConversationPage(),
      ),
      GoRoute(
        path: '/messages/chat/:conversationId',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is ConversationModel) {
            return ChatPage(conversation: extra);
          }
          return const _MainNavShell(initialIndex: 1);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const _MainNavShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const _MainNavShell(initialIndex: 3),
      ),
      GoRoute(
        path: '/tickets/new',
        name: 'ticketCreate',
        redirect: (_, __) => '/create-ticket',
      ),
      GoRoute(
        path: '/tickets/:ticketId',
        builder: (_, state) {
          final ticketId = state.pathParameters['ticketId'];
          if (ticketId == null || ticketId.isEmpty) {
            return const ItSupportGuard(child: TicketListPage());
          }
          if (ticketId == 'new') {
            return const SizedBox.shrink();
          }
          return ItSupportGuard(child: TicketDetailPage(ticketId: ticketId));
        },
      ),
      GoRoute(
        path: '/tickets',
        builder: (_, __) => const ItSupportGuard(child: TicketListPage()),
      ),
      GoRoute(
        path: '/users/approvals',
        builder: (_, __) => const UserApprovalsPage(),
      ),
      GoRoute(
        path: '/users/ratings',
        builder: (_, __) =>
            const _LedelseHrGuard(child: UserRatingsOverviewPage()),
      ),
      GoRoute(
        path: '/absence/approvals',
        builder: (_, __) => _LedelseGuard(
          child: AbsenceApprovalsPage(
            absenceRequestRepository: getIt<AbsenceRequestRepository>(),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => const LoginPage(),
  );
}

/// Shell that shows main bottom-nav pages (Home, Messages, Calendar, Notifications).
class _MainNavShell extends StatelessWidget {
  const _MainNavShell({required this.initialIndex});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return _MainNavigation(initialIndex: initialIndex);
  }
}

class _MainNavigation extends StatefulWidget {
  const _MainNavigation({this.initialIndex = 0});

  final int initialIndex;

  @override
  State<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<_MainNavigation> {
  late int _selectedIndex;

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const ConversationsPage(),
    CalendarPage(
      shiftRepository: getIt<ShiftRepository>(),
      absenceRequestRepository: getIt<AbsenceRequestRepository>(),
    ),
    const NotificationsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(_MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _pages[_selectedIndex]);
  }
}

class _LedelseHrGuard extends StatelessWidget {
  const _LedelseHrGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().currentUser;
    if (!canApproveAccounts(user)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}

class _LedelseGuard extends StatelessWidget {
  const _LedelseGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().currentUser;
    if (!isLedelseDepartment(user)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}
