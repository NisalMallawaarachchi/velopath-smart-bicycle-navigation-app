import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_trace/services/sensor_service.dart';
import 'package:motion_trace/services/storage_service.dart';
import 'package:motion_trace/services/api_service.dart';
import 'package:motion_trace/widgets/sensor_chart.dart';
import 'package:motion_trace/widgets/sensor_status_widget.dart';
import 'package:motion_trace/screens/session_list_screen.dart';
import 'package:motion_trace/screens/prediction_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SensorService sensorService = SensorService();
  bool isRecording = false;
  int dataPoints = 0;
  bool isLoadingSensors = true;

  @override
  void initState() {
    super.initState();
    _initializeSensors();
  }

  Future<void> _initializeSensors() async {
    await sensorService.checkSensors();
    setState(() => isLoadingSensors = false);
  }

  void _updateDataCount() {
    if (mounted && isRecording) {
      setState(() {
        dataPoints = sensorService.readings.length;
      });
    }
  }

  Future<void> _refreshSensors() async {
    setState(() => isLoadingSensors = true);
    await sensorService.checkSensors();
    setState(() => isLoadingSensors = false);
  }

  Future<void> _runDemoAnalysis() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Analyzing road data..."),
          ],
        ),
      ),
    );

    try {
      // Call backend API for demo prediction
      final result = await ApiService.getDemoPrediction();
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (result.success) {
        // Navigate to results screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PredictionResultScreen(result: result),
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Analysis failed: ${result.error}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "MotionTrace",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white),
            tooltip: "Demo Analyze",
            onPressed: _runDemoAnalysis,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Sensors",
            onPressed: isLoadingSensors ? null : _refreshSensors,
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: "View Sessions",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionListScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoadingSensors
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Checking available sensors...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Sensor Status Widget
                          SensorStatusWidget(sensorService: sensorService),

                          // Header Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF1D4ED8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isRecording ? Icons.sensors : Icons.sensors_off,
                                  size: 48,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isRecording ? "Recording Active" : "Ready to Record",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isRecording 
                                      ? "$dataPoints data points captured"
                                      : "Start capturing sensor data",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Control Section
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ElevatedButton.icon(
                                  icon: Icon(
                                    isRecording ? Icons.stop_circle : Icons.play_circle_fill,
                                    size: 24,
                                  ),
                                  label: Text(
                                    isRecording ? "STOP RECORDING" : "START RECORDING",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (isRecording) {
                                      sensorService.stopRecording();
                                      await StorageService.saveSession(
                                        DateTime.now().toString(),
                                        sensorService.readings,
                                      );
                                      setState(() {
                                        isRecording = false;
                                        dataPoints = 0;
                                      });
                                    } else {
                                      // Check if any sensors are available
                                      final availableSensors = [
                                        sensorService.hasAccelerometer,
                                        sensorService.hasGyroscope,
                                        sensorService.hasMagnetometer,
                                      ].any((element) => element);

                                      if (!availableSensors) {
                                        _showNoSensorsDialog();
                                        return;
                                      }

                                      await sensorService.startRecording();
                                      setState(() => isRecording = true);
                                      
                                      Timer.periodic(const Duration(milliseconds: 500), (timer) {
                                        if (!isRecording) {
                                          timer.cancel();
                                          return;
                                        }
                                        _updateDataCount();
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRecording ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (isRecording) ...[
                                  const LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Recording in progress...",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Data Visualization Section
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: sensorService.readings.isEmpty
                                  ? _buildEmptyState()
                                  : _buildChartSection(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_graph,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              "No Data Yet",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Start recording to see real-time sensor data visualization",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                "Live Data",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SensorChart(
              readings: sensorService.readings,
              isLive: isRecording,
            ),
          ),
        ),
      ],
    );
  }

  void _showNoSensorsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text("No Sensors Available"),
          ],
        ),
        content: const Text(
          "No motion sensors were detected on your device. "
          "The app requires at least one motion sensor (accelerometer, gyroscope, or magnetometer) to record data.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshSensors();
            },
            child: const Text("Retry Detection"),
          ),
        ],
      ),
    );
  }
}