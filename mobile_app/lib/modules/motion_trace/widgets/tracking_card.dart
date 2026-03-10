import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/motion_trace_provider.dart';
import '../services/sensor_service.dart';

/// Dashboard card widget for road condition tracking.
/// Shows permission status, sensor status, start/stop controls, and reading count.
class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MotionTraceProvider>(
      builder: (context, provider, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: provider.isTracking
                  ? const Color(0xFF184652)
                  : Colors.grey.shade300,
              width: provider.isTracking ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.15),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    provider.isTracking
                        ? Icons.sensors_rounded
                        : Icons.sensors_off,
                    color: provider.isTracking
                        ? const Color(0xFF184652)
                        : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Road Condition Tracking',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.isTracking
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isTracking
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.isTracking ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: provider.isTracking
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Permission status
              if (!provider.allPermissionsGranted && provider.isInitialized) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Permissions needed',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                              _getMissingPermissionsText(provider),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            provider.requestPermissionsAfterLogin(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF184652),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Grant',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Status message
              Text(
                provider.statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: provider.hasError
                      ? Colors.red.shade700
                      : Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 8),

              // Sensor status chips
              if (provider.isInitialized) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: provider
                      .getDetailedSensorStatus()
                      .map((sensor) => _sensorChip(sensor))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Reading count when tracking
              if (provider.isTracking) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.data_usage,
                          size: 18, color: Color(0xFF184652)),
                      const SizedBox(width: 6),
                      Text(
                        '${provider.readingCount} readings collected',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF184652),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Start / Stop button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.isInitialized
                      ? () => _onToggleTracking(context, provider)
                      : null,
                  icon: Icon(
                      provider.isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    provider.isTracking
                        ? 'Stop Tracking'
                        : 'Start Road Tracking',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.isTracking
                        ? Colors.red.shade700
                        : const Color(0xFF184652),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getMissingPermissionsText(MotionTraceProvider provider) {
    final missing = <String>[];
    if (!provider.locationGranted) missing.add('Location');
    if (!provider.sensorsGranted) missing.add('Sensors');
    if (!provider.notificationGranted) missing.add('Notifications');
    return 'Missing: ${missing.join(', ')}';
  }

  Widget _sensorChip(SensorStatus sensor) {
    return Chip(
      avatar: Icon(sensor.icon, size: 16,
          color: sensor.available ? Colors.green : Colors.red),
      label: Text(sensor.name, style: const TextStyle(fontSize: 11)),
      backgroundColor:
          sensor.available ? Colors.green.shade50 : Colors.red.shade50,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _onToggleTracking(
      BuildContext context, MotionTraceProvider provider) async {
    if (provider.isTracking) {
      await provider.stopTracking();
    } else {
      // Full flow: permissions → consent → start
      await provider.requestConsentAndStart(context);
    }
  }
}
