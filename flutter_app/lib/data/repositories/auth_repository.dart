import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response_model.dart';
import '../../core/config/app_config.dart';

class AuthRepository {
  final Dio _dio;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.instance.apiBaseUrl,
              connectTimeout: Duration(
                milliseconds: AppConfig.instance.apiTimeout,
              ),
              receiveTimeout: Duration(
                milliseconds: AppConfig.instance.apiTimeout,
              ),
            ),
          );

  Future<AuthResponseModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    required String departmentId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'department_id': departmentId,
        },
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponseModel> ssoLogin({
    required String provider,
    required String idToken,
    required String email,
    required String name,
    String? departmentId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/sso',
        data: {
          'provider': provider,
          'id_token': idToken,
          'email': email,
          'name': name,
          if (departmentId != null) 'department_id': departmentId,
        },
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponseModel> githubCallback(String code) async {
    try {
      final response = await _dio.get(
        '/auth/github/callback',
        queryParameters: {'code': code},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> _saveAuthData(AuthResponseModel authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authResponse.token);
    await prefs.setString(_userKey, authResponse.user.toJson().toString());
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      // Try to extract error message from response
      final data = error.response?.data;
      if (data is String) {
        return data;
      } else if (data is Map && data['message'] != null) {
        return data['message'];
      }
      return 'Server error: ${error.response?.statusCode}';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout - is the server running?';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please check if the backend is running on ${AppConfig.instance.apiBaseUrl}';
    } else {
      return 'Network error: ${error.message}';
    }
  }
}
