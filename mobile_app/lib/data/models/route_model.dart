class RouteModel {
  final int id;
  final String startPoint;
  final String endPoint;
  final double distance;
  final double poiScore;
  final double hazardScore;

  RouteModel({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.poiScore,
    required this.hazardScore,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is String) {
        return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      } else if (value is num) {
        return value.toDouble();
      } else {
        return 0.0;
      }
    }

    return RouteModel(
      id: json['id'] ?? 0,
      startPoint: json['start_point'] ?? '',
      endPoint: json['end_point'] ?? '',
      distance: parseDouble(json['distance']),
      poiScore: parseDouble(json['poi_score']),
      hazardScore: parseDouble(json['hazard_score']),
    );
  }
}
