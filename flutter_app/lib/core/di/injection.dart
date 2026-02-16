import 'package:get_it/get_it.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../features/tickets/bloc/tickets_bloc.dart';
import '../../features/messaging/bloc/messaging_bloc.dart';
import '../../data/datasources/shift_remote_datasource.dart';
import '../../data/datasources/absence_request_remote_datasource.dart';
import '../../data/datasources/messaging_remote_datasource.dart';
import '../../core/services/messaging_websocket_service.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../data/repositories/absence_request_repository_impl.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/repositories/absence_request_repository.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../api/api_client.dart';

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
/// final weatherBloc = getIt<WeatherBloc>();
/// final repository = getIt<WeatherRepository>();
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
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // ============================================================
  // Data Sources
  // ============================================================
  // Remote data sources
  getIt.registerLazySingleton<ShiftRemoteDataSource>(
    () => ShiftRemoteDataSource(
      apiClient: getIt<ApiClient>(),
    ),
  );

  getIt.registerLazySingleton<AbsenceRequestRemoteDataSource>(
    () => AbsenceRequestRemoteDataSource(
      apiClient: getIt<ApiClient>(),
    ),
  );

  // messaging data source + websocket service
  getIt.registerLazySingleton<MessagingRemoteDataSource>(
    () => MessagingRemoteDataSource(),
  );
  getIt.registerLazySingleton<MessagingWebSocketService>(
    () => MessagingWebSocketService(),
  );

  // TODO: Tilføj local data source her når I implementerer caching
  // getIt.registerLazySingleton<WeatherLocalDataSource>(
  //   () => WeatherLocalDataSourceImpl(),
  // );

  // ============================================================
  // Repositories
  // ============================================================
  // Registrer som interface type
  // så de kun afhænger af interface, ikke implementation
  getIt.registerLazySingleton<ShiftRepository>(
    () => ShiftRepositoryImpl(
      remoteDataSource: getIt<ShiftRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<AbsenceRequestRepository>(
    () => AbsenceRequestRepositoryImpl(
      remoteDataSource: getIt<AbsenceRequestRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<TicketRepository>(() => TicketRepository());
  // TODO: Tilføj flere repositories her efterhånden:
  // getIt.registerLazySingleton<UserRepository>(
  //   () => UserRepositoryImpl(
  //     remoteDataSource: getIt<UserRemoteDataSource>(),
  //   ),
  // );

  // ============================================================
  // BLoCs
  // ============================================================
  // Factory fordi vi vil have ny instance hver gang
  // (BLoCs skal ikke deles mellem widgets)
  getIt.registerFactory<MessagingBloc>(
    () => MessagingBloc(
      dataSource: getIt<MessagingRemoteDataSource>(),
      wsService: getIt<MessagingWebSocketService>(),
    ),
  );

  getIt.registerFactory<TicketsBloc>(
    () => TicketsBloc(repository: getIt<TicketRepository>()),
  );
  // TODO: Tilføj flere BLoCs her efterhånden:
  // getIt.registerFactory<LoginBloc>(
  //   () => LoginBloc(
  //     authRepository: getIt<AuthRepository>(),
  //   ),
  // );
}

/// Setup auth interceptor with AuthBloc
/// 
/// Called from main.dart after AuthBloc is created to inject
/// the current token provider.
void setupAuthInterceptor(AuthBloc authBloc) {
  getIt<ApiClient>().addAuthInterceptor(
    () async => authBloc.currentToken,
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
///   
///   // Register mocks
///   getIt.registerLazySingleton<WeatherRepository>(
///     () => MockWeatherRepository(),
///   );
///   
///   getIt.registerFactory<WeatherBloc>(
///     () => WeatherBloc(repository: getIt<WeatherRepository>()),
///   );
/// }
/// ```

