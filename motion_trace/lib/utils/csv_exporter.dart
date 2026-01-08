import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:motion_trace/models/sensor_reading.dart';

class CSVExporter {
  /// Get the Downloads directory path
  static Future<Directory> _getDownloadsDirectory() async {
    // On Android, try to get the Downloads folder
    if (Platform.isAndroid) {
      // Try the common Downloads path first
      final downloadPath = Directory('/storage/emulated/0/Download');
      if (await downloadPath.exists()) {
        return downloadPath;
      }
      
      // Alternative path
      final altDownloadPath = Directory('/storage/emulated/0/Downloads');
      if (await altDownloadPath.exists()) {
        return altDownloadPath;
      }
    }
    
    // Fallback to getDownloadsDirectory() from path_provider
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return downloadsDir;
    }
    
    // Final fallback to external storage
    final extDir = await getExternalStorageDirectory();
    return extDir!;
  }

  static Future<String> exportToCSV(List<SensorReading> readings, String sessionId) async {
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
        'longitude',
        'label'
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
            r.label,
          ])
    ];

    // Convert to CSV
    String csvData = const ListToCsvConverter().convert(rows);

    // Get Downloads directory
    final downloadsDir = await _getDownloadsDirectory();
    
    // Create MotionTrace subfolder in Downloads
    final folder = Directory('${downloadsDir.path}/MotionTrace');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    // Create a clean filename with timestamp
    final timestamp = DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19);
    final filename = 'motion_trace_$timestamp.csv';
    
    // Save file
    final file = File('${folder.path}/$filename');
    await file.writeAsString(csvData);

    print('✅ CSV Exported to: ${file.path}');
    return file.path;
  }
}

