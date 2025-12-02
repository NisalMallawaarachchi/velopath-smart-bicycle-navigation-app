// lib/modules/routing_engine/providers/routing_engine_provider.dart
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../data/models/route_model.dart';

/// Which type of route the user wants
enum RouteProfile { shortest, safest, scenic, balanced }

/// Suggestion model (from Geoapify)
class PlaceSuggestion {
  final String name;
  final double lat;
  final double lon;

  PlaceSuggestion({
    required this.name,
    required this.lat,
    required this.lon,
  });
}

/// One colored segment of the route (for map styling)
class ColoredSegment {
  final List<LatLng> points;
  final Color color;

  ColoredSegment({
    required this.points,
    required this.color,
  });
}

class RoutingEngineProvider extends ChangeNotifier {
  // =======================
  // CONFIG
  // =======================

  /// Your backend server (make sure this matches your Mac IP)
  static const String _backendBaseUrl = 'http://192.168.114.184:5001';

  /// Geoapify API Key
  static const String geoapifyKey = "32bb4486a6864bbbb20904ff39d832ca";

  // =======================
  // OLD LIST VIEW
  // =======================

  List<RouteModel> _routes = [];
  bool _isLoading = false;

  List<RouteModel> get routes => _routes;
  bool get isLoading => _isLoading;

