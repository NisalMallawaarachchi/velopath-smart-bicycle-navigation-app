import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:motion_trace/models/sensor_reading.dart';

/// Service for communicating with the Velopath backend API
class ApiService {
  // TODO: Update this to your backend URL
  // For local testing with emulator, use 10.0.2.2 instead of localhost
  // For real device, use your computer's IP address
  static const String baseUrl = 'http://10.0.2.2:5000';
  
  /// Check if the backend ML service is available
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hazard/health'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Server returned ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
  
  /// Send sensor data to backend for hazard prediction
  static Future<HazardPredictionResult> predictHazards(List<SensorReading> readings) async {
    try {
      // Convert sensor readings to JSON
      final sensorData = readings.map((r) => r.toJson()).toList();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/hazard/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sensorData': sensorData}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HazardPredictionResult.fromJson(data);
      } else {
        return HazardPredictionResult(
          success: false,
          error: 'Server returned ${response.statusCode}',
          predictions: [],
          summary: HazardSummary.empty(),
        );
      }
    } catch (e) {
      return HazardPredictionResult(
        success: false,
        error: e.toString(),
        predictions: [],
        summary: HazardSummary.empty(),
      );
    }
  }
  
  /// Get demo prediction using pre-generated data on server
  static Future<HazardPredictionResult> getDemoPrediction() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hazard/demo'),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HazardPredictionResult.fromJson(data);
      } else {
        return HazardPredictionResult(
          success: false,
          error: 'Server returned ${response.statusCode}',
          predictions: [],
          summary: HazardSummary.empty(),
        );
      }
    } catch (e) {
      return HazardPredictionResult(
        success: false,
        error: e.toString(),
        predictions: [],
        summary: HazardSummary.empty(),
      );
    }
  }
}

/// Result of hazard prediction
class HazardPredictionResult {
  final bool success;
  final String? error;
  final List<HazardPrediction> predictions;
  final HazardSummary summary;
  
  HazardPredictionResult({
    required this.success,
    this.error,
    required this.predictions,
    required this.summary,
  });
  
  factory HazardPredictionResult.fromJson(Map<String, dynamic> json) {
    return HazardPredictionResult(
      success: json['success'] ?? false,
      error: json['error'],
      predictions: (json['predictions'] as List? ?? [])
          .map((p) => HazardPrediction.fromJson(p))
          .toList(),
      summary: HazardSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Individual hazard prediction
class HazardPrediction {
  final int windowIndex;
  final int readingIndex;
  final String hazardType;
  final double confidence;
  final double latitude;
  final double longitude;
  final String timestamp;
  
  HazardPrediction({
    required this.windowIndex,
    required this.readingIndex,
    required this.hazardType,
    required this.confidence,
    required this.latitude,
    required this.longitude,
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

/// Summary of hazard predictions
class HazardSummary {
  final int totalWindows;
  final Map<String, int> hazardCounts;
  final int hazardsDetected;
  final List<HazardPrediction> hazardLocations;
  
  HazardSummary({
    required this.totalWindows,
    required this.hazardCounts,
    required this.hazardsDetected,
    required this.hazardLocations,
  });
  
  factory HazardSummary.empty() {
    return HazardSummary(
      totalWindows: 0,
      hazardCounts: {},
      hazardsDetected: 0,
      hazardLocations: [],
    );
  }
  
  factory HazardSummary.fromJson(Map<String, dynamic> json) {
    return HazardSummary(
      totalWindows: json['total_windows'] ?? 0,
      hazardCounts: Map<String, int>.from(json['hazard_counts'] ?? {}),
      hazardsDetected: json['hazards_detected'] ?? 0,
      hazardLocations: (json['hazard_locations'] as List? ?? [])
          .map((h) => HazardPrediction.fromJson(h))
          .toList(),
    );
  }
}
