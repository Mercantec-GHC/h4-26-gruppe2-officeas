import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'api_interceptor.dart';
import 'api_result.dart';

/// Central API Client
/// 
/// Single source of truth for alle HTTP requests.
/// Håndterer base configuration, interceptors, og error mapping.
/// 
/// Features:
/// - Automatic logging (kun i development)
/// - Error handling og mapping til ApiException
/// - Timeout configuration
/// - Retry logic for failed requests
/// - Type-safe responses med ApiResult<T>
/// 
/// Usage:
/// ```dart
/// final apiClient = ApiClient();
/// final result = await apiClient.get<List<User>>(
///   '/users',
///   fromJson: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
/// );
/// ```
class ApiClient {
  late final Dio _dio;

  ApiClient({
    Dio? dio,
    List<Interceptor>? additionalInterceptors,
  }) {
    _dio = dio ?? _createDio(additionalInterceptors);
  }

  /// Factory til at lave pre-configured Dio instance
  Dio _createDio(List<Interceptor>? additionalInterceptors) {
    final config = AppConfig.instance;
    
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: Duration(milliseconds: config.apiTimeout),
        receiveTimeout: Duration(milliseconds: config.apiTimeout),
        sendTimeout: Duration(milliseconds: config.apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) {
          // Accept alle status codes - vi håndterer dem manuelt
          return status != null && status < 500;
        },
      ),
    );

    // Tilføj interceptors
    dio.interceptors.addAll([
      // Logging (kun i development)
      if (config.enableApiLogging) LoggingInterceptor(),
      
      // Retry logic
      RetryInterceptor(maxRetries: 2),
      
      // Custom interceptors
      if (additionalInterceptors != null) ...additionalInterceptors,
    ]);

    return dio;
  }

  /// GET request
  /// 
  /// Generic GET request med type-safe response parsing.
  /// 
  /// Example:
  /// ```dart
  /// final result = await apiClient.get<List<Weather>>(
  ///   '/weather',
  ///   fromJson: (json) => (json as List)
  ///       .map((e) => Weather.fromJson(e))
  ///       .toList(),
  /// );
  /// ```
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );

      // Check for success status
      if (_isSuccessStatusCode(response.statusCode)) {
        final data = fromJson(response.data);
        return ApiResult.success(data);
      } else {
        return ApiResult.failure(_mapError(response));
      }
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioException(e));
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown('Uventet fejl: $e'),
      );
    }
  }

  /// POST request
  /// 
  /// Generic POST request med request body og type-safe response parsing.
  /// 
  /// Example:
  /// ```dart
  /// final result = await apiClient.post<User>(
  ///   '/users',
  ///   body: {'name': 'John', 'email': 'john@example.com'},
  ///   fromJson: (json) => User.fromJson(json),
  /// );
  /// ```
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      if (_isSuccessStatusCode(response.statusCode)) {
        final data = fromJson(response.data);
        return ApiResult.success(data);
      } else {
        return ApiResult.failure(_mapError(response));
      }
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioException(e));
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown('Uventet fejl: $e'),
      );
    }
  }

  /// PUT request
  /// 
  /// Generic PUT request til at opdatere eksisterende ressourcer.
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      if (_isSuccessStatusCode(response.statusCode)) {
        final data = fromJson(response.data);
        return ApiResult.success(data);
      } else {
        return ApiResult.failure(_mapError(response));
      }
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioException(e));
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown('Uventet fejl: $e'),
      );
    }
  }

  /// DELETE request
  /// 
  /// Generic DELETE request til at slette ressourcer.
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
      );

      if (_isSuccessStatusCode(response.statusCode)) {
        final data = fromJson(response.data);
        return ApiResult.success(data);
      } else {
        return ApiResult.failure(_mapError(response));
      }
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioException(e));
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown('Uventet fejl: $e'),
      );
    }
  }

  /// Check om status code er success (2xx)
  bool _isSuccessStatusCode(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  /// Map Dio Response error til ApiException
  ApiException _mapError(Response response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    
    // Prøv at parse error message fra response
    String message = 'HTTP Error: $statusCode';
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['error'] ?? message;
    }

    if (statusCode >= 500) {
      return ApiException.server(
        message,
        statusCode: statusCode,
        data: data,
      );
    } else if (statusCode == 401) {
      return ApiException.unauthorized(message);
    } else if (statusCode >= 400) {
      return ApiException.client(
        message,
        statusCode: statusCode,
        data: data,
      );
    } else {
      return ApiException.unknown(message);
    }
  }

  /// Map DioException til ApiException
  ApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.network(
          'Request timeout - serveren svarede ikke i tide',
        );

      case DioExceptionType.connectionError:
        return ApiException.network(
          'Ingen internetforbindelse - tjek din netværksforbindelse',
        );

      case DioExceptionType.badResponse:
        return _mapError(error.response!);

      case DioExceptionType.cancel:
        return ApiException.unknown('Request blev annulleret');

      case DioExceptionType.unknown:
        return ApiException.network(
          'Netværksfejl: ${error.message}',
        );

      default:
        return ApiException.unknown(
          'Ukendt fejl: ${error.message}',
        );
    }
  }

  /// Tilføj custom interceptor
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Tilføj auth interceptor med token provider
  void addAuthInterceptor(Future<String?> Function() tokenProvider) {
    _dio.interceptors.add(AuthInterceptor(tokenProvider: tokenProvider));
  }
}

