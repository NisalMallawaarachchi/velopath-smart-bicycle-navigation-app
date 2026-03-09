//map_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/routing_engine_provider.dart';
import '../../../providers/theme_provider.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canStartRide =
        p.startPoint != null && p.endPoint != null && p.routePoints.length > 1;

    final currentInstr = p.currentInstruction;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("Plan Route", style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ---------------- START & DEST DETAILS ----------------
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ],
                    ),
                    child: Column(
                      children: [
                        // START
                        TextField(
                          controller: _startController,
                          decoration: InputDecoration(
                            hintText: "Start location",
                            prefixIcon: const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.my_location, color: ThemeProvider.primaryDarkBlue),
                              onPressed: () async {
                                await p.useCurrentLocationAsStart();
                                _startController.text = "My location";
                                if (p.startPoint != null) {
                                  _recenterSafe(p.startPoint!, 17);
                                }
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : ThemeProvider.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (v) {
                            if (v.length >= 3) {
                              p.searchPlaces(v, isStart: true);
                            }
                          },
                        ),
                        _suggestions(p.startSuggestions, true, p),

                        const SizedBox(height: 12),

                        // DEST
                        TextField(
                          controller: _endController,
                          decoration: InputDecoration(
                            hintText: "Destination",
                            prefixIcon: const Icon(Icons.place, color: Colors.red, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : ThemeProvider.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (v) {
                            if (v.length >= 3) {
                              p.searchPlaces(v, isStart: false);
                            }
                          },
                        ),
                        _suggestions(p.endSuggestions, false, p),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------------- PROFILES ----------------
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: RouteProfile.values.map((profile) {
                        final isSelected = p.activeProfile == profile;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_profileLabel(profile), style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : (isDark ? Colors.white70 : ThemeProvider.primaryDarkBlue))),
                            selected: isSelected,
                            selectedColor: ThemeProvider.primaryDarkBlue,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : ThemeProvider.surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
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

                  const SizedBox(height: 16),

                  // ---------------- NAVIGATION ----------------
                  if (canStartRide && !p.isNavigating)
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation, size: 22, color: ThemeProvider.accentCyan),
                        label: const Text("Start Ride", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeProvider.primaryDarkBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await p.startNavigation();
                          if (p.currentLocation != null) {
                            _recenterSafe(p.currentLocation!, 16);
                          }
                        },
                      ),
                    ),

                  if (p.isNavigating)
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.stop, color: Colors.redAccent, size: 22),
                        label: const Text("End Ride", style: TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: p.stopNavigation,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ---------------- MAP ----------------
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ]
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
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
                              (LatLng?, LatLng?, bool, LatLng?, List<MapPoi>, List<MapHazard>)>(
                            selector: (_, prov) => (
                              prov.startPoint,
                              prov.endPoint,
                              prov.isNavigating,
                              prov.currentLocation,
                              prov.routePois,
                              prov.routeHazards,
                            ),
                            builder: (_, data, __) {
                              final sp = data.$1;
                              final ep = data.$2;
                              final nav = data.$3;
                              final cl = data.$4;
                              final pois = data.$5;
                              final hazards = data.$6;

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
                                          color: Colors.blueAccent,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                        ),
                                      ),
                                    ),
                                  // --- POI Markers ---
                                  if (pois.isNotEmpty)
                                    ...pois.map((poi) {
                                      return Marker(
                                        point: poi.location,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.stars,
                                          color: Colors.amber,
                                          size: 28,
                                        ),
                                      );
                                    }),
                                  // --- Hazard Markers ---
                                  if (hazards.isNotEmpty)
                                    ...hazards.map((hazard) {
                                      return Marker(
                                        point: hazard.location,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.redAccent,
                                          size: 28,
                                        ),
                                      );
                                    }),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---------------- PROXIMITY ALERT BANNER ----------------
                  Selector<RoutingEngineProvider, String?>(
                    selector: (_, prov) => prov.currentAlertMessage,
                    builder: (_, alertMessage, __) {
                      if (alertMessage == null) return const SizedBox.shrink();
                      
                      final isHazard = alertMessage.contains("HAZARD");
                      
                      return Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isHazard ? Colors.red.shade800 : Colors.teal.shade800,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isHazard ? Icons.warning_rounded : Icons.star_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alertMessage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---------------- BOTTOM PANEL ----------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.isNavigating && currentInstr != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ThemeProvider.primaryDarkBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_instructionIcon(currentInstr.textEn),
                                color: ThemeProvider.primaryDarkBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currentInstr.textEn,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Text(
                            "(${p.currentInstructionIndex + 1}/${p.instructions.length})",
                            style: TextStyle(
                                fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      const SizedBox(height: 12),
                    ],
                    // ---- Route Stats Row ----
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          // Distance
                          Expanded(
                            child: _statCard(
                              icon: Icons.straighten,
                              iconColor: Colors.blueAccent,
                              label: 'Distance',
                              value:
                                  '${p.totalDistanceKm.toStringAsFixed(2)} km',
                              isDark: isDark,
                            ),
                          ),
                          VerticalDivider(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                          // Hazards
                          Expanded(
                            child: _statCard(
                              icon: Icons.warning_amber_rounded,
                              iconColor: p.totalHazards > 0
                                  ? Colors.redAccent
                                  : Colors.orangeAccent,
                              label: 'Hazards',
                              value: '${p.totalHazards}',
                              isDark: isDark,
                            ),
                          ),
                          VerticalDivider(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                          // POI Score
                          Expanded(
                            child: _statCard(
                              icon: Icons.local_florist_rounded,
                              iconColor: Colors.green,
                              label: 'Avg POI',
                              value: p.avgPoiScore.toStringAsFixed(2),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
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
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.05),
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

