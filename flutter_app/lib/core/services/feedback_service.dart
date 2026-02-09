import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/feedback_model.dart';

class FeedbackService {
  static const String baseUrl = 'http://localhost:8080/api';

  Future<void> createFeedback({
    required FeedbackModel feedback,
    required String jwt,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feedback'),
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

  Future<List<FeedbackModel>> getAllFeedback() async {
    final response = await http.get(
      Uri.parse('$baseUrl/feedback'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FeedbackModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load feedback');
    }
  }
}
