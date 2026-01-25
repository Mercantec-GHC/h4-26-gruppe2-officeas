import 'package:equatable/equatable.dart';

/// Weather Entity (Domain Layer)
/// 
/// Repræsenterer vejr data i business logic laget.
/// Entity er uafhængig af data source (API, database, osv.)
/// 
/// Entities vs Models:
/// - Entity: Business logic representation (domain layer)
/// - Model/DTO: Data transfer representation (data layer)
/// 
/// I simple apps kan entity og model være identiske,
/// men separation gør det nemt at håndtere forskellige data sources.
class WeatherEntity extends Equatable {
  final DateTime date;
  final int temperatureC;
  final int temperatureF;
  final String? summary;

  const WeatherEntity({
    required this.date,
    required this.temperatureC,
    required this.temperatureF,
    this.summary,
  });

  /// Convenience getter for formateret dato
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Convenience getter for temperatur som string
  String get temperatureCelsius => '$temperatureC°C';
  String get temperatureFahrenheit => '$temperatureF°F';

  @override
  List<Object?> get props => [date, temperatureC, temperatureF, summary];

  @override
  String toString() {
    return 'WeatherEntity(date: $date, tempC: $temperatureC, '
        'tempF: $temperatureF, summary: $summary)';
  }
}

