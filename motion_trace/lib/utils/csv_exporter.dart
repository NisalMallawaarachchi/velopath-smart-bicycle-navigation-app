import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:motion_trace/models/sensor_reading.dart';

class CSVExporter {
  static Future<void> exportToCSV(List<SensorReading> readings, String sessionId) async {
    // Convert to rows
    final rows = [
      [
        'timestamp',
        'accelX',
        'accelY',
        'accelZ',
        'gyroX',
        'gyroY',
        'gyroZ',
        'magX',
        'magY',
        'magZ',
        'latitude',
        'longitude'
      ],
      ...readings.map((r) => [
            r.timestamp.toIso8601String(),
            r.accelX,
            r.accelY,
            r.accelZ,
            r.gyroX,
            r.gyroY,
            r.gyroZ,
            r.magX,
            r.magY,
            r.magZ,
            r.latitude,
            r.longitude,
          ])
    ];

    // Convert to CSV
    String csvData = const ListToCsvConverter().convert(rows);

    // Save location
    final directory = await getExternalStorageDirectory();
    final folder = Directory('${directory!.path}/MotionTraceExports');

    // Create folder if not exists
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    // Save file
    final file = File('${folder.path}/session_$sessionId.csv');
    await file.writeAsString(csvData);

    print('✅ CSV Exported to: ${file.path}');
  }
}
