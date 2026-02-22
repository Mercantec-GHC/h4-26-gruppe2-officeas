import '../../core/api/api_result.dart';
import '../../domain/entities/absence_request_entity.dart';
import '../../domain/repositories/absence_request_repository.dart';
import '../datasources/absence_request_remote_datasource.dart';
import '../../core/api/api_client.dart';

/// Absence Request Repository Implementation (Data Layer)
///
/// Konkret implementering af AbsenceRequestRepository.
/// Orkesterer datasources og konverterer til entities.
///
/// Responsibilities:
/// - Kombinerer data fra flere datasources
/// - Konverterer models til entities
/// - Implementerer business logic for data hentning
class AbsenceRequestRepositoryImpl implements AbsenceRequestRepository {
    @override
    Future<ApiResult<void>> cancelAbsenceRequest(String id) async {
      try {
        // Mark as cancelled via update (status only)
        final result = await remoteDataSource.updateAbsenceRequest(
          id: id,
          userId: '', // Not needed for cancel, but required by interface
          type: '', // Not needed for cancel, but required by interface
          startDate: DateTime.now(), // Not needed for cancel, but required by interface
          endDate: DateTime.now(), // Not needed for cancel, but required by interface
          shiftId: null,
          status: 'CANCELLED',
        );
        return result.when(
          success: (_) => ApiResult.success(null),
          failure: (error) => ApiResult.failure(error),
        );
      } catch (e) {
        return ApiResult.failure(
          ApiException.unknown(
            'Failed to cancel absence request: ${e.toString()}',
          ),
        );
      }
    }
  final AbsenceRequestRemoteDataSource remoteDataSource;

  AbsenceRequestRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<ApiResult<List<AbsenceRequestEntity>>> getAllAbsenceRequests() async {
    try {
      final result = await remoteDataSource.getAllAbsenceRequests();

      return result.when(
        success: (models) {
          final entities = models.map((model) => model.toEntity()).toList();
          return ApiResult.success(entities);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown(
          'Failed to fetch absence requests: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<AbsenceRequestEntity>> getAbsenceRequestById(String id) async {
    try {
      final result = await remoteDataSource.getAbsenceRequestById(id);

      return result.when(
        success: (model) => ApiResult.success(model.toEntity()),
        failure: (error) => ApiResult.failure(error),
      );
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown(
          'Failed to fetch absence request: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<AbsenceRequestEntity>> createAbsenceRequest({
    required String userId,
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
  }) async {
    try {
      final result = await remoteDataSource.createAbsenceRequest(
        userId: userId,
        type: type.apiValue,
        startDate: startDate,
        endDate: endDate,
        shiftId: shiftId,
      );

      return result.when(
        success: (model) => ApiResult.success(model.toEntity()),
        failure: (error) => ApiResult.failure(error),
      );
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown(
          'Failed to create absence request: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<AbsenceRequestEntity>> updateAbsenceRequest({
    required String id,
    required String userId,
    required AbsenceType type,
    required DateTime startDate,
    required DateTime endDate,
    String? shiftId,
    required AbsenceRequestStatus status,
  }) async {
    try {
      final result = await remoteDataSource.updateAbsenceRequest(
        id: id,
        userId: userId,
        type: type.apiValue,
        startDate: startDate,
        endDate: endDate,
        shiftId: shiftId,
        status: status.toString().split('.').last.toUpperCase(),
      );

      return result.when(
        success: (model) => ApiResult.success(model.toEntity()),
        failure: (error) => ApiResult.failure(error),
      );
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown(
          'Failed to update absence request: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<void>> deleteAbsenceRequest(String id) async {
    try {
      return await remoteDataSource.deleteAbsenceRequest(id);
    } catch (e) {
      return ApiResult.failure(
        ApiException.unknown(
          'Failed to delete absence request: ${e.toString()}',
        ),
      );
    }
  }
}
