import 'package:hive_flutter/hive_flutter.dart';
import '../models/sensor_reading.dart';

/// Manages local data persistence for sensor sessions using Hive.
class SensorStorageService {
  static const _boxName = 'motion_trace_data';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Future<void> saveSession(
      String sessionId, List<SensorReading> data) async {
    final box = Hive.box(_boxName);
    await box.put(sessionId, data.map((e) => e.toJson()).toList());
  }

  static Future<void> appendToSession(
      String sessionId, List<SensorReading> newData) async {
    final box = Hive.box(_boxName);
    final existing = box.get(sessionId, defaultValue: []) as List;
    final combined = [
      ...existing,
      ...newData.map((e) => e.toJson()),
    ];
    await box.put(sessionId, combined);
  }

  static List<String> getAllSessionKeys() {
    final box = Hive.box(_boxName);
    return box.keys.cast<String>().toList();
  }

  static List<SensorReading> getSessionData(String sessionId) {
    final box = Hive.box(_boxName);
    final rawList = box.get(sessionId, defaultValue: []) as List;
    return rawList
        .map((e) => SensorReading.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> deleteSession(String sessionId) async {
    final box = Hive.box(_boxName);
    await box.delete(sessionId);
  }

  static Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }

  static int getSessionReadingCount(String sessionId) {
    final box = Hive.box(_boxName);
    final rawList = box.get(sessionId, defaultValue: []) as List;
    return rawList.length;
  }
}
