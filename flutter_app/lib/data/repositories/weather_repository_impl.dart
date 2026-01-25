import '../../core/api/api_result.dart';
import '../../domain/entities/weather_entity.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_remote_datasource.dart';

/// Weather Repository Implementation (Data Layer)
/// 
/// Konkret implementation af WeatherRepository interface.
/// Koordinerer data sources og konverterer models til entities.
/// 
/// Architecture flow:
/// BLoC → Repository Interface → Repository Impl → DataSource → API Client → API
/// 
/// Responsibilities:
/// - Kalder data sources (remote/local)
/// - Konverterer models til entities
/// - Håndterer caching logik (hvis relevant)
/// - Kombinerer data fra multiple sources (hvis relevant)
class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource remoteDataSource;

  WeatherRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<ApiResult<List<WeatherEntity>>> getWeatherForecast() async {
    // Hent data fra remote data source
    final result = await remoteDataSource.getWeatherForecast();

    // Transform models til entities
    return result.map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }

  @override
  Future<ApiResult<WeatherEntity>> getWeatherByDate(DateTime date) async {
    // Først hent alle, derefter filter
    // I en rigtig app ville dette være et separat API endpoint
    final result = await getWeatherForecast();

    return result.map((weatherList) {
      // Find vejr for specifik dato
      final weather = weatherList.firstWhere(
        (w) => w.date.year == date.year &&
            w.date.month == date.month &&
            w.date.day == date.day,
        orElse: () => throw Exception('Ingen vejrdata for dato: $date'),
      );
      return weather;
    });
  }

  @override
  Future<ApiResult<List<WeatherEntity>>> refreshWeatherForecast() async {
    // I denne simple implementation er refresh det samme som get
    // Men kunne implementere force refresh logic her
    return getWeatherForecast();
  }

  /// Eksempel på caching implementation (optional)
  /// 
  /// Sådan kunne I tilføje caching:
  /// ```dart
  /// final WeatherLocalDataSource? localDataSource;
  /// 
  /// Future<ApiResult<List<WeatherEntity>>> getWeatherForecast() async {
  ///   // 1. Prøv at hente fra cache først
  ///   final cachedResult = await localDataSource?.getCachedWeather();
  ///   if (cachedResult != null && !cachedResult.isExpired) {
  ///     return ApiResult.success(cachedResult);
  ///   }
  ///   
  ///   // 2. Hvis ikke i cache, hent fra API
  ///   final result = await remoteDataSource.getWeatherForecast();
  ///   
  ///   // 3. Gem i cache for næste gang
  ///   result.when(
  ///     success: (data) => localDataSource?.cacheWeather(data),
  ///     failure: (_) => null,
  ///   );
  ///   
  ///   return result.map((models) => 
  ///     models.map((model) => model.toEntity()).toList()
  ///   );
  /// }
  /// ```
}

