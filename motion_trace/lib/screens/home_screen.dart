import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motion_trace/services/sensor_service.dart';
import 'package:motion_trace/services/storage_service.dart';
import 'package:motion_trace/services/api_service.dart';
import 'package:motion_trace/widgets/sensor_chart.dart';
import 'package:motion_trace/screens/session_list_screen.dart';
import 'package:motion_trace/screens/prediction_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final SensorService sensorService = SensorService();
  bool isRecording = false;
  int dataPoints = 0;
  bool isLoadingSensors = true;
  Timer? _uiUpdateTimer;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _initializeSensors();
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _initializeSensors() async {
    await sensorService.checkSensors();
    if (mounted) setState(() => isLoadingSensors = false);
  }

  void _startUIUpdates() {
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!isRecording) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          dataPoints = sensorService.readings.length;
        });
      }
    });
  }

  Future<void> _toggleRecording() async {
    HapticFeedback.mediumImpact();
    
    if (isRecording) {
      sensorService.stopRecording();
      _uiUpdateTimer?.cancel();
      await StorageService.saveSession(
        DateTime.now().toIso8601String(),
        sensorService.readings,
      );
      setState(() {
        isRecording = false;
        dataPoints = 0;
      });
      _showSessionSavedDialog();
    } else {
      final availableSensors = [
        sensorService.hasAccelerometer,
        sensorService.hasGyroscope,
        sensorService.hasMagnetometer,
      ].any((e) => e);

      if (!availableSensors) {
        _showNoSensorsDialog();
        return;
      }

      await sensorService.startRecording();
      setState(() => isRecording = true);
      _startUIUpdates();
    }
  }

  void _markHazard(String hazardType) {
    HapticFeedback.heavyImpact();
    
    // For rough roads, use toggle mode
    if (hazardType == 'rough') {
      sensorService.toggleContinuousLabeling(hazardType);
    } else {
      sensorService.markHazard(hazardType);
    }
    
    setState(() {});
  }

  void _showSessionSavedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            const Text("Session Saved", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          "Your ride data has been saved. You can view it in Sessions or upload to the server for analysis.",
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionListScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text("View Sessions", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNoSensorsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sensors_off, color: Color(0xFFEF4444)),
            ),
            const SizedBox(width: 12),
            const Text("No Sensors", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          "No motion sensors detected. Please ensure your device has an accelerometer or gyroscope.",
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoadingSensors ? _buildLoadingScreen() : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + (_pulseController.value * 0.1),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.directions_bike, size: 40, color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "VeloTrace",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Initializing sensors...",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildRecordButton(),
                if (isRecording) ...[
                  const SizedBox(height: 16),
                  _buildHazardButtons(),
                ],
                const SizedBox(height: 20),
                _buildSensorMetrics(),
                if (sensorService.readings.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildLiveChart(),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "VeloTrace",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                "Road Hazard Detection",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
          Row(
            children: [
              _buildHeaderButton(Icons.analytics_outlined, () => _runDemoAnalysis()),
              const SizedBox(width: 8),
              _buildHeaderButton(Icons.folder_outlined, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionListScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Icon(icon, color: Colors.grey.shade400, size: 22),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isRecording
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecording ? Colors.transparent : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (isRecording) ...[
                    ...List.generate(3, (index) {
                      final delay = index * 0.3;
                      final value = ((_waveController.value + delay) % 1.0);
                      return Container(
                        width: 60 + (value * 40),
                        height: 60 + (value * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3 * (1 - value)),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ],
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.white.withOpacity(0.2) : const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRecording ? Icons.sensors : Icons.pedal_bike,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            isRecording ? "Recording Active" : "Ready to Record",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(Icons.data_usage, "$dataPoints pts"),
                const SizedBox(width: 12),
                _buildStatChip(Icons.timer_outlined, "${(dataPoints * 0.2).toStringAsFixed(1)}s"),
              ],
            )
          else
            Text(
              "Mount your phone and start cycling",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isRecording
              ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
              : const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              isRecording ? "STOP RECORDING" : "START RECORDING",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sensorService.isLabelingActive
              ? _getHazardColor(sensorService.currentLabel).withOpacity(0.5)
              : const Color(0xFF334155),
          width: sensorService.isLabelingActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: 18,
                color: sensorService.isLabelingActive
                    ? _getHazardColor(sensorService.currentLabel)
                    : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                "TAP WHEN YOU HIT A HAZARD",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (sensorService.isLabelingActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getHazardColor(sensorService.currentLabel).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sensorService.isContinuousLabeling)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _getHazardColor(sensorService.currentLabel),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        sensorService.isContinuousLabeling
                            ? "${sensorService.currentLabel.toUpperCase()} ●"
                            : "${sensorService.currentLabel.toUpperCase()} (${sensorService.labelReadingsRemaining})",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getHazardColor(sensorService.currentLabel),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHazardButton("pothole", "Pothole", Icons.warning_rounded, Colors.red, false)),
              const SizedBox(width: 10),
              Expanded(child: _buildHazardButton("bump", "Bump", Icons.terrain, Colors.orange, false)),
              const SizedBox(width: 10),
              Expanded(child: _buildRoughToggleButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHazardButton(String type, String label, IconData icon, MaterialColor color, bool isToggle) {
    final isActive = sensorService.currentLabel == type && sensorService.isLabelingActive;
    return GestureDetector(
      onTap: () => _markHazard(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? color.shade700 : color.shade900.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color.shade400 : color.shade700.withOpacity(0.5),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : color.shade300, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : color.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoughToggleButton() {
    final isActive = sensorService.currentLabel == 'rough' && sensorService.isContinuousLabeling;
    final color = Colors.amber;
    
    return GestureDetector(
      onTap: () => _markHazard('rough'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.shade700 : color.shade900.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color.shade400 : color.shade700.withOpacity(0.5),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.grain, color: isActive ? Colors.white : color.shade300, size: 24),
            const SizedBox(height: 4),
            Text(
              isActive ? "STOP" : "Rough",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : color.shade300,
              ),
            ),
            Text(
              isActive ? "●REC" : "START/END",
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white.withOpacity(0.8) : color.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            "Accelerometer",
            sensorService.hasAccelerometer ? "Active" : "N/A",
            Icons.speed,
            sensorService.hasAccelerometer ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "Gyroscope",
            sensorService.hasGyroscope ? "Active" : "N/A",
            Icons.rotate_right,
            sensorService.hasGyroscope ? const Color(0xFF3B82F6) : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "GPS",
            sensorService.hasLocation ? "Active" : "N/A",
            Icons.location_on,
            sensorService.hasLocation ? const Color(0xFF8B5CF6) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color == Colors.grey ? Colors.grey : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Live Sensor Data",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isRecording ? const Color(0xFF10B981) : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isRecording ? "LIVE" : "PAUSED",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isRecording ? const Color(0xFF10B981) : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SensorChart(readings: sensorService.readings, isLive: isRecording),
          ),
        ],
      ),
    );
  }

  Color _getHazardColor(String hazardType) {
    switch (hazardType) {
      case 'pothole': return Colors.red.shade600;
      case 'bump': return Colors.orange.shade600;
      case 'rough': return Colors.amber.shade600;
      default: return Colors.green.shade600;
    }
  }

  Future<void> _runDemoAnalysis() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(width: 20),
            Text("Analyzing...", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final result = await ApiService.getDemoPrediction();
      if (mounted) Navigator.pop(context);

      if (result.success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PredictionResultScreen(result: result)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Analysis failed: ${result.error}"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }
}