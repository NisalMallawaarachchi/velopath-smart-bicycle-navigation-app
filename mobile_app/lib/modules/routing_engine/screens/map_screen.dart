// lib/modules/routing_engine/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/routing_engine_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController = TextEditingController();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String _profileLabel(RouteProfile profile) {
    switch (profile) {
      case RouteProfile.shortest:
        return 'Shortest';
      case RouteProfile.safest:
        return 'Safest';
      case RouteProfile.scenic:
        return 'Scenic';
      case RouteProfile.balanced:
      default:
        return 'Balanced';
    }
  }

  Widget _profileButton(
    RoutingEngineProvider provider,
    String label,
    RouteProfile profile,
  ) {
    final bool isActive = provider.activeProfile == profile;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.deepPurple.shade100 : Colors.white,
          foregroundColor: Colors.black87,
          elevation: isActive ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isActive ? Colors.deepPurple : Colors.grey.shade300,
            ),
          ),
        ),
        onPressed: () => provider.setProfile(profile),
        child: Row(
          children: [
            if (isActive) const Icon(Icons.check, size: 16),
            if (isActive) const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _suggestionList(
    List<PlaceSuggestion> suggestions,
    bool isStart,
    RoutingEngineProvider provider,
  ) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final s = suggestions[index];
          final title = s.name;
          final subtitle = s.name.replaceFirst('$title, ', '');

          return ListTile(
            leading: Icon(
              isStart ? Icons.radio_button_unchecked : Icons.flag,
              color: isStart ? Colors.green : Colors.red,
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: () async {
              if (isStart) {
                _startController.text = title;
              } else {
                _endController.text = title;
              }
              FocusScope.of(context).unfocus();
              await provider.selectSuggestion(s, isStart: isStart);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RoutingEngineProvider>(context);

    final routePoints = provider.routePoints;
    final LatLng centerSL = LatLng(7.8731, 80.7718);

    LatLng initialCenter;
    double initialZoom;

    if (routePoints.isNotEmpty) {
      initialCenter = routePoints[routePoints.length ~/ 2];
      initialZoom = 12;
    } else if (provider.startPoint != null) {
      initialCenter = provider.startPoint!;
      initialZoom = 13;
    } else {
      initialCenter = centerSL;
      initialZoom = 7.5;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Route Map (${_profileLabel(provider.activeProfile)})'),
      ),
      body: Column(
        children: [
          // █████████ SEARCH INPUTS █████████
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // START TEXT FIELD
                TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: 'Start location',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    if (value.trim().length >= 2) {
                      provider.searchPlaces(value, isStart: true);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // END TEXT FIELD
                TextField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    if (value.trim().length >= 2) {
                      provider.searchPlaces(value, isStart: false);
                    }
                  },
                ),

                const SizedBox(height: 12),

                // █████ Profile Buttons (Scrollable) █████
                SizedBox(
                  height: 45,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _profileButton(provider, "Shortest", RouteProfile.shortest),
                        _profileButton(provider, "Safest", RouteProfile.safest),
                        _profileButton(provider, "Scenic", RouteProfile.scenic),
                        _profileButton(provider, "Balanced", RouteProfile.balanced),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // █████████ SUGGESTIONS █████████
          _suggestionList(
            provider.startSuggestions,
            true,
            provider,
          ),
          _suggestionList(
            provider.endSuggestions,
            false,
            provider,
          ),

          // █████████ MAP █████████
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.velopath.app",
                ),

                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4,
                        color: Colors.blue,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    if (provider.startPoint != null)
                      Marker(
                        point: provider.startPoint!,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.location_on,
                            size: 40, color: Colors.green),
                      ),
                    if (provider.endPoint != null)
                      Marker(
                        point: provider.endPoint!,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.flag,
                            size: 36, color: Colors.red),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // █████████ SUMMARY █████████
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                Text("Total distance: ${provider.totalDistanceKm.toStringAsFixed(3)} km"),
                Text("Total hazards: ${provider.totalHazards}"),
                Text("Avg POI score: ${provider.avgPoiScore.toStringAsFixed(2)}"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
