import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/sensor_reading.dart';

/// Manages all sensor data collection for road hazard detection.
/// Collects accelerometer, gyroscope, magnetometer data at 200ms intervals
/// along with GPS coordinates.
class SensorService {
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;

  double ax = 0, ay = 0, az = 0;
  double gx = 0, gy = 0, gz = 0;
  double mx = 0, my = 0, mz = 0;

  bool isRecording = false;
  final List<SensorReading> readings = [];
  Timer? _recordingTimer;

  bool hasAccelerometer = false;
  bool hasGyroscope = false;
  bool hasMagnetometer = false;
  bool hasLocation = false;
  bool sensorsChecked = false;

  String _currentLabel = 'smooth';
  int _labelReadingsRemaining = 0;
  bool _isContinuousLabeling = false;
  static const int defaultLabelDuration = 10;

  String get currentLabel => _currentLabel;
  int get labelReadingsRemaining => _labelReadingsRemaining;
  bool get isLabelingActive =>
      _labelReadingsRemaining > 0 || _isContinuousLabeling;

  void markHazard(String hazardType,
      {int duration = defaultLabelDuration}) {
    _currentLabel = hazardType;
    _labelReadingsRemaining = duration;
    _isContinuousLabeling = false;
  }

  bool toggleContinuousLabeling(String hazardType) {
    if (_isContinuousLabeling && _currentLabel == hazardType) {
      _isContinuousLabeling = false;
      _currentLabel = 'smooth';
      _labelReadingsRemaining = 0;
      return false;
    } else {
      _isContinuousLabeling = true;
      _currentLabel = hazardType;
      _labelReadingsRemaining = 0;
      return true;
    }
  }

  void _resetLabel() {
    _currentLabel = 'smooth';
    _labelReadingsRemaining = 0;
    _isContinuousLabeling = false;
  }

  /// Check which sensors are available on the device
  Future<Map<String, bool>> checkSensors() async {
    try {
      try {
        final sub =
            accelerometerEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await sub.cancel();
        hasAccelerometer = true;
      } catch (e) {
        hasAccelerometer = false;
      }

      try {
        final sub = gyroscopeEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await sub.cancel();
        hasGyroscope = true;
      } catch (e) {
        hasGyroscope = false;
      }

      try {
        final sub =
            magnetometerEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await sub.cancel();
        hasMagnetometer = true;
      } catch (e) {
        hasMagnetometer = false;
      }

      try {
        hasLocation = await _isLocationAvailable()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        hasLocation = false;
      }

      sensorsChecked = true;

      return {
        'accelerometer': hasAccelerometer,
        'gyroscope': hasGyroscope,
        'magnetometer': hasMagnetometer,
        'location': hasLocation,
      };
    } catch (e) {
      sensorsChecked = true;
      return {
        'accelerometer': false,
        'gyroscope': false,
        'magnetometer': false,
        'location': false,
      };
    }
  }

  static Future<bool> _isLocationAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  String getSensorStatusSummary() {
    if (!sensorsChecked) return "Checking sensors...";
    final available = [
      if (hasAccelerometer) 'Accelerometer',
      if (hasGyroscope) 'Gyroscope',
      if (hasMagnetometer) 'Magnetometer',
      if (hasLocation) 'GPS',
    ];
    if (available.isEmpty) return "No sensors available";
    return "Available: ${available.join(', ')}";
  }

  List<SensorStatus> getDetailedSensorStatus() {
    return [
      SensorStatus(
          name: 'Accelerometer',
          available: hasAccelerometer,
          icon: Icons.speed,
          description: 'Measures acceleration forces'),
      SensorStatus(
          name: 'Gyroscope',
          available: hasGyroscope,
          icon: Icons.rotate_right,
          description: 'Measures orientation and rotation'),
      SensorStatus(
          name: 'Magnetometer',
          available: hasMagnetometer,
          icon: Icons.explore,
          description: 'Detects magnetic fields'),
      SensorStatus(
          name: 'GPS Location',
          available: hasLocation,
          icon: Icons.location_on,
          description: 'Provides location data'),
    ];
  }

  Future<void> startRecording() async {
    if (!hasAccelerometer && !hasGyroscope && !hasMagnetometer) {
      throw Exception("No motion sensors available for recording");
    }

    isRecording = true;
    readings.clear();
    _resetLabel();

    if (hasAccelerometer) {
      _accelSub = accelerometerEvents.listen((event) {
        ax = event.x; ay = event.y; az = event.z;
      }, cancelOnError: true);
    }

    if (hasGyroscope) {
      _gyroSub = gyroscopeEvents.listen((event) {
        gx = event.x; gy = event.y; gz = event.z;
      }, cancelOnError: true);
    }

    if (hasMagnetometer) {
      _magSub = magnetometerEvents.listen((event) {
        mx = event.x; my = event.y; mz = event.z;
      }, cancelOnError: true);
    }

    _recordingTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!isRecording) {
        timer.cancel();
        return;
      }

      double latitude = 0;
      double longitude = 0;

      if (hasLocation) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
          ).timeout(const Duration(seconds: 2));
          latitude = pos.latitude;
          longitude = pos.longitude;
        } catch (e) {
          // Location not available for this reading
        }
      }

      final labelForReading = _currentLabel;
      readings.add(SensorReading(
        timestamp: DateTime.now(),
        accelX: ax, accelY: ay, accelZ: az,
        gyroX: gx, gyroY: gy, gyroZ: gz,
        magX: mx, magY: my, magZ: mz,
        latitude: latitude, longitude: longitude,
        label: labelForReading,
      ));

      if (_labelReadingsRemaining > 0) {
        _labelReadingsRemaining--;
        if (_labelReadingsRemaining == 0) {
          _currentLabel = 'smooth';
        }
      }
    });
  }

  void stopRecording() {
    isRecording = false;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _resetLabel();
  }

  List<SensorReading> flushReadings() {
    final flushed = List<SensorReading>.from(readings);
    readings.clear();
    return flushed;
  }

  void dispose() {
    stopRecording();
  }
}

class SensorStatus {
  final String name;
  final bool available;
  final IconData icon;
  final String description;

  SensorStatus({
    required this.name,
    required this.available,
    required this.icon,
    required this.description,
  });
}
