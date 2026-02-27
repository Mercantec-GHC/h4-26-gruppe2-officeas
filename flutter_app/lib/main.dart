import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart'
    if (dart.library.io) 'core/config/url_strategy_stub.dart'
    as url_strategy;
import 'package:go_router/go_router.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/pending_approval_page.dart';
import 'features/tickets/bloc/tickets_bloc.dart';
import 'features/messaging/bloc/messaging_bloc.dart';

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

/// Root app widget: BLoC providers, auth-notifier for router, MaterialApp.router.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<bool> _authNotifier = ValueNotifier(false);
  late final GoRouter _router = createAppRouter(_authNotifier);

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

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
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          final isAuthenticated = state is Authenticated;
          if (_authNotifier.value != isAuthenticated) {
            _authNotifier.value = isAuthenticated;
            if (isAuthenticated) context.go('/');
          }
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'OfficeAs',
              theme: appTheme,
              darkTheme: appDarkTheme,
              themeMode: themeMode,
              debugShowCheckedModeBanner: false,
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
