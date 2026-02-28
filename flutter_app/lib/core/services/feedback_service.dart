import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../../data/models/feedback_model.dart';

class FeedbackService {
  String get _baseUrl => AppConfig.instance.apiBaseUrl;

  Future<void> createFeedback({
    required FeedbackModel feedback,
    required String jwt,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/feedback'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode(feedback.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create feedback (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Load all feedback. Pass [jwt] so the request is authorized (GET /feedback is protected).
  Future<List<FeedbackModel>> getAllFeedback({String? jwt}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (jwt != null && jwt.isNotEmpty) {
      headers['Authorization'] = 'Bearer $jwt';
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/feedback'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FeedbackModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load feedback');
    }
  }
}
