import 'dart:async';
import 'package:flutter/material.dart';
import 'package:motion_trace/models/sensor_reading.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'location_service.dart';

class SensorService {
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;

  double ax = 0, ay = 0, az = 0;
  double gx = 0, gy = 0, gz = 0;
  double mx = 0, my = 0, mz = 0;

  bool isRecording = false;
  final List<SensorReading> readings = [];

  // Sensor availability flags
  bool hasAccelerometer = false;
  bool hasGyroscope = false;
  bool hasMagnetometer = false;
  bool hasLocation = false;
  bool sensorsChecked = false;

  /// Check which sensors are available on the device
  Future<Map<String, bool>> checkSensors() async {
    try {
      // Test accelerometer
      try {
        final accelSubscription = accelerometerEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await accelSubscription.cancel();
        hasAccelerometer = true;
      } catch (e) {
        hasAccelerometer = false;
      }

      // Test gyroscope
      try {
        final gyroSubscription = gyroscopeEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await gyroSubscription.cancel();
        hasGyroscope = true;
      } catch (e) {
        hasGyroscope = false;
      }

      // Test magnetometer
      try {
        final magSubscription = magnetometerEvents.listen((event) {}, cancelOnError: true);
        await Future.delayed(const Duration(milliseconds: 100));
        await magSubscription.cancel();
        hasMagnetometer = true;
      } catch (e) {
        hasMagnetometer = false;
      }

      // Test location services using safer method
      try {
        hasLocation = await LocationService.isLocationAvailable().timeout(const Duration(seconds: 5));
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

  /// Get sensor status summary
  String getSensorStatusSummary() {
    if (!sensorsChecked) return "Checking sensors...";
    
    final availableSensors = [
      if (hasAccelerometer) 'Accelerometer',
      if (hasGyroscope) 'Gyroscope',
      if (hasMagnetometer) 'Magnetometer',
      if (hasLocation) 'GPS',
    ];
    
    if (availableSensors.isEmpty) return "No sensors available";
    return "Available: ${availableSensors.join(', ')}";
  }

  /// Get detailed sensor status
  List<SensorStatus> getDetailedSensorStatus() {
    return [
      SensorStatus(
        name: 'Accelerometer',
        available: hasAccelerometer,
        icon: Icons.speed,
        description: 'Measures acceleration forces',
      ),
      SensorStatus(
        name: 'Gyroscope',
        available: hasGyroscope,
        icon: Icons.rotate_right,
        description: 'Measures orientation and rotation',
      ),
      SensorStatus(
        name: 'Magnetometer',
        available: hasMagnetometer,
        icon: Icons.explore,
        description: 'Detects magnetic fields',
      ),
      SensorStatus(
        name: 'GPS Location',
        available: hasLocation,
        icon: Icons.location_on,
        description: 'Provides location data',
      ),
    ];
  }

  Future<void> startRecording() async {
    if (!hasAccelerometer && !hasGyroscope && !hasMagnetometer) {
      throw Exception("No motion sensors available for recording");
    }

    isRecording = true;
    readings.clear();

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

    Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!isRecording) {
        timer.cancel();
        return;
      }
      
      double latitude = 0;
      double longitude = 0;
      
      if (hasLocation) {
        try {
          final pos = await LocationService.getCurrentPosition().timeout(const Duration(seconds: 2));
          latitude = pos.latitude;
          longitude = pos.longitude;
        } catch (e) {
          // Location not available for this reading
        }
      }
      
      if (mounted) {
        readings.add(SensorReading(
          timestamp: DateTime.now(),
          accelX: ax, accelY: ay, accelZ: az,
          gyroX: gx, gyroY: gy, gyroZ: gz,
          magX: mx, magY: my, magZ: mz,
          latitude: latitude, longitude: longitude,
        ));
      }
    });
  }

  void stopRecording() {
    isRecording = false;
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
  }

  // Helper method to check if we're in a widget context
  bool get mounted => true;
}

/// Model for sensor status
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