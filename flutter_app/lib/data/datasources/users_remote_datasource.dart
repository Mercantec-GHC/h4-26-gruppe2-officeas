import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../models/user_model.dart';

class UsersRemoteDataSource {
  final Dio _dio;

  UsersRemoteDataSource({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final dio = Dio(
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
    dio.interceptors.add(_UsersAuthInterceptor());
    return dio;
  }

  Future<List<UserModel>> getUsers() async {
    final response = await _dio.get('/users');
    final list = response.data as List<dynamic>;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getPendingUsers() async {
    final response = await _dio.get('/users/pending');
    final list = response.data as List<dynamic>;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<UserModel> approveUser(String userId, {String? departmentId}) async {
    final response = await _dio.put(
      '/users/$userId/approve',
      data: {
        if (departmentId != null && departmentId.isNotEmpty)
          'department_id': departmentId,
      },
    );
    return UserModel.fromJson(response.data);
  }
}

class _UsersAuthInterceptor extends Interceptor {
  static const String _tokenKey = 'auth_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
