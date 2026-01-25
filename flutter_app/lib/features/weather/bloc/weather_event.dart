import 'package:equatable/equatable.dart';

/// Base class for alle Weather events
abstract class WeatherEvent extends Equatable {
  const WeatherEvent();

  @override
  List<Object?> get props => [];
}

/// Event der trigges når vejrdata skal hentes
class LoadWeatherData extends WeatherEvent {
  const LoadWeatherData();
}

/// Event der trigges når brugeren vil refreshe vejrdata
class RefreshWeatherData extends WeatherEvent {
  const RefreshWeatherData();
}

