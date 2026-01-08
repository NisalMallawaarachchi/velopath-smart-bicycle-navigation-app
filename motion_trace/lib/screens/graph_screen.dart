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
    required IconData icon,
    required Color accentColor,
    required List<double> x,
    required List<double> y,
    required List<double> z,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval([...x, ...y, ...z]),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: x.isNotEmpty ? (x.length - 1).toDouble() : 0,
                minY: _getMinValue([...x, ...y, ...z]),
                maxY: _getMaxValue([...x, ...y, ...z]),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFFEF4444),
                    barWidth: 2,
                    spots: _toSpots(x),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 2,
                    spots: _toSpots(y),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 2,
                    spots: _toSpots(z),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(const Color(0xFFEF4444), "X"),
              const SizedBox(width: 20),
              _buildLegend(const Color(0xFF10B981), "Y"),
              const SizedBox(width: 20),
              _buildLegend(const Color(0xFF3B82F6), "Z"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$label Axis",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
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
    if (range == 0) return 1;
    return range / 5;
  }

  String _calculateDuration(List<SensorReading> readings) {
    if (readings.length < 2) return "0s";
    final start = readings.first.timestamp;
    final end = readings.last.timestamp;
    final duration = end.difference(start);
    return "${duration.inSeconds}s";
  }

  @override
  Widget build(BuildContext context) {
    final accelX = readings.map((r) => r.accelX).toList();
    final accelY = readings.map((r) => r.accelY).toList();
    final accelZ = readings.map((r) => r.accelZ).toList();

    final gyroX = readings.map((r) => r.gyroX).toList();
    final gyroY = readings.map((r) => r.gyroY).toList();
    final gyroZ = readings.map((r) => r.gyroZ).toList();

    final magX = readings.map((r) => r.magX).toList();
    final magY = readings.map((r) => r.magY).toList();
    final magZ = readings.map((r) => r.magZ).toList();

    // Count labels
    final labelCounts = <String, int>{};
    for (final r in readings) {
      labelCounts[r.label] = (labelCounts[r.label] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Session Analysis"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${readings.length} Data Points",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "Duration: ${_calculateDuration(readings)}",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (labelCounts.length > 1 || (labelCounts.length == 1 && !labelCounts.containsKey('smooth'))) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: labelCounts.entries.map((e) => 
                          _buildLabelStat(e.key, e.value),
                        ).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSensorChart(
              title: "Accelerometer",
              icon: Icons.speed,
              accentColor: const Color(0xFF10B981),
              x: accelX,
              y: accelY,
              z: accelZ,
            ),
            _buildSensorChart(
              title: "Gyroscope",
              icon: Icons.rotate_right,
              accentColor: const Color(0xFF3B82F6),
              x: gyroX,
              y: gyroY,
              z: gyroZ,
            ),
            _buildSensorChart(
              title: "Magnetometer",
              icon: Icons.explore,
              accentColor: const Color(0xFF8B5CF6),
              x: magX,
              y: magY,
              z: magZ,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelStat(String label, int count) {
    Color color;
    switch (label) {
      case 'pothole': color = const Color(0xFFEF4444); break;
      case 'bump': color = const Color(0xFFF59E0B); break;
      case 'rough': color = const Color(0xFFF97316); break;
      default: color = const Color(0xFF10B981);
    }
    
    return Column(
      children: [
        Text(
          "$count",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}