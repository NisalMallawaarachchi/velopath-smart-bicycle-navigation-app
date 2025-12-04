import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/screens/poidetails_screen.dart';

class POIMapScreen extends StatefulWidget {
  final LatLng startPoint;
  final dynamic selectedPoi;
  final List<dynamic>? otherPois;

  const POIMapScreen({
    super.key,
    required this.startPoint,
    required this.selectedPoi,
    this.otherPois,
  });

  @override
  State<POIMapScreen> createState() => _POIMapScreenState();
}

class _POIMapScreenState extends State<POIMapScreen> {
  final MapController _mapController = MapController();

  late LatLng poiLatLng;
  late LatLng userLatLng;
  late List<LatLng> routePoints;

  @override
  void initState() {
    super.initState();

    userLatLng = widget.startPoint;

    final latRaw = widget.selectedPoi['lat'];
    final lonRaw = widget.selectedPoi['lon'];

    double? poiLat;
    double? poiLon;

    if (latRaw is String) poiLat = double.tryParse(latRaw);
    if (lonRaw is String) poiLon = double.tryParse(lonRaw);
    if (latRaw is num) poiLat = latRaw.toDouble();
    if (lonRaw is num) poiLon = lonRaw.toDouble();

    poiLat ??= userLatLng.latitude;
    poiLon ??= userLatLng.longitude;

    poiLatLng = LatLng(poiLat, poiLon);

    routePoints = [userLatLng, poiLatLng];

    WidgetsBinding.instance.addPostFrameCallback((_) => fitBounds());
  }

  void fitBounds() {
    final points = [userLatLng, poiLatLng];

    if (widget.otherPois != null) {
      for (var poi in widget.otherPois!) {
        final point = LatLng(
          poi['lat'] is String
              ? double.parse(poi['lat'])
              : (poi['lat'] as num).toDouble(),
          poi['lon'] is String
              ? double.parse(poi['lon'])
              : (poi['lon'] as num).toDouble(),
        );
        points.add(point);
      }
    }

    final bounds = LatLngBounds.fromPoints(points);

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
          maxZoom: 16,
        ),
      );
    } catch (e) {
      _mapController.move(bounds.center, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poiName = widget.selectedPoi['name'] ?? "POI";
    final poiAmenity = widget.selectedPoi['amenity'] ?? "";
    

    /// MARKERS
    final markers = <Marker>[
      Marker(
        point: userLatLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin_circle,
            size: 36, color: Colors.blue),
      ),
      Marker(
        point: poiLatLng,
        width: 40,
        height: 40,
        child:
            const Icon(Icons.location_on, size: 36, color: Colors.red),
      ),
    ];

    /// Add other POIs (optional)
    if (widget.otherPois != null) {
      for (var poi in widget.otherPois!) {
        final point = LatLng(
          poi['lat'] is String
              ? double.parse(poi['lat'])
              : (poi['lat'] as num).toDouble(),
          poi['lon'] is String
              ? double.parse(poi['lon'])
              : (poi['lon'] as num).toDouble(),
        );

        markers.add(
          Marker(
            point: point,
            width: 36,
            height: 36,
            child: const Icon(Icons.location_on,
                size: 30, color: Colors.orange),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(poiName),
        backgroundColor: Colors.deepPurple,
      ),

      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: userLatLng,
          initialZoom: 13,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.velopath.app',
          ),

          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4,
                color: Colors.deepPurple,
              ),
            ],
          ),

          MarkerLayer(markers: markers),
        ],
      ),

      /// BIGGER BOTTOM SHEET + BUTTONS
      bottomSheet: Container(
        height: 160, // ⬅ Increased height
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poiName,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text("$poiAmenity • ${widget.selectedPoi['district'] ?? ''}"),

 

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// 🟣 VIEW DETAILS BUTTON
                ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
    foregroundColor: Colors.white, // ⬅ WHITE TEXT
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => POIDetailsScreen(poi: widget.selectedPoi),
      ),
    );
  },
  child: const Text("View Details"),
),

                /// 📍 MY LOCATION BUTTON
                ElevatedButton.icon(
                  onPressed: () => _mapController.move(userLatLng, 15),
                  icon: const Icon(Icons.my_location),
                  label: const Text("My Location"),
                ),
              
              ],
            )
          ],
        ),
      ),
    );
  }
}
