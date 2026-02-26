import '../../domain/entities/absence_request_entity.dart';

/// Absence Request Model (Data Layer / DTO)
///
/// Data Transfer Object til API kommunikation.
/// Håndterer serialization/deserialization (JSON <-> Object).
///
/// Model vs Entity:
/// - Model: Tied til data source format (JSON structure fra API)
/// - Entity: Business logic representation
///
/// Models kan konverteres til entities via `.toEntity()` metode.
class AbsenceRequestModel {
  final String id;
  final String userId;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String? shiftId;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByUserId;
  final String? userName;

  AbsenceRequestModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.shiftId,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByUserId,
    this.userName,
  });

  /// Deserialize fra JSON (fra API response)
  ///
  /// Håndterer parsing fra JSON til Dart objekt.
  factory AbsenceRequestModel.fromJson(Map<String, dynamic> json) {
    return AbsenceRequestModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      shiftId: json['shift_id'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedByUserId: json['reviewed_by_user_id'] as String?,
      userName: json['user']?['name'] as String?,
    );
  }

  /// Serialize til JSON (til API requests)
  ///
  /// Konverterer Dart objekt til JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'start_date': startDate.toIso8601String().split('T')[0], // Date only
      'end_date': endDate.toIso8601String().split('T')[0], // Date only
      'shift_id': shiftId,
      'status': status,
    };
  }

  /// Konverter Model til Entity (Data Layer → Domain Layer)
  ///
  /// Separerer data representation fra business logic.
  /// Repository returnerer entities, ikke models.
  AbsenceRequestEntity toEntity() {
    return AbsenceRequestEntity(
      id: id,
      userId: userId,
      type: AbsenceType.fromString(type),
      startDate: startDate,
      endDate: endDate,
      shiftId: shiftId,
      status: AbsenceRequestStatus.fromString(status),
      createdAt: createdAt,
      reviewedAt: reviewedAt,
      reviewedByUserId: reviewedByUserId,
      userName: userName,
    );
  }

  /// Konverter Entity til Model (Domain Layer → Data Layer)
  ///
  /// Bruges hvis vi skal sende entity data tilbage til API.
  factory AbsenceRequestModel.fromEntity(AbsenceRequestEntity entity) {
    return AbsenceRequestModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type.apiValue,
      startDate: entity.startDate,
      endDate: entity.endDate,
      shiftId: entity.shiftId,
      status: entity.status.toString().split('.').last.toUpperCase(),
      createdAt: entity.createdAt,
      reviewedAt: entity.reviewedAt,
      reviewedByUserId: entity.reviewedByUserId,
      userName: entity.userName,
    );
  }

  @override
  String toString() {
    return 'AbsenceRequestModel('
        'id: $id, userId: $userId, type: $type, '
        'startDate: $startDate, endDate: $endDate, status: $status)';
  }
}
