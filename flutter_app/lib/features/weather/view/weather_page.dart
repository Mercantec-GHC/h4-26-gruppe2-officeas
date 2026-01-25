import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/weather_bloc.dart';
import '../bloc/weather_event.dart';
import '../bloc/weather_state.dart';
import '../widgets/weather_list.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vejrforudsigelse'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Send event til BLoC for at refreshe data
              context.read<WeatherBloc>().add(const RefreshWeatherData());
            },
            tooltip: 'Opdater',
          ),
        ],
      ),
      body: BlocBuilder<WeatherBloc, WeatherState>(
        builder: (context, state) {
          // Pattern matching på state type
          if (state is WeatherInitial) {
            // Hent data automatisk ved første visning
            context.read<WeatherBloc>().add(const LoadWeatherData());
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is WeatherLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Henter vejrdata...'),
                ],
              ),
            );
          } else if (state is WeatherLoaded) {
            return WeatherList(
              forecasts: state.weatherData,
              chartData: state.chartData,
            );
          } else if (state is WeatherError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fejl ved hentning af vejrdata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<WeatherBloc>().add(const RefreshWeatherData());
                    },
                    child: const Text('Prøv igen'),
                  ),
                ],
              ),
            );
          }
          
          // Fallback hvis ingen state matcher
          return const Center(child: Text('Ukendt tilstand'));
        },
      ),
    );
  }
} 