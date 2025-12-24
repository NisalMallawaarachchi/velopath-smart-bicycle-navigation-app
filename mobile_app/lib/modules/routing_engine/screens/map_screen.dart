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
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  final MapController _mapController = MapController();
  late final MapOptions _mapOptions;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController = TextEditingController();

    _mapOptions = const MapOptions(
      initialCenter: LatLng(7.8731, 80.7718), // Sri Lanka
      initialZoom: 7,
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  IconData _instructionIcon(String text) {
    final t = text.toLowerCase();
    if (t.contains("u-turn")) return Icons.u_turn_left;
    if (t.contains("left")) return Icons.turn_left;
    if (t.contains("right")) return Icons.turn_right;
    if (t.contains("arriv")) return Icons.flag;
    return Icons.straight;
  }

  String _profileLabel(RouteProfile p) {
    switch (p) {
      case RouteProfile.shortest:
        return "Shortest";
      case RouteProfile.safest:
        return "Safest";
      case RouteProfile.scenic:
        return "Scenic";
      case RouteProfile.balanced:
      default:
        return "Balanced";
    }
  }

  void _recenterSafe(LatLng point, [double zoom = 16]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, zoom);
    });
  }

  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final p = context.watch<RoutingEngineProvider>();

    final canStartRide =
        p.startPoint != null && p.endPoint != null && p.routePoints.length > 1;

    final currentInstr = p.currentInstruction;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("Route Map (${_profileLabel(p.activeProfile)})"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---------------- START ----------------
                  TextField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: "Start location",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v.length >= 3) {
                        p.searchPlaces(v, isStart: true);
                      }
                    },
                  ),
                  _suggestions(p.startSuggestions, true, p),

                  TextButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text("Use my location"),
                    onPressed: () async {
                      await p.useCurrentLocationAsStart();
                      _startController.text = "My location";
                      if (p.startPoint != null) {
                        _recenterSafe(p.startPoint!, 17);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // ---------------- DEST ----------------
                  TextField(
                    controller: _endController,
                    decoration: const InputDecoration(
                      labelText: "Destination",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v.length >= 3) {
                        p.searchPlaces(v, isStart: false);
                      }
                    },
                  ),
                  _suggestions(p.endSuggestions, false, p),

                  const SizedBox(height: 14),

                  // ---------------- PROFILES ----------------
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: RouteProfile.values.map((profile) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_profileLabel(profile)),
                            selected: p.activeProfile == profile,
                            onSelected: (_) async {
                              await p.setProfile(profile);
                              if (p.routePoints.isNotEmpty) {
                                _recenterSafe(
                                  p.routePoints[p.routePoints.length ~/ 2],
                                  13,
                                );
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ---------------- NAVIGATION ----------------
                  if (canStartRide && !p.isNavigating)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.navigation),
                      label: const Text("Start Ride"),
                      onPressed: () async {
                        await p.startNavigation();
                        if (p.currentLocation != null) {
                          _recenterSafe(p.currentLocation!, 16);
                        }
                      },
                    ),

                  if (p.isNavigating)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text("End Ride"),
                      onPressed: p.stopNavigation,
                    ),

                  const SizedBox(height: 14),

                  // ---------------- MAP ----------------
                  RepaintBoundary(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: _mapOptions,
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: "com.velopath.app",
                          ),

                          Selector<RoutingEngineProvider, List<Polyline>>(
                            selector: (_, prov) => prov.coloredPolylines,
                            builder: (_, polylines, __) {
                              if (polylines.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return PolylineLayer(polylines: polylines);
                            },
                          ),

                          Selector<RoutingEngineProvider,
                              (LatLng?, LatLng?, bool, LatLng?)>(
                            selector: (_, prov) => (
                              prov.startPoint,
                              prov.endPoint,
                              prov.isNavigating,
                              prov.currentLocation
                            ),
                            builder: (_, data, __) {
                              final sp = data.$1;
                              final ep = data.$2;
                              final nav = data.$3;
                              final cl = data.$4;

                              return MarkerLayer(
                                markers: [
                                  if (sp != null)
                                    Marker(
                                      point: sp,
                                      child: const Icon(Icons.location_on,
                                          color: Colors.green, size: 34),
                                    ),
                                  if (ep != null)
                                    Marker(
                                      point: ep,
                                      child: const Icon(Icons.flag,
                                          color: Colors.red, size: 30),
                                    ),
                                  if (nav && cl != null)
                                    Marker(
                                      point: cl,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------------- BOTTOM PANEL ----------------
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.deepPurple.shade50,
              child: Column(
                children: [
                  if (p.isNavigating && currentInstr != null)
                    Row(
                      children: [
                        Icon(_instructionIcon(currentInstr.textEn)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(currentInstr.textEn)),
                        Text(
                          "(${p.currentInstructionIndex + 1}/${p.instructions.length})",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                      "Total Distance: ${p.totalDistanceKm.toStringAsFixed(2)} km"),
                  Text("Hazards: ${p.totalHazards}"),
                  Text(
                      "Avg POI Score: ${p.avgPoiScore.toStringAsFixed(2)}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  Widget _suggestions(
    List<PlaceSuggestion> list,
    bool isStart,
    RoutingEngineProvider p,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(0.08),
          )
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final s = list[i];
          return ListTile(
            title: Text(s.name),
            onTap: () async {
              FocusScope.of(context).unfocus();

              if (isStart) {
                _startController.text = s.name;
              } else {
                _endController.text = s.name;
              }

              await p.selectSuggestion(s, isStart: isStart);

              if (isStart && p.startPoint != null) {
                _recenterSafe(p.startPoint!, 16);
              }
              if (!isStart && p.endPoint != null) {
                _recenterSafe(p.endPoint!, 16);
              }
              if (p.routePoints.isNotEmpty) {
                _recenterSafe(
                    p.routePoints[p.routePoints.length ~/ 2], 13);
              }
            },
          );
        },
      ),
    );
  }
}
