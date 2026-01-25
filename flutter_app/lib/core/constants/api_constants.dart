class ApiConstants {
  // Backend API URL 
  static const String baseUrl = 'https://h4-api.mercantec.tech/api';
  
  // Weather endpoints
  static const String weatherForecast = '/WeatherForecast';
  
  // Full URLs
  static String get weatherForecastUrl => '$baseUrl$weatherForecast';
} 