import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../models/shift_model.dart';

/// Shift Remote DataSource
/// 
/// Håndterer kommunikation med shift API endpoints.
/// Returnerer models, ikke entities (entities er for domain layer).
/// 
/// Separation af DataSource og Repository:
/// - DataSource: Håndterer API kommunikation
/// - Repository: Orkesterer datakilder og konverterer til entities
/// 
/// Benefits:
/// - Nem at teste (mock DataSource i tests)
/// - Nem at udskifte API med anden datakilde (database, mock, etc.)
class ShiftRemoteDataSource {
  final ApiClient apiClient;

  ShiftRemoteDataSource({required this.apiClient});

  /// Hent alle shifts
  /// 
  /// Returns ApiResult<List<ShiftModel>>
  Future<ApiResult<List<ShiftModel>>> getAllShifts() async {
    return await apiClient.get<List<ShiftModel>>(
      '/shifts',
      fromJson: (json) {
        if (json is! List) {
          throw ArgumentError('Expected list, got ${json.runtimeType}');
        }
        return json
            .map((item) => ShiftModel.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Hent shift by ID
  /// 
  /// Returns ApiResult<ShiftModel>
  Future<ApiResult<ShiftModel>> getShiftById(String id) async {
    return await apiClient.get<ShiftModel>(
      '/shifts/$id',
      fromJson: (json) => ShiftModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Hent shifts for specifik bruger
  /// 
  /// Returns ApiResult<List<ShiftModel>>
  Future<ApiResult<List<ShiftModel>>> getShiftsByUserId(String userId) async {
    return await apiClient.get<List<ShiftModel>>(
      '/shifts/user/$userId',
      fromJson: (json) {
        if (json is! List) {
          throw ArgumentError('Expected list, got ${json.runtimeType}');
        }
        return json
            .map((item) => ShiftModel.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Opret ny shift
  /// 
  /// Returns ApiResult<ShiftModel>
  Future<ApiResult<ShiftModel>> createShift(ShiftModel shift) async {
    return await apiClient.post<ShiftModel>(
      '/shifts',
      body: shift.toJson(),
      fromJson: (json) => ShiftModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Opdater shift
  /// 
  /// Returns ApiResult<ShiftModel>
  Future<ApiResult<ShiftModel>> updateShift(String id, ShiftModel shift) async {
    return await apiClient.put<ShiftModel>(
      '/shifts/$id',
      body: shift.toJson(),
      fromJson: (json) => ShiftModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Slet shift
  /// 
  /// Returns ApiResult<void>
  Future<ApiResult<void>> deleteShift(String id) async {
    return await apiClient.delete<void>(
      '/shifts/$id',
      fromJson: (_) => null,
    );
  }
}
