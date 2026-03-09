class SensorReading {
  final DateTime timestamp;
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  final double magX, magY, magZ;
  final double latitude, longitude;
  final String label;

  SensorReading({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.magX,
    required this.magY,
    required this.magZ,
    required this.latitude,
    required this.longitude,
    this.label = 'smooth',
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'accelX': accelX,
        'accelY': accelY,
        'accelZ': accelZ,
        'gyroX': gyroX,
        'gyroY': gyroY,
        'gyroZ': gyroZ,
        'magX': magX,
        'magY': magY,
        'magZ': magZ,
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      timestamp: DateTime.parse(json['timestamp']),
      accelX: (json['accelX'] ?? 0).toDouble(),
      accelY: (json['accelY'] ?? 0).toDouble(),
      accelZ: (json['accelZ'] ?? 0).toDouble(),
      gyroX: (json['gyroX'] ?? 0).toDouble(),
      gyroY: (json['gyroY'] ?? 0).toDouble(),
      gyroZ: (json['gyroZ'] ?? 0).toDouble(),
      magX: (json['magX'] ?? 0).toDouble(),
      magY: (json['magY'] ?? 0).toDouble(),
      magZ: (json['magZ'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      label: json['label'] ?? 'smooth',
    );
  }
}
