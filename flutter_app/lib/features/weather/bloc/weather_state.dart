import 'package:equatable/equatable.dart';
import '../../../domain/entities/weather_entity.dart';
import '../model/chart_data.dart';

/// Base class for alle Weather states
/// 
/// Bruger Equatable for automatisk equality comparison.
/// Dette gør at BLoC kun rebuilder widgets når state faktisk ændrer sig.
abstract class WeatherState extends Equatable {
  const WeatherState();

  @override
  List<Object?> get props => [];
}

/// Initial state når appen starter
/// 
/// Emitted når BLoC oprettes første gang.
class WeatherInitial extends WeatherState {
  const WeatherInitial();
}

/// Loading state
/// 
/// Emitted når data bliver hentet fra repository.
/// UI kan vise loading spinner/skeleton.
class WeatherLoading extends WeatherState {
  const WeatherLoading();
}

/// Success state
/// 
/// Emitted når data er hentet succesfuldt fra repository.
/// Indeholder WeatherEntity (domain layer) ikke Model (data layer).
/// Dette holder UI uafhængig af data source detaljer.
class WeatherLoaded extends WeatherState {
  final List<WeatherEntity> weatherData;
  final ChartData chartData;

  const WeatherLoaded({
    required this.weatherData,
    required this.chartData,
  });

  @override
  List<Object?> get props => [weatherData, chartData];
}

/// Error state
/// 
/// Emitted når der opstår en fejl i repository.
/// Message er brugervenlig fejlbesked fra ApiException.userMessage.
class WeatherError extends WeatherState {
  final String message;

  const WeatherError(this.message);

  @override
  List<Object?> get props => [message];
}

