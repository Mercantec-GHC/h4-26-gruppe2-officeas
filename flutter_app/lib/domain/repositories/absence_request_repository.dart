import '../../core/api/api_result.dart';
import '../entities/absence_request_entity.dart';

/// Absence Request Repository (Domain Layer)
///
/// Abstrakt interface for absence request operations.
/// Definerer kontrakten som implementering skal følge.
///
/// Repository pattern benefits:
/// - Separation af concerns (API vs business logic)
/// - Nem testing (mock repository i tests)
/// - Nem at skifte data source senere
abstract class AbsenceRequestRepository {
  /// Hent alle absence requests
  Future<ApiResult<List<AbsenceRequestEntity>>> getAllAbsenceRequests();

  /// Hent absence request by ID
  Future<ApiResult<AbsenceRequestEntity>> getAbsenceRequestById(String id);

  /// Opret ny absence request
  Future<ApiResult<AbsenceRequestEntity>> createAbsenceRequest({
    required String userId,
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
  });

  /// Opdater absence request
  Future<ApiResult<AbsenceRequestEntity>> updateAbsenceRequest({
    required String id,
    required String userId,
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
    required AbsenceRequestStatus status,
  });

  /// Slet absence request
  Future<ApiResult<void>> deleteAbsenceRequest(String id);
}
