class WeatherForecast {
  final DateTime date;
  final int temperatureC;
  final int temperatureF;
  final String? summary;

  WeatherForecast({
    required this.date,
    required this.temperatureC,
    required this.temperatureF,
    this.summary,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      date: DateTime.parse(json['date']),
      temperatureC: json['temperatureC'],
      temperatureF: json['temperatureF'],
      summary: json['summary'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'temperatureC': temperatureC,
      'temperatureF': temperatureF,
      'summary': summary,
    };
  }
} 