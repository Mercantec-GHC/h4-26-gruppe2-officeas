import 'package:dio/dio.dart';

import '../../core/api/secure_api_client.dart';
import '../../core/config/app_config.dart';
import '../models/ticket_comment_model.dart';
import '../models/ticket_model.dart';

class TicketRepository {
  late final Dio _dio;

  TicketRepository({Dio? dio}) {
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
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
    _dio.interceptors.add(AuthInterceptor());
  }

  Future<List<TicketModel>> getTickets() async {
    final response = await _dio.get('/tickets');

    if (response.data is! List) throw Exception('Expected list of tickets');

    return (response.data as List)
        .map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TicketModel> getTicketById(String id) async {
    final response = await _dio.get('/tickets/$id');

    return TicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TicketModel> createTicket({
    required String title,
    required String description,
    required String createdByUserId,
    String? assignedToUserId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'created_by_user_id': createdByUserId,
    };

    if (assignedToUserId != null) {
      body['assigned_to_user_id'] = assignedToUserId;
    }

    final response = await _dio.post('/tickets', data: body);
    return TicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TicketModel> updateTicket(
    String id, {
    String? title,
    String? description,
    String? status,
    String? assignedToUserId,
  }) async {
    final current = await getTicketById(id);

    final body = <String, dynamic>{
      'title': title ?? current.title,
      'description': description ?? current.description,
      'status': status ?? current.status,
      'assigned_to_user_id': assignedToUserId ?? current.assignedToUserId,
    };

    final response = await _dio.put('/tickets/$id', data: body);

    return TicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTicket(String id) async {
    await _dio.delete('/tickets/$id');
  }

  Future<List<TicketCommentModel>> getComments(String ticketId) async {
    final response = await _dio.get('tickets/$ticketId/comments');

    if (response.data is! List) throw Exception('Expected list of comments');

    return (response.data as List)
        .map((e) => TicketCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TicketCommentModel> addComment({
    required String ticketId,
    required String userId,
    required String content,
  }) async {
    final response = await _dio.post(
      '/tickets/$ticketId/comments',
      data: {'user_id': userId, 'content': content},
    );

    return TicketCommentModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Upload problem image for a ticket (PUT /tickets/:id/image).
  /// [bytes] and [filename] work on all platforms (no dart:io).
  Future<TicketModel> uploadTicketImage(
    String ticketId,
    List<int> bytes, {
    String filename = 'image.jpg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await _dio.put(
      '/tickets/$ticketId/image',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return TicketModel.fromJson(response.data as Map<String, dynamic>);
  }
}
