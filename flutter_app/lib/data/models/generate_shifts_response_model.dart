import 'shift_model.dart';

/// Response from POST /shifts/generate
class GenerateShiftsResponseModel {
  final List<ShiftModel> created;
  final List<String> warnings;

  GenerateShiftsResponseModel({
    required this.created,
    required this.warnings,
  });

  factory GenerateShiftsResponseModel.fromJson(Map<String, dynamic> json) {
    final createdList = json['created'];
    final warningsList = json['warnings'];

    return GenerateShiftsResponseModel(
      created: createdList is List
          ? (createdList)
              .map((e) => ShiftModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      warnings: warningsList is List
          ? (warningsList).map((e) => e.toString()).toList()
          : [],
    );
  }
}
