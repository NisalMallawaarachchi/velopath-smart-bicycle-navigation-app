import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:geolocator/geolocator.dart';

class AllPOIsMapScreen extends StatefulWidget {
  final dynamic startPoint;
  final dynamic endPoint;
  final dynamic selectedPoi;

  const AllPOIsMapScreen({super.key, this.startPoint, this.endPoint, this.selectedPoi});

  @override
  State<AllPOIsMapScreen> createState() => _AllPOIsMapScreenState();
}

class _AllPOIsMapScreenState extends State<AllPOIsMapScreen> {
  List<dynamic> pois = [];
  List<dynamic> nearbyPois = [];
  bool isLoading = true;
  final MapController _mapController = MapController();
  double _zoom = 13.0;
  LatLng? userLocation;
  final double radiusKm = 5.0; // Filter POIs within 5 km

  @override
  void initState() {
    super.initState();
    getUserLocationAndPOIs();
  }

  Future<void> getUserLocationAndPOIs() async {
    try {
      // Request location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      userLocation = LatLng(position.latitude, position.longitude);

      await fetchPOIs();
      filterNearbyPOIs();
    } catch (e) {
      print('Error getting user location: $e');
      await fetchPOIs(); // Fallback to all POIs
    }
  }

  Future<void> fetchPOIs() async {
    try {
      final response = await http.get(Uri.parse('http://10.75.197.44:5001/api/pois'));
      if (response.statusCode == 200) {
        setState(() {
          pois = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load POIs');
      }
    } catch (e) {
      print('Error fetching POIs: $e');
      setState(() => isLoading = false);
    }
  }

  void filterNearbyPOIs() {
    if (userLocation == null) {
      nearbyPois = pois;
      return;
    }

    final Distance distance = Distance();
    nearbyPois = pois.where((poi) {
      final lat = poi['lat']?.toDouble();
      final lon = poi['lon']?.toDouble();
      if (lat == null || lon == null) return false;

      final poiLocation = LatLng(lat, lon);
      final km = distance.as(LengthUnit.Kilometer, userLocation!, poiLocation);
      return km <= radiusKm;
    }).toList();

    setState(() {}); // Refresh map
  }

  List<Marker> buildMarkers() {
    List<Marker> markers = [];

    for (var poi in nearbyPois) {
      final lat = poi['lat']?.toDouble();
      final lon = poi['lon']?.toDouble();
      final name = poi['name'] ?? "Unnamed";
      if (lat == null || lon == null) continue;

      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(name),
                  content: Text(poi['description'] ?? ''),
                ),
              );
            },
            child: Icon(
              Icons.location_on,
              color: (widget.selectedPoi != null && widget.selectedPoi['id'] == poi['id'])
                  ? Colors.blue
                  : Colors.red,
              size: 32,
            ),
          ),
        ),
      );
    }

    // Start & End markers
    if (widget.startPoint != null) {
      markers.add(Marker(
        point: LatLng(widget.startPoint['lat'], widget.startPoint['lon']),
        width: 80,
        height: 80,
        child: const Icon(Icons.flag, color: Colors.green, size: 36),
      ));
    }

    if (widget.endPoint != null) {
      markers.add(Marker(
        point: LatLng(widget.endPoint['lat'], widget.endPoint['lon']),
        width: 80,
        height: 80,
        child: const Icon(Icons.flag, color: Colors.red, size: 36),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final markers = buildMarkers();

    LatLng center = userLocation ??
        (widget.selectedPoi != null
            ? LatLng(widget.selectedPoi['lat'], widget.selectedPoi['lon'])
            : widget.startPoint != null
                ? LatLng(widget.startPoint['lat'], widget.startPoint['lon'])
                : LatLng(6.9271, 79.8612));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby POIs Map'),
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _zoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    markers: markers,
                    polygonOptions: PolygonOptions(
                      borderColor: Colors.blueAccent,
                      color: Colors.black12,
                      borderStrokeWidth: 3,
                    ),
                    builder: (context, clusterMarkers) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            clusterMarkers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "add_poi",
            backgroundColor: Colors.green,
            onPressed: () async {
              final added = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPOIScreen()),
              );
              if (added == true) {
                await fetchPOIs();
                filterNearbyPOIs();
              }
            },
            child: const Icon(Icons.add_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "zoom_in",
            mini: true,
            onPressed: () {
              setState(() => _zoom += 1);
              _mapController.move(center, _zoom);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "zoom_out",
            mini: true,
            onPressed: () {
              setState(() => _zoom -= 1);
              _mapController.move(center, _zoom);
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
