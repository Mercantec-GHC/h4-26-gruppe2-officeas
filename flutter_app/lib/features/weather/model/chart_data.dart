import '../../../domain/entities/weather_entity.dart';

/// Chart Data Model
/// 
/// View model for chart visualization.
/// Beregner statistik og formaterer data til charts.
class ChartData {
  final double averageTemperature;
  final int minTemperature;
  final int maxTemperature;
  final int dataPoints;
  final List<ChartPoint> points;

  ChartData({
    required this.averageTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.dataPoints,
    required this.points,
  });

  /// Factory constructor fra WeatherEntity list
  /// 
  /// Konverterer domain entities til chart-ready data.
  /// Beregner statistik (average, min, max) og laver chart points.
  factory ChartData.fromWeatherEntities(List<WeatherEntity> weatherData) {
    if (weatherData.isEmpty) {
      return ChartData(
        averageTemperature: 0,
        minTemperature: 0,
        maxTemperature: 0,
        dataPoints: 0,
        points: [],
      );
    }

    // Beregn statistik
    final temperatures = weatherData.map((f) => f.temperatureC).toList();
    final average = temperatures.reduce((a, b) => a + b) / temperatures.length;
    final min = temperatures.reduce((a, b) => a < b ? a : b);
    final max = temperatures.reduce((a, b) => a > b ? a : b);

    // Lav chart points
    final points = weatherData.asMap().entries.map((entry) {
      return ChartPoint(
        x: entry.key.toDouble(),
        y: entry.value.temperatureC.toDouble(),
        label: '${entry.value.date.day}/${entry.value.date.month}',
        temperature: entry.value.temperatureC,
      );
    }).toList();

    return ChartData(
      averageTemperature: average,
      minTemperature: min,
      maxTemperature: max,
      dataPoints: weatherData.length,
      points: points,
    );
  }

  /// Legacy support - deprecated
  /// 
  /// Behold for bagudkompatibilitet, men brug fromWeatherEntities i stedet.
  @Deprecated('Brug fromWeatherEntities i stedet')
  factory ChartData.fromWeatherData(List<dynamic> weatherData) {
    if (weatherData.isEmpty) {
      return ChartData(
        averageTemperature: 0,
        minTemperature: 0,
        maxTemperature: 0,
        dataPoints: 0,
        points: [],
      );
    }

    final temperatures = weatherData.map((f) => f.temperatureC).toList();
    final average = temperatures.reduce((a, b) => a + b) / temperatures.length;
    final min = temperatures.reduce((a, b) => a < b ? a : b);
    final max = temperatures.reduce((a, b) => a > b ? a : b);

    final points = weatherData.asMap().entries.map((entry) {
      return ChartPoint(
        x: entry.key.toDouble(),
        y: entry.value.temperatureC.toDouble(),
        label: '${entry.value.date.day}/${entry.value.date.month}',
        temperature: entry.value.temperatureC,
      );
    }).toList();

    return ChartData(
      averageTemperature: average,
      minTemperature: min,
      maxTemperature: max,
      dataPoints: weatherData.length,
      points: points,
    );
  }
}

class ChartPoint {
  final double x;
  final double y;
  final String label;
  final int temperature;

  ChartPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.temperature,
  });
} 