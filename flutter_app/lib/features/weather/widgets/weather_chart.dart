import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/entities/weather_entity.dart';
import '../model/chart_data.dart';

class WeatherChart extends StatelessWidget {
  final List<WeatherEntity> forecasts;
  final ChartData? chartData;

  const WeatherChart({
    super.key,
    required this.forecasts,
    this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temperatur over tid',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}°C',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < forecasts.length) {
                            final date = forecasts[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _createSpots(),
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  minY: _getMinTemperature() - 5,
                  maxY: _getMaxTemperature() + 5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _createSpots() {
    return forecasts.asMap().entries.map((entry) {
      final index = entry.key;
      final forecast = entry.value;
      return FlSpot(index.toDouble(), forecast.temperatureC.toDouble());
    }).toList();
  }

  double _getMinTemperature() {
    if (forecasts.isEmpty) return 0;
    return forecasts.map((f) => f.temperatureC.toDouble()).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxTemperature() {
    if (forecasts.isEmpty) return 0;
    return forecasts.map((f) => f.temperatureC.toDouble()).reduce((a, b) => a > b ? a : b);
  }

  Widget _buildLegend(BuildContext context) {
    final avgTemp = chartData?.averageTemperature ?? 0;
    final dataPoints = chartData?.dataPoints ?? 0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Gennemsnit: ${avgTemp.toStringAsFixed(1)}°C',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$dataPoints dage',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 