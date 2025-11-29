import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:motion_trace/models/sensor_reading.dart';

class SensorChart extends StatefulWidget {
  final List<SensorReading> readings;
  final bool isLive;

  const SensorChart({
    super.key,
    required this.readings,
    this.isLive = false,
  });

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FlSpot> _toSpots(List<double> values) {
    return List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );
  }

  Widget _buildChart(List<double> x, List<double> y, List<double> z) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(show: false),
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

  @override
  Widget build(BuildContext context) {
    final accelX = widget.readings.map((r) => r.accelX).toList();
    final accelY = widget.readings.map((r) => r.accelY).toList();
    final accelZ = widget.readings.map((r) => r.accelZ).toList();

    final gyroX = widget.readings.map((r) => r.gyroX).toList();
    final gyroY = widget.readings.map((r) => r.gyroY).toList();
    final gyroZ = widget.readings.map((r) => r.gyroZ).toList();

    final magX = widget.readings.map((r) => r.magX).toList();
    final magY = widget.readings.map((r) => r.magY).toList();
    final magZ = widget.readings.map((r) => r.magZ).toList();

    return Column(
      children: [
        // Tab Bar with modern styling
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            tabs: const [
              Tab(text: "Accelerometer"),
              Tab(text: "Gyroscope"),
              Tab(text: "Magnetometer"),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Chart Area
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChart(accelX, accelY, accelZ),
              _buildChart(gyroX, gyroY, gyroZ),
              _buildChart(magX, magY, magZ),
            ],
          ),
        ),
        
        // Legend
        Container(
          padding: const EdgeInsets.all(8),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.red, label: "X Axis"),
              SizedBox(width: 16),
              _LegendDot(color: Colors.green, label: "Y Axis"),
              SizedBox(width: 16),
              _LegendDot(color: Colors.blue, label: "Z Axis"),
            ],
          ),
        ),
      ],
    );
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}