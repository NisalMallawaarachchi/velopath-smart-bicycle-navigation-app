import 'package:flutter/material.dart';
import 'package:motion_trace/services/sensor_service.dart';

class SensorStatusWidget extends StatelessWidget {
  final SensorService sensorService;

  const SensorStatusWidget({super.key, required this.sensorService});

  @override
  Widget build(BuildContext context) {
    final statusList = sensorService.getDetailedSensorStatus();
    final availableCount = statusList.where((s) => s.available).length;
    final totalCount = statusList.length;

    return Container(
      margin: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors,
                color: availableCount > 0 ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "Sensor Status",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: availableCount == totalCount 
                      ? Colors.green.shade50 
                      : availableCount > 0 
                          ? Colors.orange.shade50 
                          : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: availableCount == totalCount 
                        ? Colors.green.shade200 
                        : availableCount > 0 
                            ? Colors.orange.shade200 
                            : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  "$availableCount/$totalCount",
                  style: TextStyle(
                    color: availableCount == totalCount 
                        ? Colors.green.shade700 
                        : availableCount > 0 
                            ? Colors.orange.shade700 
                            : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusList.map((sensor) => _buildSensorChip(sensor)).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            sensorService.getSensorStatusSummary(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorChip(SensorStatus sensor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sensor.available ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sensor.available ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sensor.icon,
            color: sensor.available ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            sensor.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: sensor.available ? Colors.green.shade700 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}