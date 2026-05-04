// calibration_screen.dart
// Per-device accelerometer calibration.
//
// How it works:
//   1. User places phone flat on a level surface.
//   2. App records 50 accelerometer readings over 10 seconds (5 Hz).
//   3. Mean X/Y are the horizontal bias; mean Z - 9.81 is the vertical bias.
//   4. Offsets stored in SharedPreferences and sent with every /predict call.
//
// Why this matters:
//   Different Android phones have different accelerometer zero-offsets (hardware
//   manufacturing variance). Without calibration, a phone that reads accelZ = 9.95
//   at rest will make a smooth road look like a rough road to the ML model.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const int _totalReadings = 50;
  static const double _gravity    = 9.81;

  _Phase _phase = _Phase.instructions;
  int    _count = 0;

  final List<double> _xs = [], _ys = [], _zs = [];
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _timer;

  double? _biasX, _biasY, _biasZ;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _phase = _Phase.recording;
      _count = 0;
      _xs.clear(); _ys.clear(); _zs.clear();
    });

    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) {
      if (_count >= _totalReadings) return;
      _xs.add(e.x); _ys.add(e.y); _zs.add(e.z);
      setState(() => _count++);
      if (_count >= _totalReadings) _finishRecording();
    });
  }

  void _finishRecording() {
    _sub?.cancel();

    final meanX = _xs.reduce((a, b) => a + b) / _xs.length;
    final meanY = _ys.reduce((a, b) => a + b) / _ys.length;
    final meanZ = _zs.reduce((a, b) => a + b) / _zs.length;

    // Bias = deviation from expected value
    // Expected: accelX ≈ 0, accelY ≈ 0, accelZ ≈ +9.81
    _biasX = meanX;
    _biasY = meanY;
    _biasZ = meanZ - _gravity;

    _saveCalibration();
    setState(() => _phase = _Phase.done);
  }

  Future<void> _saveCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('calib_bias_x', _biasX!);
    await prefs.setDouble('calib_bias_y', _biasY!);
    await prefs.setDouble('calib_bias_z', _biasZ!);
    await prefs.setInt('calib_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, double>?> loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final bx = prefs.getDouble('calib_bias_x');
    final by = prefs.getDouble('calib_bias_y');
    final bz = prefs.getDouble('calib_bias_z');
    if (bx == null || by == null || bz == null) return null;
    return {'bias_x': bx, 'bias_y': by, 'bias_z': bz};
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF0E417A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Calibration'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(primary),
        ),
      ),
    );
  }

  Widget _buildBody(Color primary) {
    switch (_phase) {
      case _Phase.instructions:
        return _Instructions(
          onStart: _startRecording,
          primary: primary,
        );
      case _Phase.recording:
        return _Recording(
          count: _count,
          total: _totalReadings,
          primary: primary,
        );
      case _Phase.done:
        return _Done(
          biasX: _biasX!,
          biasY: _biasY!,
          biasZ: _biasZ!,
          onClose: () => Navigator.pop(context),
          primary: primary,
        );
    }
  }
}

// ── Phases ────────────────────────────────────────────────────────────────────

enum _Phase { instructions, recording, done }

class _Instructions extends StatelessWidget {
  const _Instructions({required this.onStart, required this.primary});
  final VoidCallback onStart;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.phonelink_setup, size: 80, color: primary),
        const SizedBox(height: 32),
        const Text(
          'Calibrate Your Phone',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Place your phone on a flat, level surface.\n\n'
          'The app will record 50 accelerometer readings to measure your '
          'phone\'s hardware zero-offset. This makes hazard detection more '
          'accurate regardless of which phone you use.',
          style: TextStyle(fontSize: 15, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.tune),
            label: const Text('Start Calibration', style: TextStyle(fontSize: 17)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _Recording extends StatelessWidget {
  const _Recording({required this.count, required this.total, required this.primary});
  final int count, total;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final progress = count / total;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140, height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: Colors.grey.shade200,
                color: primary,
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Recording… $count / $total readings',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        const Text(
          'Keep the phone flat and still.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.biasX,
    required this.biasY,
    required this.biasZ,
    required this.onClose,
    required this.primary,
  });
  final double biasX, biasY, biasZ;
  final VoidCallback onClose;
  final Color primary;

  String _fmt(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(4)} m/s²';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 80, color: Colors.green.shade600),
        const SizedBox(height: 24),
        const Text(
          'Calibration Complete',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'These offsets will be subtracted from all sensor readings before '
          'hazard detection.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        _BiasRow(label: 'X bias', value: _fmt(biasX)),
        _BiasRow(label: 'Y bias', value: _fmt(biasY)),
        _BiasRow(label: 'Z bias', value: _fmt(biasZ)),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onClose,
            child: const Text('Done', style: TextStyle(fontSize: 17)),
          ),
        ),
      ],
    );
  }
}

class _BiasRow extends StatelessWidget {
  const _BiasRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value,  style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
