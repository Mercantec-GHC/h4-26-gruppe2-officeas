import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'domain/repositories/shift_repository.dart';
import 'features/messaging/bloc/messaging_bloc.dart';
import 'features/messaging/pages/conversations_page.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/pages/login_page.dart';
import 'features/home/pages/home_page.dart';
import 'features/calendar/pages/calendar_page.dart';
import 'features/notifications/pages/notifications_page.dart';
import 'core/theme/theme.dart';

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
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'OfficeAs',
            theme: appTheme,
            debugShowCheckedModeBanner: false,
            home: state is Authenticated
                ? const MainNavigation()
                : const LoginPage(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/home': (context) => const HomePage(),
              '/navigation': (context) => const MainNavigation(),
              '/calendar': (context) =>
                  CalendarPage(shiftRepository: getIt<ShiftRepository>()),
              '/notifications': (context) => const NotificationsPage(),
            },
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const ConversationsPage(),
    CalendarPage(shiftRepository: getIt<ShiftRepository>()),
    const NotificationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Hjem'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Beskeder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Kalender',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notifikationer',
          ),
        ],
      ),
    );
  }
}
