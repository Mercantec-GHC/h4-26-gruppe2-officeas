import 'package:get_it/get_it.dart';
import '../../data/datasources/messaging_remote_datasource.dart';
import '../../features/messaging/bloc/messaging_bloc.dart';
import '../api/api_client.dart';
import '../services/messaging_websocket_service.dart';

/// Dependency Injection Container
///
/// Central sted til at registrere og resolve dependencies.
/// Bruger get_it som service locator.
///
/// Benefits:
/// - Single source of truth for dependencies
/// - Easy testing (mock dependencies)
/// - Loose coupling mellem komponenter
/// - Nem at skifte implementations
///
/// Usage:
/// ```dart
/// // I main.dart:
/// await setupDependencyInjection();
///
/// // I kode:
/// final messagingBloc = getIt<MessagingBloc>();
/// ```
final getIt = GetIt.instance;

/// Setup alle dependencies
///
/// Registrerer dependencies i den rigtige rækkefølge:
/// 1. Core services (ApiClient)
/// 2. Data sources
/// 3. Repositories
/// 4. BLoCs
///
/// Kaldes fra main.dart før app starter.
Future<void> setupDependencyInjection() async {
  // ============================================================
  // Core - API Client
  // ============================================================
  // Singleton fordi vi kun vil have én API client instance
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());

  // ============================================================
  // Data Sources
  // ============================================================
  getIt.registerLazySingleton<MessagingRemoteDataSource>(
    () => MessagingRemoteDataSource(),
  );

  getIt.registerLazySingleton<MessagingWebSocketService>(
    () => MessagingWebSocketService(),
  );

  // ============================================================
  // BLoCs
  // ============================================================
  getIt.registerFactory<MessagingBloc>(
    () => MessagingBloc(
      dataSource: getIt<MessagingRemoteDataSource>(),
      wsService: getIt<MessagingWebSocketService>(),
    ),
  );
}

/// Reset dependency injection
///
/// Nyttigt til testing hvor du vil starte med clean slate.
/// Kan også bruges til at skifte mellem mock og real dependencies.
Future<void> resetDependencyInjection() async {
  await getIt.reset();
}

/// Setup mock dependencies til testing
///
/// Eksempel på hvordan I kan lave test setup:
/// ```dart
/// Future<void> setupMockDependencies() async {
///   await resetDependencyInjection();
///   // Register mocks here
/// }
/// ```
