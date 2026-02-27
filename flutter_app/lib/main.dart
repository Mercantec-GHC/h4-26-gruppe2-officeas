import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart'
    if (dart.library.io) 'core/config/url_strategy_stub.dart'
    as url_strategy;
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'domain/repositories/shift_repository.dart';
import 'domain/repositories/absence_request_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/pending_approval_page.dart';
import 'features/home/pages/home_page.dart';
import 'features/home/account.dart';
import 'features/calendar/pages/calendar_page.dart';
import 'features/notifications/pages/notifications_page.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/widgets/it_support_guard.dart';
import 'features/tickets/bloc/tickets_bloc.dart';
import 'features/messaging/bloc/messaging_bloc.dart';
import 'features/messaging/pages/conversations_page.dart';
import 'features/tickets/pages/ticket_list_page.dart';
import 'features/tickets/pages/create_ticket_page.dart';
import 'features/users/pages/user_approvals_page.dart';
import 'features/users/pages/user_ratings_overview_page.dart';
import 'core/utils/department_utils.dart';

/// Main entry point
///
/// Initialiserer app dependencies og configuration før app starter.
///
/// Setup steps:
/// 1. Initialisér app configuration (environment)
/// 2. Setup dependency injection
/// 3. Start app
void main() async {
  // Sikr at Flutter bindings er initialiseret
  WidgetsFlutterBinding.ensureInitialized();

  // Path-based URLs on web (e.g. /home instead of #/home)
  url_strategy.usePathUrlStrategy();

  // 1. Initialisér App Configuration
  // TODO: Skift til Environment.production når du deployer til produktion!
  await AppConfig.initialize(Environment.development);
  // await AppConfig.initialize(Environment.production);

  // Log hvilket environment vi kører i
  debugPrint('🚀 Starting app in ${AppConfig.instance.environment.name} mode');
  debugPrint('📡 API Base URL: ${AppConfig.instance.apiBaseUrl}');

  // 2. Setup Dependency Injection
  await setupDependencyInjection();
  debugPrint('✅ Dependency Injection setup complete');

  // 3. Start App
  runApp(const MyApp());
}

/// Tip: Skift environment nemt
///
/// For at skifte mellem localhost og deployed API, ændre bare Environment i main():
/// - Development (localhost): Environment.development
/// - Production (deployed): Environment.production
/// - Staging (hvis I har det): Environment.staging

/// Root app widget
///
/// Setup BLoC providers og MaterialApp.
/// BLoCs injiceres via DI container (getIt).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Auth BLoC - for authentication
        BlocProvider(
          create: (context) {
            final authBloc = AuthBloc();
            // Setup auth interceptor after AuthBloc is created
            setupAuthInterceptor(authBloc);
            return authBloc;
          },
        ),
        // Messaging BLoC - injected via DI
        BlocProvider(create: (context) => getIt<MessagingBloc>()),
        BlocProvider(create: (context) => getIt<TicketsBloc>()),
        BlocProvider(create: (context) => ThemeCubit()..loadTheme()),

        // TODO: Tilføj flere BLoCs her efterhånden:
        // BlocProvider(
        //   create: (context) => getIt<LoginBloc>(),
        // ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isAuthenticated = state is Authenticated;
          return BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp(
                key: ValueKey('$isAuthenticated-$themeMode'),
                title: 'OfficeAs',
                theme: appTheme,
                darkTheme: appDarkTheme,
                themeMode: themeMode,
                debugShowCheckedModeBanner: false,
                home: isAuthenticated
                    ? const MainNavigation(initialIndex: 0)
                    : const LoginPage(),
                initialRoute: isAuthenticated ? '/home' : null,
                routes: {
                  '/login': (context) => const LoginPage(),
                  '/pending-approval': (context) => const PendingApprovalPage(),
                  '/home': (context) => const MainNavigation(initialIndex: 0),
                  '/account': (context) => const AccountPage(),
                  '/messages': (context) =>
                      const MainNavigation(initialIndex: 1),
                  '/calendar': (context) =>
                      const MainNavigation(initialIndex: 2),
                  '/notifications': (context) =>
                      const MainNavigation(initialIndex: 3),
                  '/tickets': (context) =>
                      const ItSupportGuard(child: TicketListPage()),
                  '/tickets/new': (context) => const CreateTicketPage(),
                  '/users/approvals': (context) => const UserApprovalsPage(),
                  '/users/ratings': (context) =>
                      const _LedelseHrGuard(child: UserRatingsOverviewPage()),
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Wrapper that only allows Ledelse and HR to see the child; others are redirected to home.
class _LedelseHrGuard extends StatelessWidget {
  const _LedelseHrGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().currentUser;
    if (!canApproveAccounts(user)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  // Pages correspond to bottom navigation items: Home, Messages, Calendar, Notifications
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
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
    );
  }
}
