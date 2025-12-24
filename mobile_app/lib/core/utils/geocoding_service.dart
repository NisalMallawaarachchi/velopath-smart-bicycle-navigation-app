// lib/core/utils/geocoding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/geocoding_result.dart';

class GeocodingService {
  /// Search locations using OpenStreetMap Nominatim
  static Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final encoded = Uri.encodeComponent(query.trim());

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$encoded&format=json&limit=5',
    );

    final response = await http.get(
      uri,
      headers: {
        // Nominatim requires a polite user agent
        'User-Agent': 'velopath-student-app/1.0 (your-email@example.com)',
      },
    );

    if (response.statusCode != 200) {
      return [];
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) {
      final lat = double.tryParse(item['lat'] as String? ?? '') ?? 0.0;
      final lon = double.tryParse(item['lon'] as String? ?? '') ?? 0.0;
      final name = item['display_name'] as String? ?? 'Unknown';

      return GeocodingResult(
        displayName: name,
        point: LatLng(lat, lon),
      );
    }).toList();
  }
}
