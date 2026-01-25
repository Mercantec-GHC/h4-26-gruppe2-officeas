import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../models/weather_model.dart';

/// Weather Remote Data Source
/// 
/// Ansvarlig for at hente data fra remote API.
/// Wrapper omkring ApiClient med weather-specifik logik.
/// 
/// Separation of Concerns:
/// - DataSource: Rå API kald (HTTP requests)
/// - Repository: Business logic og data transformation
/// 
/// Dette gør det nemt at:
/// - Tilføje caching (local data source)
/// - Skifte API implementation
/// - Teste repository isoleret
abstract class WeatherRemoteDataSource {
  /// Hent vejrudsigt fra API
  Future<ApiResult<List<WeatherModel>>> getWeatherForecast();
}

/// Implementation af Weather Remote Data Source
class WeatherRemoteDataSourceImpl implements WeatherRemoteDataSource {
  final ApiClient apiClient;

  WeatherRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<ApiResult<List<WeatherModel>>> getWeatherForecast() async {
    // Lav API kald via ApiClient
    final result = await apiClient.get<List<WeatherModel>>(
      '/WeatherForecast',
      fromJson: (json) {
        // Parse JSON array til List<WeatherModel>
        if (json is List) {
          return json
              .map((item) => WeatherModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        throw FormatException('Expected JSON array, got ${json.runtimeType}');
      },
    );

    return result;
  }

  /// Eksempel på anden API metode
  /// 
  /// Sådan kan I nemt tilføje flere endpoints:
  /// ```dart
  /// Future<ApiResult<WeatherModel>> getWeatherById(String id) async {
  ///   return await apiClient.get<WeatherModel>(
  ///     '/WeatherForecast/$id',
  ///     fromJson: (json) => WeatherModel.fromJson(json),
  ///   );
  /// }
  /// ```
}

