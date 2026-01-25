import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/weather_repository.dart';
import '../model/chart_data.dart';
import 'weather_event.dart';
import 'weather_state.dart';

/// Weather BLoC (Presentation Layer)
/// 
/// Håndterer vejr-relateret business logic og state management.
/// Følger BLoC pattern med Clean Architecture principper.
/// 
/// Architecture:
/// UI → BLoC → Repository (Interface) → Repository Impl → DataSource → API
/// 
/// BLoC'en afhænger kun af repository interface, ikke concrete implementation.
/// Dette gør den testbar og uafhængig af data source detaljer.
/// 
/// Event Flow:
/// 1. UI trigger event (LoadWeatherData)
/// 2. BLoC kalder repository metode
/// 3. Repository returnerer ApiResult<T>
/// 4. BLoC mapper result til state
/// 5. UI reagerer på ny state
/// 
/// Usage:
/// ```dart
/// // Inject via DI:
/// final weatherBloc = getIt<WeatherBloc>();
/// 
/// // Eller direkte:
/// final weatherBloc = WeatherBloc(
///   repository: getIt<WeatherRepository>(),
/// );
/// 
/// // Trigger event:
/// weatherBloc.add(const LoadWeatherData());
/// ```
class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherRepository _repository;

  WeatherBloc({
    required WeatherRepository repository,
  })  : _repository = repository,
        super(const WeatherInitial()) {
    // Registrer event handlers
    on<LoadWeatherData>(_onLoadWeatherData);
    on<RefreshWeatherData>(_onRefreshWeatherData);
  }

  /// Handler for LoadWeatherData event
  /// 
  /// Henter vejrdata fra repository og emitter states baseret på result.
  /// Bruger ApiResult<T> for type-safe error handling - ingen try/catch nødvendigt!
  Future<void> _onLoadWeatherData(
    LoadWeatherData event,
    Emitter<WeatherState> emit,
  ) async {
    // Emit loading state
    emit(const WeatherLoading());

    // Hent data fra repository
    final result = await _repository.getWeatherForecast();

    // Pattern match på result og emit relevant state
    result.when(
      success: (weatherEntities) {
        // Success: Konverter entities til chart data og emit loaded state
        final chartData = ChartData.fromWeatherEntities(weatherEntities);
        
        emit(WeatherLoaded(
          weatherData: weatherEntities,
          chartData: chartData,
        ));
      },
      failure: (exception) {
        // Failure: Emit error state med brugervenlig besked
        emit(WeatherError(exception.userMessage));
      },
    );
  }

  /// Handler for RefreshWeatherData event
  /// 
  /// Refresh data fra API (kan senere implementere pull-to-refresh).
  /// I denne implementation er det samme som LoadWeatherData.
  Future<void> _onRefreshWeatherData(
    RefreshWeatherData event,
    Emitter<WeatherState> emit,
  ) async {
    // Emit loading state
    emit(const WeatherLoading());

    // Kald refresh metode (kunne være forskellig fra get)
    final result = await _repository.refreshWeatherForecast();

    // Pattern match på result
    result.when(
      success: (weatherEntities) {
        final chartData = ChartData.fromWeatherEntities(weatherEntities);
        
        emit(WeatherLoaded(
          weatherData: weatherEntities,
          chartData: chartData,
        ));
      },
      failure: (exception) {
        emit(WeatherError(exception.userMessage));
      },
    );
  }
}

