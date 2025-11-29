import 'package:hive_flutter/hive_flutter.dart';
import 'package:motion_trace/models/sensor_reading.dart';

class StorageService {
  static const _boxName = 'sensor_data';

  /// Initialize Hive and open the storage box
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  /// Save a session with all sensor readings
  static Future<void> saveSession(String sessionId, List<SensorReading> data) async {
    final box = Hive.box(_boxName);
    await box.put(sessionId, data.map((e) => e.toJson()).toList());
  }

  /// Get all session IDs stored in Hive
  static List<String> getAllSessionKeys() {
    final box = Hive.box(_boxName);
    return box.keys.cast<String>().toList();
  }

  /// Get all SensorReading objects for a given session ID
  static List<SensorReading> getSessionData(String sessionId) {
    final box = Hive.box(_boxName);
    final rawList = box.get(sessionId, defaultValue: []) as List;
    return rawList.map((e) => SensorReading.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Get all stored sessions combined (optional)
  static List<Map<String, dynamic>> getSessions() {
    final box = Hive.box(_boxName);
    return box.values
        .cast<List>()
        .expand((i) => i.cast<Map<String, dynamic>>())
        .toList();
  }

  /// Delete a specific session
  static Future<void> deleteSession(String sessionId) async {
    final box = Hive.box(_boxName);
    await box.delete(sessionId);
  }

  /// Clear all stored sessions
  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}
