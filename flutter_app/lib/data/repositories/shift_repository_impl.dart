import '../../core/api/api_result.dart';
import '../../domain/entities/generate_shifts_result.dart';
import '../../domain/entities/shift_entity.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/shift_remote_datasource.dart';

/// Shift Repository Implementation (Data Layer)
///
/// Konkret implementation af ShiftRepository interface.
/// Koordinerer data sources og konverterer models til entities.
///
/// Architecture flow:
/// BLoC → Repository Interface → Repository Impl → DataSource → API Client → API
///
/// Responsibilities:
/// - Kalder data sources (remote/local)
/// - Konverterer models til entities
/// - Håndterer filtering logik (by date, user, etc.)
class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftRemoteDataSource remoteDataSource;

  ShiftRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ApiResult<List<ShiftEntity>>> getAllShifts() async {
    // Hent data fra remote data source
    final result = await remoteDataSource.getAllShifts();

    // Transform models til entities
    return result.map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }

  @override
  Future<ApiResult<ShiftEntity>> getShiftById(String id) async {
    final result = await remoteDataSource.getShiftById(id);

    return result.map((model) => model.toEntity());
  }

  @override
  Future<ApiResult<List<ShiftEntity>>> getShiftsByUserId(String userId) async {
    final result = await remoteDataSource.getShiftsByUserId(userId);

    return result.map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }

  @override
  Future<ApiResult<List<ShiftEntity>>> getShiftsByDate(DateTime date) async {
    // Hent alle shifts og filter for specifik dato
    final result = await getAllShifts();

    return result.map((shifts) {
      return shifts.where((shift) {
        return shift.startTime.year == date.year &&
            shift.startTime.month == date.month &&
            shift.startTime.day == date.day;
      }).toList();
    });
  }

  @override
  Future<ApiResult<List<ShiftEntity>>> getShiftsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Hent alle shifts og filter for datointerval
    final result = await getAllShifts();

    return result.map((shifts) {
      return shifts.where((shift) {
        return shift.startTime.isAfter(startDate) &&
                shift.startTime.isBefore(endDate) ||
            shift.startTime.isAtSameMomentAs(startDate) ||
            shift.startTime.isAtSameMomentAs(endDate);
      }).toList();
    });
  }

  @override
  Future<ApiResult<List<ShiftEntity>>> refreshAllShifts() async {
    return getAllShifts();
  }

  /// Max days per API call to avoid timeouts (one day per request).
  static const int _generateChunkDays = 1;

  @override
  Future<ApiResult<GenerateShiftsResult>> generateShifts({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allCreated = <ShiftEntity>[];
    final allWarnings = <String>[];

    DateTime chunkStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    /// Cross-chunk state: user_id -> number of shifts assigned so far in this run.
    /// Passed to the backend so balance is preserved across chunked requests.
    Map<String, int> priorAssignedCounts = {};

    while (!chunkStart.isAfter(endDay)) {
      final chunkEnd = chunkStart.add(Duration(days: _generateChunkDays - 1));
      final chunkEndClamped = chunkEnd.isAfter(endDay) ? endDay : chunkEnd;

      final result = await remoteDataSource.generateShifts(
        startDate: chunkStart,
        endDate: chunkEndClamped,
        priorAssignedCounts: priorAssignedCounts.isEmpty
            ? null
            : Map.from(priorAssignedCounts),
      );

      final failure = result.exceptionOrNull;
      if (failure != null) {
        return ApiResult.failure(failure);
      }

      final model = result.dataOrNull!;
      for (final m in model.created) {
        allCreated.add(m.toEntity());

        priorAssignedCounts[m.userId] =
            (priorAssignedCounts[m.userId] ?? 0) + 1;
      }
      allWarnings.addAll(model.warnings);

      chunkStart = chunkEndClamped.add(const Duration(days: 1));
    }

    return ApiResult.success(
      GenerateShiftsResult(created: allCreated, warnings: allWarnings),
    );
  }
}
