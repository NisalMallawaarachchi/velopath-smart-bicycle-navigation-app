import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sensor_service.dart';
import 'sensor_storage_service.dart';
import 'hazard_api_service.dart';
import '../models/sensor_reading.dart';

/// Wraps sensor collection with a persistent notification and periodic uploads.
class BackgroundSensorService {
  static final BackgroundSensorService _instance =
      BackgroundSensorService._internal();
  factory BackgroundSensorService() => _instance;
  BackgroundSensorService._internal();

  static const String _notificationChannelId = 'velopath_sensor_channel';
  static const String _notificationChannelName = 'VeloPath Road Tracking';
  static const int _notificationId = 888;
  static const int _uploadIntervalMinutes = 5;

  final SensorService _sensorService = SensorService();
  Timer? _uploadTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _isRunning = false;
  String? _currentSessionId;
  int _totalReadings = 0;

  bool get isRunning => _isRunning;
  String? get currentSessionId => _currentSessionId;
  int get totalReadings => _totalReadings;
  SensorService get sensorService => _sensorService;

  Future<void> initialize() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Notification for VeloPath road data collection',
      importance: Importance.low,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _sensorService.checkSensors();

    // Listen for connectivity changes to sync pending data
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (hasConnection) {
        syncPendingData();
      }
    });

    // Try to sync any pending sessions from previous rides
    syncPendingData();
  }

  Future<bool> startTracking() async {
    if (_isRunning) return true;
    try {
      _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _totalReadings = 0;
      await _sensorService.startRecording();
      _isRunning = true;
      await _showTrackingNotification();

      _uploadTimer = Timer.periodic(
        Duration(minutes: _uploadIntervalMinutes),
        (_) => _periodicUpload(),
      );

      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!_isRunning) { timer.cancel(); return; }
        _saveToLocal();
      });

      return true;
    } catch (e) {
      _isRunning = false;
      debugPrint('Failed to start tracking: $e');
      return false;
    }
  }

  Future<void> stopTracking({bool uploadOnStop = true}) async {
    if (!_isRunning) return;
    _isRunning = false;
    _sensorService.stopRecording();
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _saveToLocal();
    await _cancelNotification();
    if (uploadOnStop && _currentSessionId != null) {
      await _uploadSession();
    }
  }

  Future<void> _saveToLocal() async {
    if (_currentSessionId == null) return;
    final readings = _sensorService.flushReadings();
    if (readings.isEmpty) return;
    _totalReadings += readings.length;
    try {
      await SensorStorageService.appendToSession(_currentSessionId!, readings);
    } catch (e) {
      _sensorService.readings.addAll(readings);
    }
  }

  /// Check if there is internet connectivity
  Future<bool> _hasConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }

  Future<void> _periodicUpload() async {
    if (_currentSessionId == null) return;
    await _saveToLocal();
    if (await _hasConnectivity()) {
      await _uploadSession();
    } else {
      debugPrint('[BackgroundSensor] No connectivity, data saved locally');
    }
  }

  Future<void> _uploadSession() async {
    if (_currentSessionId == null) return;
    try {
      final readings = SensorStorageService.getSessionData(_currentSessionId!);
      if (readings.isEmpty) return;
      final result = await HazardApiService.uploadSession(readings, 'predict');
      if (result.success) {
        // Clear local data after successful upload
        await SensorStorageService.deleteSession(_currentSessionId!);
        debugPrint('[BackgroundSensor] Upload successful, local data cleared');
      }
    } catch (e) {
      debugPrint('[BackgroundSensor] Upload error (will retry): $e');
    }
  }

  /// Sync any pending locally-stored sessions (from offline rides)
  Future<void> syncPendingData() async {
    if (!await _hasConnectivity()) return;
    try {
      final sessionKeys = SensorStorageService.getAllSessionKeys();
      if (sessionKeys.isEmpty) return;
      debugPrint('[BackgroundSensor] Syncing ${sessionKeys.length} pending sessions...');
      for (final key in sessionKeys) {
        // Skip the active session — it's still collecting
        if (key == _currentSessionId && _isRunning) continue;
        final readings = SensorStorageService.getSessionData(key);
        if (readings.isEmpty) {
          await SensorStorageService.deleteSession(key);
          continue;
        }
        try {
          final result = await HazardApiService.uploadSession(readings, 'predict');
          if (result.success) {
            await SensorStorageService.deleteSession(key);
            debugPrint('[BackgroundSensor] Synced session $key');
          }
        } catch (e) {
          debugPrint('[BackgroundSensor] Failed to sync session $key: $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSensor] Sync error: $e');
    }
  }

  Future<void> _showTrackingNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const details = AndroidNotificationDetails(
      _notificationChannelId, _notificationChannelName,
      channelDescription: 'VeloPath is collecting road condition data',
      importance: Importance.low, priority: Priority.low,
      ongoing: true, autoCancel: false, icon: '@mipmap/ic_launcher',
    );
    await plugin.show(_notificationId, 'VeloPath Road Tracking',
        'Collecting road condition data...', const NotificationDetails(android: details));
  }

  Future<void> _cancelNotification() async {
    await FlutterLocalNotificationsPlugin().cancel(_notificationId);
  }

  void dispose() {
    _connectivitySub?.cancel();
    stopTracking(uploadOnStop: false);
  }
}
