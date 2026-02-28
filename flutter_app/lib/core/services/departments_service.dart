import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../../data/models/department_model.dart';
import '../../data/models/shift_model.dart';

/// Fetches departments and department shifts from the API. Reusable across feedback, forms, etc.
class DepartmentsService {
  String get _baseUrl => AppConfig.instance.apiBaseUrl;

  Future<List<ShiftModel>> getShiftsForDepartment(
    String departmentId,
    String jwt,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/departments/$departmentId/shifts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load shifts: ${response.statusCode}');
    }
    final List data = jsonDecode(response.body);
    return data
        .map((e) => ShiftModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all departments. GET /departments does not require auth.
  Future<List<DepartmentModel>> getDepartments() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/departments'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load departments: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    return data.map((e) => DepartmentModel.fromJson(e)).toList();
  }
}
