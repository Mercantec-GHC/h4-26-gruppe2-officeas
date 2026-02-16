import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../models/absence_request_model.dart';

/// Absence Request Remote DataSource
///
/// Håndterer kommunikation med absence request API endpoints.
/// Returnerer models, ikke entities (entities er for domain layer).
///
/// Separation af DataSource og Repository:
/// - DataSource: Håndterer API kommunikation
/// - Repository: Orkesterer datakilder og konverterer til entities
///
/// Benefits:
/// - Nem at teste (mock DataSource i tests)
/// - Nem at udskifte API med anden datakilde (database, mock, etc.)
class AbsenceRequestRemoteDataSource {
  final ApiClient apiClient;

  AbsenceRequestRemoteDataSource({required this.apiClient});

  /// Hent alle absence requests
  ///
  /// Returns ApiResult<List<AbsenceRequestModel>>
  Future<ApiResult<List<AbsenceRequestModel>>> getAllAbsenceRequests() async {
    return await apiClient.get<List<AbsenceRequestModel>>(
      '/absence-requests',
      fromJson: (json) {
        if (json is! List) {
          throw ArgumentError('Expected list, got ${json.runtimeType}');
        }
        return json
            .map((item) => AbsenceRequestModel.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Hent absence request by ID
  ///
  /// Returns ApiResult<AbsenceRequestModel>
  Future<ApiResult<AbsenceRequestModel>> getAbsenceRequestById(String id) async {
    return await apiClient.get<AbsenceRequestModel>(
      '/absence-requests/$id',
      fromJson: (json) => AbsenceRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Opret ny absence request
  ///
  /// Returns ApiResult<AbsenceRequestModel>
  Future<ApiResult<AbsenceRequestModel>> createAbsenceRequest({
    required String userId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
  }) async {
    final body = {
      'user_id': userId,
      'type': type,
      'start_date': DateTime(startDate.year, startDate.month, startDate.day).toUtc().toIso8601String(),
      'end_date': DateTime(endDate.year, endDate.month, endDate.day).toUtc().toIso8601String(),
      'shift_id': shiftId,
      'status': 'PENDING',
    };

    return await apiClient.post<AbsenceRequestModel>(
      '/absence-requests',
      body: body,
      fromJson: (json) => AbsenceRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Opdater absence request
  ///
  /// Returns ApiResult<AbsenceRequestModel>
  Future<ApiResult<AbsenceRequestModel>> updateAbsenceRequest({
    required String id,
    required String userId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
    required String status,
  }) async {
    final body = {
      'user_id': userId,
      'type': type,
      'start_date': DateTime(startDate.year, startDate.month, startDate.day).toUtc().toIso8601String(),
      'end_date': DateTime(endDate.year, endDate.month, endDate.day).toUtc().toIso8601String(),
      'shift_id': shiftId,
      'status': status,
    };

    return await apiClient.put<AbsenceRequestModel>(
      '/absence-requests/$id',
      body: body,
      fromJson: (json) => AbsenceRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Slet absence request
  ///
  /// Returns ApiResult<void>
  Future<ApiResult<void>> deleteAbsenceRequest(String id) async {
    return await apiClient.delete<void>(
      '/absence-requests/$id',
      fromJson: (_) => null,
    );
  }
}
