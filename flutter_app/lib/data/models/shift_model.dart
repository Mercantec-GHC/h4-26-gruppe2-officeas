import '../../domain/entities/shift_entity.dart';

/// Shift Model (Data Layer / DTO)
/// 
/// Data Transfer Object til API kommunikation.
/// Håndterer serialization/deserialization (JSON <-> Object).
/// 
/// Model vs Entity:
/// - Model: Tied til data source format (JSON structure fra API)
/// - Entity: Business logic representation
/// 
/// Models kan konverteres til entities via `.toEntity()` metode.
class ShiftModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final String? userName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShiftModel({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    this.userName,
    this.createdAt,
    this.updatedAt,
  });

  /// Deserialize fra JSON (fra API response)
  /// 
  /// Håndterer parsing fra JSON til Dart objekt.
  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      userName: json['user']?['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Serialize til JSON (til API requests)
  /// 
  /// Konverterer Dart objekt til JSON format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Konverter Model til Entity (Data Layer → Domain Layer)
  /// 
  /// Separerer data representation fra business logic.
  /// Repository returnerer entities, ikke models.
  ShiftEntity toEntity() {
    return ShiftEntity(
      id: id,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      userName: userName,
    );
  }

  /// Konverter Entity til Model (Domain Layer → Data Layer)
  /// 
  /// Bruges hvis vi skal sende entity data tilbage til API.
  factory ShiftModel.fromEntity(ShiftEntity entity) {
    return ShiftModel(
      id: entity.id,
      userId: entity.userId,
      startTime: entity.startTime,
      endTime: entity.endTime,
      userName: entity.userName,
    );
  }

  @override
  String toString() {
    return 'ShiftModel(id: $id, userId: $userId, startTime: $startTime, '
        'endTime: $endTime, userName: $userName)';
  }
}
