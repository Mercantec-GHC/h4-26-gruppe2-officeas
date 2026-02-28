import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../models/messaging_models.dart';
import '../models/user_model.dart';

/// Remote data source for messaging. Dio + JWT interceptor.
class MessagingRemoteDataSource {
  final Dio _dio;
  static const String _tokenKey = 'auth_token';

  MessagingRemoteDataSource({Dio? dio}) : _dio = dio ?? _createDio();

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
    dio.interceptors.add(_AuthInterceptor());
    if (AppConfig.instance.enableApiLogging) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, error: true),
      );
    }
    return dio;
  }

  /// GET /conversations
  Future<List<ConversationModel>> getConversations() async {
    final response = await _dio.get('/conversations');
    final list = response.data as List<dynamic>;
    return list.map((e) => ConversationModel.fromJson(e)).toList();
  }

  /// POST /conversations
  Future<ConversationModel> createConversation({
    required List<String> userIds,
    required bool isGroup,
  }) async {
    final response = await _dio.post(
      '/conversations',
      data: {'user_ids': userIds, 'is_group': isGroup},
    );
    return ConversationModel.fromJson(response.data);
  }

  /// GET /conversations/{id}/messages?limit=&offset=
  Future<PaginatedMessagesModel> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return PaginatedMessagesModel.fromJson(response.data);
  }

  /// POST /conversations/{id}/messages
  Future<MessageModel> sendMessage(
    String conversationId,
    String content,
  ) async {
    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return MessageModel.fromJson(response.data);
  }

  /// POST /messages/multi
  /// Creates/reuses a conversation and sends one message to multiple users.
  Future<ConversationModel> sendMessageToUsers({
    required List<String> userIds,
    required String content,
    bool isGroup = true,
  }) async {
    final response = await _dio.post(
      '/messages/multi',
      data: {'user_ids': userIds, 'content': content, 'is_group': isGroup},
    );

    final conversationJson =
        response.data['conversation'] as Map<String, dynamic>;
    return ConversationModel.fromJson(conversationJson);
  }

  /// PUT /messages/{id}/read
  Future<void> markAsRead(String messageId) async {
    await _dio.put('/messages/$messageId/read');
  }

  /// GET /conversations/{id}/unread
  Future<int> getUnreadCount(String conversationId) async {
    final response = await _dio.get('/conversations/$conversationId/unread');
    return response.data['unread_count'] ?? 0;
  }

  /// GET /users — fetch all users in the company.
  Future<List<UserModel>> getUsers() async {
    final response = await _dio.get('/users');
    final list = response.data as List<dynamic>;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// Returns the stored JWT token. Used by the WebSocket client.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}

/// Interceptor that adds JWT from SharedPreferences.
class _AuthInterceptor extends Interceptor {
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
