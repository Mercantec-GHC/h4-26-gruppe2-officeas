import '../../core/api/api_result.dart';
import '../entities/shift_entity.dart';

/// Shift Repository Interface (Domain Layer)
/// 
/// Definer kontrakten for shift data access.
/// BLoC afhænger kun af denne interface, ikke konkret implementation.
/// 
/// Benefits:
/// - Testability: Nem at mocke i unit tests
/// - Flexibility: Skift data source uden at ændre BLoC
/// - Dependency Inversion: High-level modules afhænger ikke af low-level modules
/// 
/// Usage i BLoC:
/// ```dart
/// class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
///   final ShiftRepository repository; // Interface, ikke implementation!
///   
///   CalendarBloc({required this.repository});
/// }
/// ```
abstract class ShiftRepository {
  /// Hent alle shifts
  /// 
  /// Returns ApiResult<List<ShiftEntity>> for type-safe error handling.
  /// 
  /// Success case: Liste af shift data
  /// Failure case: ApiException med fejldetaljer
  Future<ApiResult<List<ShiftEntity>>> getAllShifts();

  /// Hent shift by ID
  /// 
  /// Returns ApiResult<ShiftEntity>
  Future<ApiResult<ShiftEntity>> getShiftById(String id);

  /// Hent shifts for specifik bruger
  /// 
  /// Returns ApiResult<List<ShiftEntity>>
  Future<ApiResult<List<ShiftEntity>>> getShiftsByUserId(String userId);

  /// Hent shifts for en given dato
  /// 
  /// Returns ApiResult<List<ShiftEntity>>
  Future<ApiResult<List<ShiftEntity>>> getShiftsByDate(DateTime date);

  /// Hent shifts i et datointerval
  /// 
  /// Returns ApiResult<List<ShiftEntity>>
  Future<ApiResult<List<ShiftEntity>>> getShiftsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Refresh shifts data
  Future<ApiResult<List<ShiftEntity>>> refreshAllShifts();
}
