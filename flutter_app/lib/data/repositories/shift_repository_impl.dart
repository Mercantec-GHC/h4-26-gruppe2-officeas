import '../../core/api/api_result.dart';
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

  ShiftRepositoryImpl({
    required this.remoteDataSource,
  });

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
    // I denne simple implementation er refresh det samme som get
    // Men kunne implementere force refresh logic her
    return getAllShifts();
  }
}
