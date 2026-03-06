import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/background_sensor_service.dart';
import '../services/sensor_service.dart';

/// Provider for Motion Trace sensor tracking state.
/// Handles runtime permissions flow:
///   1. After first login → request all sensor permissions
///   2. Before Start Ride → verify all permissions granted
class MotionTraceProvider extends ChangeNotifier {
  final BackgroundSensorService _bgService = BackgroundSensorService();

  bool _isInitialized = false;
  bool _isTracking = false;
  int _readingCount = 0;
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  bool _consentGiven = false;

  // Permission states
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _sensorsGranted = false;
  bool _allPermissionsGranted = false;

  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  int get readingCount => _readingCount;
  String get statusMessage => _statusMessage;
  bool get hasError => _hasError;
  bool get consentGiven => _consentGiven;
  bool get allPermissionsGranted => _allPermissionsGranted;
  bool get locationGranted => _locationGranted;
  bool get notificationGranted => _notificationGranted;
  bool get sensorsGranted => _sensorsGranted;
  SensorService get sensorService => _bgService.sensorService;

  /// Initialize — called on app startup
  Future<void> initialize() async {
    try {
      await _bgService.initialize();
      await _checkCurrentPermissions();
      _isInitialized = true;
      _statusMessage = _bgService.sensorService.getSensorStatusSummary();
      _hasError = false;
    } catch (e) {
      _statusMessage = 'Initialization failed: $e';
      _hasError = true;
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // PERMISSION HANDLING
  // ─────────────────────────────────────────────

  /// Check current permission status without requesting
  Future<void> _checkCurrentPermissions() async {
    _locationGranted = await Permission.locationWhenInUse.isGranted;
    _notificationGranted = await Permission.notification.isGranted;
    _sensorsGranted = await Permission.sensors.isGranted ||
        await Permission.sensors.status.then((s) => s.isGranted || s.isLimited);
    _allPermissionsGranted =
        _locationGranted && _notificationGranted && _sensorsGranted;
  }

  /// Request all permissions after first login.
  /// Shows a dialog explaining why we need them, then requests each one.
  Future<bool> requestPermissionsAfterLogin(BuildContext context) async {
    // Show explanation dialog first
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF184652), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Permissions Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VeloPath needs the following permissions to detect road hazards and keep you safe:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.location_on,
              title: 'Location',
              desc: 'GPS coordinates for mapping road conditions',
            ),
            SizedBox(height: 10),
            _PermissionRow(
              icon: Icons.sensors,
              title: 'Motion Sensors',
              desc: 'Accelerometer, gyroscope to detect potholes & bumps',
            ),
            SizedBox(height: 10),
            _PermissionRow(
              icon: Icons.notifications,
              title: 'Notifications',
              desc: 'Show tracking status while collecting data',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF184652),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );

    if (proceed != true) return false;

    // Request each permission
    await _requestAllPermissions();
    notifyListeners();
    return _allPermissionsGranted;
  }

  /// Request all runtime permissions
  Future<void> _requestAllPermissions() async {
    // 1. Location
    var locStatus = await Permission.locationWhenInUse.request();
    _locationGranted = locStatus.isGranted;

    // 2. Sensors (Android 13+)
    var sensorStatus = await Permission.sensors.request();
    _sensorsGranted = sensorStatus.isGranted || sensorStatus.isLimited;

    // 3. Notifications (Android 13+)
    var notifStatus = await Permission.notification.request();
    _notificationGranted = notifStatus.isGranted;

    _allPermissionsGranted =
        _locationGranted && _notificationGranted && _sensorsGranted;
  }

  /// Verify all permissions are granted before starting a ride.
  /// If any are missing, shows dialog and requests them again.
  Future<bool> ensurePermissionsForRide(BuildContext context) async {
    await _checkCurrentPermissions();

    if (_allPermissionsGranted) return true;

    // Show which permissions are missing
    final missing = <String>[];
    if (!_locationGranted) missing.add('Location');
    if (!_sensorsGranted) missing.add('Motion Sensors');
    if (!_notificationGranted) missing.add('Notifications');

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Permissions Needed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To start a ride with road tracking, all sensor permissions must be granted.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text('Missing permissions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            ...missing.map((p) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(p, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              'Please grant all permissions to enable hazard detection.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip Tracking',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF184652),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Grant Now'),
          ),
        ],
      ),
    );

    if (retry == true) {
      await _requestAllPermissions();

      // If still denied, open app settings
      if (!_allPermissionsGranted) {
        await openAppSettings();
        // Re-check after coming back
        await Future.delayed(const Duration(seconds: 1));
        await _checkCurrentPermissions();
      }
      notifyListeners();
    }

    return _allPermissionsGranted;
  }

  // ─────────────────────────────────────────────
  // CONSENT & TRACKING
  // ─────────────────────────────────────────────

  void setConsent(bool consent) {
    _consentGiven = consent;
    notifyListeners();
  }

  /// Show data collection consent dialog (separate from permissions)
  Future<bool> requestDataCollectionConsent(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: Color(0xFF184652), size: 28),
            SizedBox(width: 10),
            Text('Road Data Collection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VeloPath will collect road condition data using your device sensors while you ride.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text('Data collected:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('• Accelerometer, gyroscope & magnetometer'),
            Text('• GPS location coordinates'),
            SizedBox(height: 12),
            Text(
              'This data helps detect road hazards like potholes and bumps, making routes safer for all cyclists.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Deny', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF184652),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (result == true) {
      _consentGiven = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Full flow: check permissions → get consent → start tracking
  Future<bool> requestConsentAndStart(BuildContext context) async {
    // Step 1: Ensure all permissions
    final permsOk = await ensurePermissionsForRide(context);
    if (!permsOk) return false;

    // Step 2: Get data collection consent if not given
    if (!_consentGiven) {
      final consented = await requestDataCollectionConsent(context);
      if (!consented) return false;
    }

    // Step 3: Start tracking
    return await startTracking();
  }

  Future<bool> startTracking() async {
    if (!_isInitialized) {
      _statusMessage = 'Not initialized yet';
      notifyListeners();
      return false;
    }
    if (!_allPermissionsGranted) {
      _statusMessage = 'Permissions required';
      notifyListeners();
      return false;
    }
    if (!_consentGiven) {
      _statusMessage = 'User consent required';
      notifyListeners();
      return false;
    }

    try {
      final success = await _bgService.startTracking();
      if (success) {
        _isTracking = true;
        _readingCount = 0;
        _statusMessage = 'Collecting road data...';
        _hasError = false;
        _pollReadingCount();
      } else {
        _statusMessage = 'Failed to start tracking';
        _hasError = true;
      }
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error: $e';
      _hasError = true;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopTracking() async {
    try {
      await _bgService.stopTracking();
      _isTracking = false;
      _statusMessage = 'Tracking stopped. $_readingCount readings collected.';
      _hasError = false;
    } catch (e) {
      _statusMessage = 'Error stopping: $e';
      _hasError = true;
    }
    notifyListeners();
  }

  void _pollReadingCount() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isTracking) return false;
      _readingCount =
          _bgService.totalReadings + _bgService.sensorService.readings.length;
      _statusMessage = 'Collecting... $_readingCount readings';
      notifyListeners();
      return _isTracking;
    });
  }

  List<SensorStatus> getDetailedSensorStatus() {
    return _bgService.sensorService.getDetailedSensorStatus();
  }

  @override
  void dispose() {
    _bgService.dispose();
    super.dispose();
  }
}

/// Helper widget for permission explanation dialog
class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF184652), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(desc,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
