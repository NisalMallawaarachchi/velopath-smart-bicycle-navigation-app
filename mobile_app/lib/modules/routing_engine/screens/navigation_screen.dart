// navigation_screen.dart
// Full-screen navigation UI.
// isPreview=true → route overview without GPS tracking (user is far from start).
// isPreview=false → live turn-by-turn navigation.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart' show FitBoundsOptions;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/routing_engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../modules/motion_trace/providers/motion_trace_provider.dart';

class NavigationScreen extends StatefulWidget {
  final bool isPreview;
  const NavigationScreen({super.key, this.isPreview = false});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  late final PageController _stepsController;
  int _lastAutoIndex = -1;

  @override
  void initState() {
    super.initState();
    _stepsController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<RoutingEngineProvider>();
      if (widget.isPreview) {
        _fitRoute(p);
      } else {
        // Navigation: center on start point first, GPS will follow
        final target = p.startPoint ?? p.currentLocation;
        if (target != null) _mapController.move(target, 16);
      }
    });
  }

  @override
  void dispose() {
    _stepsController.dispose();
    super.dispose();
  }

  void _fitRoute(RoutingEngineProvider p) {
    if (p.routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(p.routePoints);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 160),
        ),
      );
    } catch (_) {
      // fallback: just move to midpoint
      final mid = p.routePoints[p.routePoints.length ~/ 2];
      _mapController.move(mid, 13);
    }
  }

  void _recenter() {
    final p = context.read<RoutingEngineProvider>();
    if (widget.isPreview) {
      _fitRoute(p);
    } else {
      final loc = p.currentLocation ?? p.startPoint;
      if (loc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(loc, 17);
        });
      }
    }
  }

  void _endRide() {
    context.read<RoutingEngineProvider>().stopNavigation();
    // Stop sensor collection and upload the final session to the backend
    context.read<MotionTraceProvider>().stopTracking();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _startRideFromPreview() async {
    final p = context.read<RoutingEngineProvider>();
    final mt = context.read<MotionTraceProvider>();

    // Start turn-by-turn navigation
    await p.startNavigation();

    // Start sensor collection for hazard detection.
    // Uses the full permission + consent flow so nothing is skipped.
    if (mounted) {
      await mt.requestConsentAndStart(context);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NavigationScreen(isPreview: false),
      ),
    );
  }

  // ── icon helpers ─────────────────────────────────────────────────────────

  IconData _instructionIcon(String text) {
    final t = text.toLowerCase();
    if (t.contains("u-turn")) return Icons.u_turn_left;
    if (t.contains("left"))   return Icons.turn_left;
    if (t.contains("right"))  return Icons.turn_right;
    if (t.contains("arriv"))  return Icons.flag;
    return Icons.straight;
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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p      = context.watch<RoutingEngineProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq     = MediaQuery.of(context);

    // Auto-pop when live navigation ends externally
    if (!widget.isPreview && !p.isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }

    // Follow GPS in live mode
    if (!widget.isPreview && p.currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try { _mapController.move(p.currentLocation!, 17); } catch (_) {}
        }
      });
    }

    // Auto-advance PageView when GPS moves to the next instruction step
    if (!widget.isPreview && p.instructions.isNotEmpty) {
      final targetIdx = p.currentInstructionIndex.clamp(0, p.instructions.length - 1);
      if (targetIdx != _lastAutoIndex) {
        _lastAutoIndex = targetIdx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _stepsController.hasClients) {
            _stepsController.animateToPage(
              targetIdx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [

          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: p.startPoint ?? p.routePoints.firstOrNull ?? const LatLng(7.8731, 80.7718),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.velopath.app",
                ),

                if (p.coloredPolylines.isNotEmpty)
                  PolylineLayer(polylines: p.coloredPolylines),

                MarkerLayer(
                  markers: [
                    // Start pin
                    if (p.startPoint != null)
                      Marker(
                        point: p.startPoint!,
                        width: 36, height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.trip_origin, color: Colors.white, size: 18),
                        ),
                      ),
                    // End pin
                    if (p.endPoint != null)
                      Marker(
                        point: p.endPoint!,
                        width: 36, height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.flag, color: Colors.white, size: 18),
                        ),
                      ),
                    // GPS position (live mode only)
                    if (!widget.isPreview && p.currentLocation != null)
                      Marker(
                        point: p.currentLocation!,
                        width: 30, height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeProvider.accentCyan,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                          ),
                          child: const Icon(Icons.navigation, color: Colors.white, size: 14),
                        ),
                      ),
                    // POI markers
                    ...p.routePois.map((poi) {
                      final color = _poiColor(poi.amenity);
                      return Marker(
                        point: poi.location,
                        width: 36, height: 36,
                        child: Tooltip(
                          message: poi.name,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                            ),
                            child: Icon(_poiIcon(poi.amenity), color: Colors.white, size: 16),
                          ),
                        ),
                      );
                    }),
                    // Hazard markers
                    ...p.routeHazards.map((hazard) {
                      final isPothole = hazard.type == 'pothole';
                      final color = isPothole ? Colors.red.shade700 : Colors.orange.shade700;
                      return Marker(
                        point: hazard.location,
                        width: 36, height: 36,
                        child: Tooltip(
                          message: isPothole ? 'Pothole' : 'Speed Bump',
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                            ),
                            child: Icon(
                              isPothole ? Icons.warning_rounded : Icons.speed,
                              color: Colors.white, size: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // ── Top banner ───────────────────────────────────────────────────
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF2101828) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  // ── Scrollable steps (live) or static preview info ─────────
                  Expanded(
                    child: widget.isPreview
                        ? _previewBannerContent(p, isDark)
                        : ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20),
                            ),
                            child: p.instructions.isEmpty
                                ? _staticStepPage(
                                    Icons.navigation,
                                    'Follow the route',
                                    '',
                                    isDark,
                                  )
                                : PageView.builder(
                                    controller: _stepsController,
                                    itemCount: p.instructions.length,
                                    onPageChanged: (index) {
                                      final instr = p.instructions[index];
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          try {
                                            _mapController.move(instr.location, 15);
                                          } catch (_) {}
                                        }
                                      });
                                    },
                                    itemBuilder: (_, index) {
                                      final instr = p.instructions[index];
                                      return _staticStepPage(
                                        _instructionIcon(instr.textEn),
                                        instr.textEn,
                                        'Step ${index + 1} of ${p.instructions.length}',
                                        isDark,
                                      );
                                    },
                                  ),
                          ),
                  ),

                  // ── Fixed close button (always visible) ────────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: 12, left: 4),
                    child: GestureDetector(
                      onTap: () {
                        if (!widget.isPreview) {
                          context.read<RoutingEngineProvider>().stopNavigation();
                        }
                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Proximity alert (live mode only) ─────────────────────────────
          if (!widget.isPreview && p.currentAlertMessage != null)
            Positioned(
              top: mq.padding.top + 96,
              left: 12,
              right: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.currentAlertMessage!.contains("HAZARD")
                      ? Colors.red.shade800
                      : Colors.teal.shade800,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Icon(
                      p.currentAlertMessage!.contains("HAZARD")
                          ? Icons.warning_rounded
                          : Icons.star_rounded,
                      color: Colors.white, size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.currentAlertMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Re-center / overview FAB ──────────────────────────────────────
          Positioned(
            bottom: mq.padding.bottom + 110,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'nav_recenter',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _recenter,
              child: Icon(
                widget.isPreview ? Icons.fit_screen : Icons.my_location,
                color: ThemeProvider.primaryDarkBlue,
              ),
            ),
          ),

          // ── Bottom strip ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, mq.padding.bottom + 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF2101828) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Row(
                children: [
                  _stat(Icons.straighten, Colors.blueAccent,
                      '${p.totalDistanceKm.toStringAsFixed(2)} km', 'Distance', isDark),
                  _divider(isDark),
                  _stat(Icons.warning_rounded,
                      p.totalHazards > 0 ? Colors.red.shade600 : Colors.grey.shade400,
                      '${p.totalHazards}', 'Hazards', isDark),
                  _divider(isDark),
                  _stat(Icons.local_florist_rounded, Colors.green,
                      p.avgPoiScore.toStringAsFixed(2), 'POI Score', isDark),
                  const SizedBox(width: 10),

                  // Preview mode → "Start Ride" button
                  if (widget.isPreview)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.navigation, size: 18, color: ThemeProvider.accentCyan),
                      label: const Text('Start Ride',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.primaryDarkBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: _startRideFromPreview,
                    ),

                  // Live mode → "End Ride" button
                  if (!widget.isPreview)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('End Ride',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: _endRide,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBannerContent(RoutingEngineProvider p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Route Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                  ),
                ),
                Text(
                  '${p.totalDistanceKm.toStringAsFixed(1)} km · ${p.totalHazards} hazards',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staticStepPage(IconData icon, String text, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: ThemeProvider.primaryDarkBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
        width: 1, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDark ? Colors.white24 : Colors.grey.shade300,
      );

  Widget _stat(IconData icon, Color color, String value, String label, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue)),
          Text(label, style: TextStyle(fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}
