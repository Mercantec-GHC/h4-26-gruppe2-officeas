import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/api/secure_api_client.dart';
import '../models/user_model.dart';

/// Repository for user-related API calls (profile image upload, etc.).
class UserRepository {
  late final Dio _dio;

  UserRepository({Dio? dio}) {
    _dio =
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
            headers: {'Accept': 'application/json'},
          ),
        );
    _dio.interceptors.add(AuthInterceptor());
  }

  /// Upload profile image for the current user (PUT /users/me/profile-image).
  /// [bytes] and [filename] work on all platforms (no dart:io).
  /// Returns the updated user with [avatar_url] set.
  Future<UserModel> uploadProfileImage(
    List<int> bytes, {
    String filename = 'image.jpg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _dio.put(
      '/users/me/profile-image',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Build full URL for an avatar or image path returned by the API.
  /// [path] is e.g. "/users/xxx/avatar" or "/tickets/xxx/image".
  static String imageUrl(String path) {
    if (path.isEmpty) return '';

    final base = AppConfig.instance.apiBaseUrl;
    final baseTrimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final pathTrimmed = path.startsWith('/') ? path : '/$path';

    return '$baseTrimmed$pathTrimmed';
  }
}
