import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

/// Service for communicating with the VeloPath backend hazard detection API.
class HazardApiService {
  static const String baseUrl = 'http://192.168.8.118:5001';

  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/hazard/health'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Server returned ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<HazardPredictionResult> predictHazards(
      List<SensorReading> readings) async {
    try {
      final sensorData = readings.map((r) => r.toJson()).toList();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/hazard/predict'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'sensorData': sensorData}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return HazardPredictionResult.fromJson(json.decode(response.body));
      } else {
        return HazardPredictionResult(
            success: false, error: 'Server returned ${response.statusCode}',
            predictions: [], summary: HazardSummary.empty());
      }
    } catch (e) {
      return HazardPredictionResult(
          success: false, error: e.toString(),
          predictions: [], summary: HazardSummary.empty());
    }
  }

  static Future<UploadResult> uploadSession(
      List<SensorReading> readings, String mode) async {
    try {
      final sensorData = readings.map((r) => r.toJson()).toList();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/hazard/upload'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'sensorData': sensorData, 'mode': mode}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return UploadResult.fromJson(json.decode(response.body));
      } else {
        return UploadResult(success: false, error: 'Server returned ${response.statusCode}');
      }
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }
}

class HazardPredictionResult {
  final bool success;
  final String? error;
  final List<HazardPrediction> predictions;
  final HazardSummary summary;

  HazardPredictionResult({
    required this.success, this.error,
    required this.predictions, required this.summary,
  });

  factory HazardPredictionResult.fromJson(Map<String, dynamic> json) {
    return HazardPredictionResult(
      success: json['success'] ?? false,
      error: json['error'],
      predictions: (json['predictions'] as List? ?? [])
          .map((p) => HazardPrediction.fromJson(p)).toList(),
      summary: HazardSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class HazardPrediction {
  final int windowIndex;
  final int readingIndex;
  final String hazardType;
  final double confidence;
  final double latitude;
  final double longitude;
  final String timestamp;

  HazardPrediction({
    required this.windowIndex, required this.readingIndex,
    required this.hazardType, required this.confidence,
    required this.latitude, required this.longitude,
    required this.timestamp,
  });

  factory HazardPrediction.fromJson(Map<String, dynamic> json) {
    return HazardPrediction(
      windowIndex: json['window_index'] ?? 0,
      readingIndex: json['reading_index'] ?? 0,
      hazardType: json['hazard_type'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? '',
    );
  }

  bool get isHazard => hazardType != 'smooth';
}

class HazardSummary {
  final int totalWindows;
  final Map<String, int> hazardCounts;
  final int hazardsDetected;
  final List<HazardPrediction> hazardLocations;

  HazardSummary({
    required this.totalWindows, required this.hazardCounts,
    required this.hazardsDetected, required this.hazardLocations,
  });

  factory HazardSummary.empty() => HazardSummary(
      totalWindows: 0, hazardCounts: {}, hazardsDetected: 0, hazardLocations: []);

  factory HazardSummary.fromJson(Map<String, dynamic> json) {
    return HazardSummary(
      totalWindows: json['total_windows'] ?? 0,
      hazardCounts: Map<String, int>.from(json['hazard_counts'] ?? {}),
      hazardsDetected: json['hazards_detected'] ?? 0,
      hazardLocations: (json['hazard_locations'] as List? ?? [])
          .map((h) => HazardPrediction.fromJson(h)).toList(),
    );
  }
}

class UploadResult {
  final bool success;
  final String? error;
  final String? mode;
  final String? message;

  UploadResult({required this.success, this.error, this.mode, this.message});

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      success: json['success'] ?? false,
      error: json['error'],
      mode: json['mode'],
      message: json['message'],
    );
  }
}
