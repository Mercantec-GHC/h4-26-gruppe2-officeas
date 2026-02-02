import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Automatically adds JWT token to all requests
/// Handles token expiration and refresh
class SecureApiClient {
  static SecureApiClient? _instance;
  late Dio _dio;

  SecureApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.instance.apiBaseUrl,
        connectTimeout: Duration(milliseconds: AppConfig.instance.apiTimeout),
        receiveTimeout: Duration(milliseconds: AppConfig.instance.apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(AuthInterceptor());

    if (AppConfig.instance.enableApiLogging) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, error: true),
      );
    }
  }

  static SecureApiClient get instance {
    _instance ??= SecureApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;
}

/// Authentication Interceptor
/// Adds JWT token to requests and handles 401 errors
class AuthInterceptor extends Interceptor {
  static const String _tokenKey = 'auth_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip adding token for auth endpoints
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register') ||
        options.path.contains('/auth/sso')) {
      return handler.next(options);
    }

    // Get token from storage
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid - navigate to login
      _handleUnauthorized();
    }
    handler.next(err);
  }

  void _handleUnauthorized() async {
    // Clear stored token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);

    print('Unauthorized: Token expired or invalid');
  }
}
