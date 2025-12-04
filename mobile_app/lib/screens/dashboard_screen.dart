import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'poi_map_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Fetch POIs from backend
  Future<List<dynamic>> fetchPOIs(
    double lat,
    double lon, {
    double radiusKm = 10,
  }) async {
    try {
      final uri = Uri.parse(
        'http://10.75.197.44:5001/pois?lat=$lat&lon=$lon&radius=${radiusKm * 1000}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error fetching POIs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching POIs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLocation = LatLng(
      6.9271,
      79.8612,
    ); // Example: Colombo center, replace with GPS

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Velopath Dashboard"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // View POI List
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/pois'),
              icon: const Icon(Icons.list_alt, color: Colors.white),
              label: const Text("View List of Places"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 5,
              ),
            ),

            const SizedBox(height: 20),

            // View Map
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/all-pois-map'),
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text("View All POIs on Map"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
