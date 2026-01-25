import '../../core/api/api_result.dart';
import '../entities/weather_entity.dart';

/// Weather Repository Interface (Domain Layer)
/// 
/// Definer kontrakten for weather data access.
/// BLoC afhænger kun af denne interface, ikke konkret implementation.
/// 
/// Benefits:
/// - Testability: Nem at mocke i unit tests
/// - Flexibility: Skift data source uden at ændre BLoC
/// - Dependency Inversion: High-level modules afhænger ikke af low-level modules
/// 
/// Usage i BLoC:
/// ```dart
/// class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
///   final WeatherRepository repository; // Interface, ikke implementation!
///   
///   WeatherBloc({required this.repository});
/// }
/// ```
abstract class WeatherRepository {
  /// Hent vejrudsigt
  /// 
  /// Returns ApiResult<List<WeatherEntity>> for type-safe error handling.
  /// 
  /// Success case: Liste af vejr data
  /// Failure case: ApiException med fejldetaljer
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast();

  /// Hent vejrudsigt for specifik dato (eksempel på udvidelse)
  /// 
  /// Dette er et eksempel på hvordan I nemt kan tilføje nye metoder
  /// til repository interfacet.
  Future<ApiResult<WeatherEntity>> getWeatherByDate(DateTime date);

  /// Refresh vejr data (kan være samme som getWeatherForecast)
  Future<ApiResult<List<WeatherEntity>>> refreshWeatherForecast();
}

