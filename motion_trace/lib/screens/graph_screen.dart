import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:motion_trace/models/sensor_reading.dart';

class GraphScreen extends StatelessWidget {
  final List<SensorReading> readings;

  const GraphScreen({super.key, required this.readings});

  List<FlSpot> _toSpots(List<double> values) {
    return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
  }

  Widget _buildSensorChart({
    required String title,
    required List<double> x,
    required List<double> y,
    required List<double> z,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval([...x, ...y, ...z]),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: false,
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: x.length > 0 ? (x.length - 1).toDouble() : 0,
                minY: _getMinValue([...x, ...y, ...z]),
                maxY: _getMaxValue([...x, ...y, ...z]),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    spots: _toSpots(x),
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    spots: _toSpots(y),
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    spots: _toSpots(z),
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.red, label: "X Axis"),
              const SizedBox(width: 16),
              _LegendDot(color: Colors.green, label: "Y Axis"),
              const SizedBox(width: 16),
              _LegendDot(color: Colors.blue, label: "Z Axis"),
            ],
          ),
        ],
      ),
    );
  }

  double _getMinValue(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a < b ? a : b) - 1;
  }

  double _getMaxValue(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b) + 1;
  }

  double _getInterval(List<double> values) {
    final max = _getMaxValue(values);
    final min = _getMinValue(values);
    final range = max - min;
    return range / 5;
  }

  @override
  Widget build(BuildContext context) {
    // Extract data
    final accelX = readings.map((r) => r.accelX).toList();
    final accelY = readings.map((r) => r.accelY).toList();
    final accelZ = readings.map((r) => r.accelZ).toList();

    final gyroX = readings.map((r) => r.gyroX).toList();
    final gyroY = readings.map((r) => r.gyroY).toList();
    final gyroZ = readings.map((r) => r.gyroZ).toList();

    final magX = readings.map((r) => r.magX).toList();
    final magY = readings.map((r) => r.magY).toList();
    final magZ = readings.map((r) => r.magZ).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Sensor Data Analysis',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${readings.length} Data Points",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Session duration: ${_calculateDuration(readings)}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSensorChart(
              title: "Accelerometer (X, Y, Z)",
              x: accelX,
              y: accelY,
              z: accelZ,
            ),
            const SizedBox(height: 8),
            _buildSensorChart(
              title: "Gyroscope (X, Y, Z)",
              x: gyroX,
              y: gyroY,
              z: gyroZ,
            ),
            const SizedBox(height: 8),
            _buildSensorChart(
              title: "Magnetometer (X, Y, Z)",
              x: magX,
              y: magY,
              z: magZ,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateDuration(List<SensorReading> readings) {
    if (readings.length < 2) return "0s";
    final start = readings.first.timestamp;
    final end = readings.last.timestamp;
    final duration = end.difference(start);
    return "${duration.inSeconds}s";
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}