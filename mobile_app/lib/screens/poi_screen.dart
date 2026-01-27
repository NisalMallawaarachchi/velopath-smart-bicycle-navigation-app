import 'package:flutter/material.dart';
import 'package:mobile_app/screens/poi_map_screen.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';



class PoiScreen extends StatefulWidget {
  const PoiScreen({super.key});

  @override
  State<PoiScreen> createState() => _PoiScreenState();
}

class _PoiScreenState extends State<PoiScreen> {
  List<dynamic> pois = [];
  List<dynamic> filteredPois = [];
  bool isLoading = true;

  String selectedDistrict = "All";
  String searchQuery = "";

  LatLng? myLocation; 
  final double filterDistanceKm = 10.0; 

  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    // Try to get location first then fetch POIs.
    initAll();
  }

  Future<void> initAll() async {
    await getMyLocation(silent: true);
    await fetchPOIs();
  }

  Future<void> fetchPOIs() async {
    const url = 'http://10.75.197.44:5001/api/pois';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        pois = json.decode(response.body);

      
        for (var poi in pois) {
          if (poi['district'] == null) {
            poi['district'] = "Other";
          }
        }

        applyFilters();
      } else {
        throw Exception('Failed to load POIs');
      }
    } catch (e) {
      debugPrint("Error fetching POIs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching POIs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void applyFilters() {
    final q = searchQuery.toLowerCase();
    final filtered = pois.where((poi) {
      final amenity = (poi['amenity'] ?? "").toString().toLowerCase();
      final name = (poi['name'] ?? "").toString().toLowerCase();
      final district = (poi['district'] ?? "").toString();

      final matchesDistrict = selectedDistrict == "All" || district == selectedDistrict;
      final matchesSearch = amenity.contains(q) || name.contains(q);

      bool matchesProximity = true;
      if (myLocation != null) {
        final latRaw = poi['lat'];
        final lonRaw = poi['lon'];

        double? poiLat;
        double? poiLon;
        if (latRaw is String) poiLat = double.tryParse(latRaw);
        if (lonRaw is String) poiLon = double.tryParse(lonRaw);
        if (latRaw is num) poiLat = (latRaw).toDouble();
        if (lonRaw is num) poiLon = (lonRaw).toDouble();

        if (poiLat != null && poiLon != null) {
          final d = distance(LatLng(poiLat, poiLon), myLocation!) / 1000.0;
          matchesProximity = d <= filterDistanceKm;
        } else {
          matchesProximity = false;
        }
      }

      return matchesDistrict && matchesSearch && matchesProximity;
    }).toList();

    if (!mounted) return;
    setState(() => filteredPois = filtered);
  }

  Future<void> getMyLocation({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      if (!mounted) return;

      setState(() {
        myLocation = LatLng(position.latitude, position.longitude);
      });

      applyFilters();
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Widget _buildPoiCard(Map<String, dynamic> poi) {
    final name = poi['name'] ?? "Unnamed";
    final amenity = poi['amenity'] ?? "";
    final district = poi['district'] ?? "";

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text("$amenity • $district"),
        onTap: () {
          if (myLocation == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enable "Use My Location" first.')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => POIMapScreen(
                startPoint: myLocation!,
                selectedPoi: poi,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 30, 128, 176),
        title: const Text("Places to visit", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 18, 96, 145),
        child: const Icon(Icons.add_location_alt),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPOIScreen()),
          );
          if (added == true) fetchPOIs();
        },
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 21, 98, 153)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDistrict,
                          decoration: const InputDecoration(labelText: "Select District"),
                          items: ["All","Colombo", "Gampaha", "Kalutara", "Kandy", "Matale", "Nuwara Eliya", "Galle", "Matara", "Hambantota", "Jaffna", "Kilinochchi", "Mannar", "Vavuniya", "Mullaitivu", "Batticaloa", "Ampara", "Trincomalee", "Kurunegala", "Puttalam", "Anuradhapura", "Polonnaruwa", "Badulla", "Monaragala", "Ratnapura", "Kegalle"]

                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => selectedDistrict = val);
                            applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text("Use My Location"),
                        onPressed: () => getMyLocation(silent: false),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by type (ex: hospital, school)...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      searchQuery = val.toLowerCase();
                      applyFilters();
                    },
                  ),
                ),
                Expanded(
                  child: filteredPois.isEmpty
                      ? const Center(child: Text("No POIs found.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredPois.length,
                          itemBuilder: (context, index) {
                            final poi = Map<String, dynamic>.from(filteredPois[index]);
                            return _buildPoiCard(poi);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
