// map_screen.dart — route planning screen
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/routing_engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../modules/motion_trace/providers/motion_trace_provider.dart';
import 'navigation_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController   = TextEditingController();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _recenterSafe(LatLng point, [double zoom = 16]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, zoom);
    });
  }

  String _profileLabel(RouteProfile p) {
    switch (p) {
      case RouteProfile.shortest: return "Shortest";
      case RouteProfile.safest:   return "Safest";
      case RouteProfile.scenic:   return "Scenic";
      case RouteProfile.balanced: return "Balanced";
    }
  }

  IconData _poiIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'restaurant': case 'food_court': case 'cafe': return Icons.restaurant;
      case 'hospital':   case 'clinic':     case 'pharmacy': return Icons.local_hospital;
      case 'parking':    return Icons.local_parking;
      case 'fuel':       return Icons.local_gas_station;
      case 'atm':        case 'bank':        return Icons.account_balance;
      case 'hotel':      case 'hostel':      case 'guest_house': return Icons.hotel;
      case 'viewpoint':  case 'attraction':  case 'museum': return Icons.landscape;
      case 'supermarket': case 'convenience': return Icons.local_grocery_store;
      case 'bicycle_rental': case 'bicycle_repair_station': return Icons.pedal_bike;
      default: return Icons.place;
    }
  }

  Color _poiColor(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'restaurant': case 'food_court': case 'cafe': return Colors.orange.shade700;
      case 'hospital':   case 'clinic':     case 'pharmacy': return Colors.red.shade600;
      case 'parking':    return Colors.blue.shade700;
      case 'fuel':       return Colors.deepPurple;
      case 'atm':        case 'bank':        return Colors.green.shade700;
      case 'hotel':      case 'hostel':      case 'guest_house': return Colors.indigo;
      case 'viewpoint':  case 'attraction':  case 'museum': return Colors.teal;
      case 'bicycle_rental': case 'bicycle_repair_station': return ThemeProvider.primaryDarkBlue;
      default: return Colors.grey.shade700;
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p      = context.watch<RoutingEngineProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasRoute  = p.startPoint != null && p.endPoint != null && p.routePoints.length > 1;
    // Start Ride if the user tapped "My location" GPS button; otherwise Preview
    final canRide   = hasRoute && !p.isLoading && p.startIsCurrentLocation;
    final canPreview = hasRoute && !p.isLoading && !p.startIsCurrentLocation;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          "Plan Route",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
          ),
        ),
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

                  // ── Search card ──────────────────────────────────────────
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
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Start location
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
                                if (p.startPoint != null) _recenterSafe(p.startPoint!, 17);
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : ThemeProvider.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (v) { if (v.length >= 3) p.searchPlaces(v, isStart: true); },
                        ),
                        _suggestions(p.startSuggestions, true, p),
                        const SizedBox(height: 12),

                        // Destination
                        TextField(
                          controller: _endController,
                          decoration: InputDecoration(
                            hintText: "Destination",
                            prefixIcon: const Icon(Icons.place, color: Colors.red, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : ThemeProvider.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (v) { if (v.length >= 3) p.searchPlaces(v, isStart: false); },
                        ),
                        _suggestions(p.endSuggestions, false, p),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Route profile chips ──────────────────────────────────
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: RouteProfile.values.map((profile) {
                        final isSelected = p.activeProfile == profile;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              _profileLabel(profile),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : ThemeProvider.primaryDarkBlue),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: ThemeProvider.primaryDarkBlue,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : ThemeProvider.surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                            onSelected: (_) async {
                              await p.setProfile(profile);
                              if (p.routePoints.isNotEmpty) {
                                _recenterSafe(p.routePoints[p.routePoints.length ~/ 2], 13);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Start Ride / Preview Route / Loading ─────────────────
                  if (p.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      ),
                    )
                  else if (canRide)
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
                          if (!mounted) return;
                          // Start sensor collection for hazard detection
                          await context.read<MotionTraceProvider>().requestConsentAndStart(context);
                          if (!mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const NavigationScreen(isPreview: false),
                          ));
                        },
                      ),
                    )
                  else if (canPreview)
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.preview, size: 22, color: Colors.indigo.shade600),
                        label: Text("Preview Route",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo.shade600)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.indigo.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const NavigationScreen(isPreview: true),
                          ));
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Route preview map ────────────────────────────────────
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(initialCenter: LatLng(7.8731, 80.7718), initialZoom: 7),
                        children: [
                          TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.velopath.app"),
                          if (p.coloredPolylines.isNotEmpty)
                            PolylineLayer(polylines: p.coloredPolylines),
                          MarkerLayer(
                            markers: [
                              if (p.startPoint != null)
                                Marker(
                                  point: p.startPoint!, width: 36, height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                                    child: const Icon(Icons.trip_origin, color: Colors.white, size: 18),
                                  ),
                                ),
                              if (p.endPoint != null)
                                Marker(
                                  point: p.endPoint!, width: 36, height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                                    child: const Icon(Icons.flag, color: Colors.white, size: 18),
                                  ),
                                ),
                              ...p.routePois.map((poi) {
                                final color = _poiColor(poi.amenity);
                                return Marker(
                                  point: poi.location, width: 36, height: 36,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5)),
                                    child: Icon(_poiIcon(poi.amenity), color: Colors.white, size: 16),
                                  ),
                                );
                              }),
                              ...p.routeHazards.map((hazard) {
                                final isPothole = hazard.type == 'pothole';
                                final color = isPothole ? Colors.red.shade700 : Colors.orange.shade700;
                                return Marker(
                                  point: hazard.location, width: 36, height: 36,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5)),
                                    child: Icon(isPothole ? Icons.warning_rounded : Icons.speed, color: Colors.white, size: 16),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom stats panel ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _statCard(icon: Icons.straighten, iconColor: Colors.blueAccent,
                          label: 'Distance', value: '${p.totalDistanceKm.toStringAsFixed(2)} km', isDark: isDark)),
                      VerticalDivider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                      Expanded(child: _statCard(icon: Icons.warning_rounded,
                          iconColor: p.totalHazards > 0 ? Colors.redAccent : Colors.orangeAccent,
                          label: 'Hazards', value: '${p.totalHazards}', isDark: isDark)),
                      VerticalDivider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1),
                      Expanded(child: _statCard(icon: Icons.local_florist_rounded, iconColor: Colors.green,
                          label: 'Avg POI', value: p.avgPoiScore.toStringAsFixed(2), isDark: isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({required IconData icon, required Color iconColor, required String label, required String value, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue)),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _suggestions(List<PlaceSuggestion> list, bool isStart, RoutingEngineProvider p) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withValues(alpha: 0.05)),
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
              if (isStart) { _startController.text = s.name; } else { _endController.text = s.name; }
              await p.selectSuggestion(s, isStart: isStart);
              if (isStart && p.startPoint != null) _recenterSafe(p.startPoint!, 16);
              if (!isStart && p.endPoint != null) _recenterSafe(p.endPoint!, 16);
              if (p.routePoints.isNotEmpty) _recenterSafe(p.routePoints[p.routePoints.length ~/ 2], 13);
            },
          );
        },
      ),
    );
  }
}
