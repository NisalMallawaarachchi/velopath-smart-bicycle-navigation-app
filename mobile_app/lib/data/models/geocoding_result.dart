// lib/data/models/geocoding_result.dart
import 'package:latlong2/latlong.dart';

class GeocodingResult {
  final String displayName;
  final LatLng point;

  GeocodingResult({
    required this.displayName,
    required this.point,
  });
}
