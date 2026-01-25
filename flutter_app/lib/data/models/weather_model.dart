import '../../domain/entities/weather_entity.dart';

/// Weather Model (Data Layer / DTO)
/// 
/// Data Transfer Object til API kommunikation.
/// Håndterer serialization/deserialization (JSON <-> Object).
/// 
/// Model vs Entity:
/// - Model: Tied til data source format (JSON structure fra API)
/// - Entity: Business logic representation
/// 
/// Models kan konverteres til entities via `.toEntity()` metode.
class WeatherModel {
  final DateTime date;
  final int temperatureC;
  final int temperatureF;
  final String? summary;

  WeatherModel({
    required this.date,
    required this.temperatureC,
    required this.temperatureF,
    this.summary,
  });

  /// Deserialize fra JSON (fra API response)
  /// 
  /// Håndterer parsing fra JSON til Dart objekt.
  /// Tilføj validation eller transformations her hvis nødvendigt.
  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      date: DateTime.parse(json['date'] as String),
      temperatureC: json['temperatureC'] as int,
      temperatureF: json['temperatureF'] as int,
      summary: json['summary'] as String?,
    );
  }

  /// Serialize til JSON (til API requests)
  /// 
  /// Konverterer Dart objekt til JSON format.
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'temperatureC': temperatureC,
      'temperatureF': temperatureF,
      'summary': summary,
    };
  }

  /// Konverter Model til Entity (Data Layer → Domain Layer)
  /// 
  /// Separerer data representation fra business logic.
  /// Repository returnerer entities, ikke models.
  WeatherEntity toEntity() {
    return WeatherEntity(
      date: date,
      temperatureC: temperatureC,
      temperatureF: temperatureF,
      summary: summary,
    );
  }

  /// Konverter Entity til Model (Domain Layer → Data Layer)
  /// 
  /// Bruges hvis vi skal sende entity data tilbage til API.
  factory WeatherModel.fromEntity(WeatherEntity entity) {
    return WeatherModel(
      date: entity.date,
      temperatureC: entity.temperatureC,
      temperatureF: entity.temperatureF,
      summary: entity.summary,
    );
  }

  @override
  String toString() {
    return 'WeatherModel(date: $date, tempC: $temperatureC, '
        'tempF: $temperatureF, summary: $summary)';
  }
}

