import 'shift_entity.dart';

/// Result of generating shifts for a date range.
class GenerateShiftsResult {
  final List<ShiftEntity> created;
  final List<String> warnings;

  const GenerateShiftsResult({
    required this.created,
    required this.warnings,
  });
}