  Future<void> fetchRoutes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('$_backendBaseUrl/api/routing/generate');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _routes = (data['routes'] as List)
            .map((routeJson) => RouteModel.fromJson(routeJson))
            .toList();
      } else {
        _routes = [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching routes list: $e');
      }
      _routes = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // =======================
  // MAP ROUTING STATE
  // =======================

  RouteProfile _activeProfile = RouteProfile.balanced;
  RouteProfile get activeProfile => _activeProfile;

  LatLng? _startPoint;
  LatLng? _endPoint;

  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;

  // Suggestions
  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _endSuggestions = [];

  List<PlaceSuggestion> get startSuggestions => _startSuggestions;
  List<PlaceSuggestion> get endSuggestions => _endSuggestions;

  // Route geometry (all points, for centering map etc.)
  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;

  // Color-coded segments
  List<ColoredSegment> _segments = [];
  List<ColoredSegment> get segments => _segments;

  /// Polylines ready for FlutterMap
  List<Polyline> get coloredPolylines => _segments
      .map(
        (s) => Polyline(
          points: s.points,
          color: s.color,
          strokeWidth: 5,
        ),
      )
      .toList();

  double _totalDistanceKm = 0.0;
  int _totalHazards = 0;
  double _avgPoiScore = 0.0;

  double get totalDistanceKm => _totalDistanceKm;
  int get totalHazards => _totalHazards;
  double get avgPoiScore => _avgPoiScore;

  bool _isRouting = false;
  bool get isRouting => _isRouting;

  // =======================
  // Set Profile
  // =======================

  Future<void> setProfile(RouteProfile profile) async {
    _activeProfile = profile;
    notifyListeners();

    if (_startPoint != null && _endPoint != null) {
      await _fetchRouteInternal();
    }
  }

  String _profileToString(RouteProfile profile) {
    switch (profile) {
      case RouteProfile.shortest:
        return 'shortest';
      case RouteProfile.safest:
        return 'safest';
      case RouteProfile.scenic:
        return 'scenic';
      case RouteProfile.balanced:
      default:
        return 'balanced';
    }
  }

  // =======================
  // GEOAPIFY AUTOCOMPLETE
  // =======================

  Future<void> searchPlaces(String query, {required bool isStart}) async {
    if (query.length < 3) {
      if (isStart) {
        _startSuggestions = [];
      } else {
        _endSuggestions = [];
      }
      notifyListeners();
      return;
    }

    final url = Uri.parse(
      "https://api.geoapify.com/v1/geocode/autocomplete"
      "?text=$query&filter=countrycode:lk&limit=10&apiKey=$geoapifyKey",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print("❌ Geoapify HTTP error: ${response.statusCode}");
        }
        return;
      }

      final data = jsonDecode(response.body);
      List features = data["features"] ?? [];

      List<PlaceSuggestion> out = [];

      for (var f in features) {
        final p = f["properties"];
        out.add(
          PlaceSuggestion(
            name: p["formatted"] ?? p["address_line1"] ?? "Unknown place",
            lat: (p["lat"] as num).toDouble(),
            lon: (p["lon"] as num).toDouble(),
          ),
        );
      }

      if (isStart) {
        _startSuggestions = out;
      } else {
        _endSuggestions = out;
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Geoapify error: $e");
      }
    }

    notifyListeners();
  }

  // =======================
  // SELECT SUGGESTION
  // =======================

  Future<void> selectSuggestion(
    PlaceSuggestion suggestion, {
    required bool isStart,
  }) async {
    final point = LatLng(suggestion.lat, suggestion.lon);

    if (isStart) {
      _startPoint = point;
      _startSuggestions = [];
    } else {
      _endPoint = point;
      _endSuggestions = [];
    }

    notifyListeners();

    if (_startPoint != null && _endPoint != null) {
      await _fetchRouteInternal();
    }
  }

  // =============================
  // USE CURRENT LOCATION AS START
  // =============================

  Future<void> useCurrentLocationAsStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check service
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print("❌ Location services disabled");
      }
      return;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print("❌ Location permission denied");
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print("❌ Location permission permanently denied");
      }
      return;
    }

    // Get location
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _startPoint = LatLng(position.latitude, position.longitude);
    _startSuggestions = [];

    if (kDebugMode) {
      print("📍 Current location: $_startPoint");
    }

    notifyListeners();

    if (_startPoint != null && _endPoint != null) {
      await _fetchRouteInternal();
    }
  }

  // =======================
  // ROUTING TO BACKEND
  // =======================

  Future<void> _fetchRouteInternal() async {
    if (_startPoint == null || _endPoint == null) return;

    _isRouting = true;
    _routePoints = [];
    _segments = [];
    notifyListeners();

    try {
      final profileStr = _profileToString(_activeProfile);

      final url = Uri.parse(
        "$_backendBaseUrl/api/pg-routing/route"
        "?startLon=${_startPoint!.longitude}"
        "&startLat=${_startPoint!.latitude}"
        "&endLon=${_endPoint!.longitude}"
        "&endLat=${_endPoint!.latitude}"
        "&profile=$profileStr",
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print("❌ Routing error ${response.statusCode} ${response.body}");
        }
        _isRouting = false;
        notifyListeners();
        return;
      }

      final json = jsonDecode(response.body);

      // ---------- Summary ----------
      final summary = json["summary"];
      _totalDistanceKm =
          (summary["totalDistanceKm"] as num?)?.toDouble() ?? 0.0;
      _totalHazards = (summary["totalHazard"] as num?)?.toInt() ?? 0;
      _avgPoiScore = (summary["avgPoiScore"] as num?)?.toDouble() ?? 0.0;

      // ---------- Edges (color-coded) ----------
      final edges = json["edges"] as List<dynamic>? ?? [];

      final allPoints = <LatLng>[];
      final segments = <ColoredSegment>[];

      for (final edge in edges) {
        final geo = edge["geojson"];
        if (geo == null) continue;

        final coords = geo["coordinates"] as List<dynamic>? ?? [];
        final segPoints = <LatLng>[];

        for (final c in coords) {
          if (c is List && c.length >= 2) {
            final lon = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            final p = LatLng(lat, lon);
            segPoints.add(p);
            allPoints.add(p);
          }
        }

        if (segPoints.isEmpty) continue;

        // Read hazard & POI values for this edge
        final num hazardCountRaw =
            (edge["hazardCount"] ??
                    edge["hazard_count"] ??
                    edge["hazard_score"] ??
                    0) as num;
        final num poiScoreRaw =
            (edge["poiScore"] ?? edge["poi_score"] ?? 0) as num;

        final hazardCount = hazardCountRaw.toDouble();
        final poiScore = poiScoreRaw.toDouble();

        Color color;

        // Base on hazard
        if (hazardCount >= 5) {
          // high risk
          color = const Color(0xFFE53935); // red
        } else if (hazardCount >= 2) {
          // medium risk
          color = const Color(0xFFFFA726); // orange
        } else {
          // low risk / safe
          color = const Color(0xFF43A047); // green
        }

        // If scenic profile important, let high scenic override hazard
        if (poiScore > 0 && poiScore >= 0.6) {
          color = const Color(0xFF1E88E5); // blue for scenic
        }

        segments.add(
          ColoredSegment(points: segPoints, color: color),
        );
      }

      _routePoints = allPoints;
      _segments = segments;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Route error: $e");
      }
      _routePoints = [];
      _segments = [];
    }

    _isRouting = false;
    notifyListeners();
  }

  // =======================
  // CLEAR
  // =======================

  void clearRoute() {
    _startPoint = null;
    _endPoint = null;
    _routePoints = [];
    _segments = [];
    _totalDistanceKm = 0;
    _totalHazards = 0;
    _avgPoiScore = 0;
    _startSuggestions = [];
    _endSuggestions = [];
    notifyListeners();
  }
}
