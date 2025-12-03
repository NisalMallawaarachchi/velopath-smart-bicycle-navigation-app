// lib/modules/routing_engine/providers/routing_engine_provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../data/models/route_model.dart';

/// Route types
enum RouteProfile { shortest, safest, scenic, balanced }

/// Suggestion from Geoapify
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

/// A colored map segment
class ColoredSegment {
  final List<LatLng> points;
  final Color color;

  ColoredSegment({
    required this.points,
    required this.color,
  });
}

/// Navigation instruction
class TurnInstruction {
  final String text;
  final double distanceMeters;
  final LatLng location;

  TurnInstruction({
    required this.text,
    required this.distanceMeters,
    required this.location,
  });
}

class RoutingEngineProvider extends ChangeNotifier {
  // =======================
  // CONFIG
  // =======================

  static const String _backendBaseUrl = "http://192.168.8.176:5001";
  static const String geoapifyKey = "32bb4486a6864bbbb20904ff39d832ca";

  // =======================
  // STATE
  // =======================

  LatLng? _startPoint;
  LatLng? _endPoint;

  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;

  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _endSuggestions = [];

  List<PlaceSuggestion> get startSuggestions => _startSuggestions;
  List<PlaceSuggestion> get endSuggestions => _endSuggestions;

  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;

  List<ColoredSegment> _segments = [];
  List<ColoredSegment> get segments => _segments;

  List<Polyline> get coloredPolylines =>
      _segments.map((s) => Polyline(points: s.points, color: s.color, strokeWidth: 5)).toList();

  RouteProfile _activeProfile = RouteProfile.balanced;
  RouteProfile get activeProfile => _activeProfile;

  // Summary
  double _totalDistanceKm = 0;
  int _totalHazards = 0;
  double _avgPoiScore = 0;

  double get totalDistanceKm => _totalDistanceKm;
  int get totalHazards => _totalHazards;
  double get avgPoiScore => _avgPoiScore;

  // Navigation
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  double _heading = 0.0;
  double get heading => _heading;

  List<TurnInstruction> _instructions = [];
  List<TurnInstruction> get instructions => _instructions;

  int _currentInstructionIndex = 0;
  int get currentInstructionIndex => _currentInstructionIndex;

  TurnInstruction? get currentInstruction =>
      _instructions.isEmpty ? null : _instructions[_currentInstructionIndex];

  StreamSubscription<Position>? _positionSub;

  bool _isRouting = false;
  bool get isRouting => _isRouting;

  // =======================
  // OLD LIST VIEW (optional screen)
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
  // PROFILE SELECTION
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
      final features = data["features"] as List? ?? [];

      final out = <PlaceSuggestion>[];

      for (final f in features) {
        final p = f["properties"] ?? {};
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

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print("❌ Location services disabled");
      }
      return;
    }

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
  // START / STOP NAVIGATION
  // =======================

  Future<void> startNavigation() async {
    if (_routePoints.length < 2) return;

    if (_instructions.isEmpty) {
      _buildTurnInstructions();
    }

    _isNavigating = true;
    _currentInstructionIndex = 0;
    notifyListeners();

    await _startListeningToPosition();
  }

  Future<void> stopNavigation() async {
    _isNavigating = false;
    _currentLocation = null;
    _heading = 0;
    await _positionSub?.cancel();
    _positionSub = null;
    notifyListeners();
  }

  Future<void> _startListeningToPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print("❌ Navigation position permission denied");
        }
        return;
      }
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    final newLocation = LatLng(pos.latitude, pos.longitude);

    // heading
    if (pos.heading != null && pos.heading >= 0) {
      _heading = pos.heading;
    } else if (_currentLocation != null) {
      _heading = _bearing(_currentLocation!, newLocation);
    }

    _currentLocation = newLocation;

    // advance instruction when close
    if (_isNavigating &&
        _instructions.isNotEmpty &&
        _currentInstructionIndex < _instructions.length - 1) {
      final currInstr = _instructions[_currentInstructionIndex];
      final d = Distance();
      final distToInstr = d.as(
        LengthUnit.Meter,
        _currentLocation!,
        currInstr.location,
      );

      if (distToInstr < 30) {
        _currentInstructionIndex++;
      }
    }

    notifyListeners();
  }

  // =======================
  // BUILD TURN INSTRUCTIONS
  // =======================

  void _buildTurnInstructions() {
    _instructions = [];

    if (_routePoints.length < 2) return;

    final distanceCalc = Distance();

    // Start
    _instructions.add(
      TurnInstruction(
        text: "Start riding",
        distanceMeters: 0,
        location: _routePoints.first,
      ),
    );

    double segmentDistance = 0;
    LatLng prev = _routePoints.first;

    for (int i = 1; i < _routePoints.length - 1; i++) {
      final curr = _routePoints[i];
      final next = _routePoints[i + 1];

      segmentDistance += distanceCalc.as(LengthUnit.Meter, prev, curr);

      final bearing1 = _bearing(prev, curr);
      final bearing2 = _bearing(curr, next);
      var angle = bearing2 - bearing1;

      // normalize to -180..180
      while (angle > 180) angle -= 360;
      while (angle < -180) angle += 360;

      String? text;

      if (angle > 35) {
        text = "Turn right";
      } else if (angle < -35) {
        text = "Turn left";
      } else if (segmentDistance > 300) {
        text = "Continue straight";
      }

      if (text != null) {
        _instructions.add(
          TurnInstruction(
            text: "$text in ${segmentDistance.toStringAsFixed(0)} m",
            distanceMeters: segmentDistance,
            location: curr,
          ),
        );
        segmentDistance = 0;
      }

      prev = curr;
    }

    // Arrival
    _instructions.add(
      TurnInstruction(
        text: "You have arrived",
        distanceMeters: 0,
        location: _routePoints.last,
      ),
    );
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    var brng = math.atan2(y, x);
    brng = brng * 180 / math.pi;
    return (brng + 360) % 360;
  }

  double _degToRad(double d) => d * math.pi / 180;

  // =======================
  // ROUTING TO BACKEND
  // =======================

  Future<void> _fetchRouteInternal() async {
    if (_startPoint == null || _endPoint == null) return;

    _isRouting = true;
    _routePoints = [];
    _segments = [];
    _instructions = [];
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

      // ---- summary ----
      final summary = json["summary"] ?? {};
      _totalDistanceKm =
          (summary["totalDistanceKm"] as num?)?.toDouble() ?? 0.0;
      _totalHazards = (summary["totalHazard"] as num?)?.toInt() ?? 0;
      _avgPoiScore = (summary["avgPoiScore"] as num?)?.toDouble() ?? 0.0;

      // ---- edges ----
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

        if (hazardCount >= 5) {
          color = const Color(0xFFE53935); // high
        } else if (hazardCount >= 2) {
          color = const Color(0xFFFFA726); // medium
        } else {
          color = const Color(0xFF43A047); // low
        }

        // scenic override
        if (poiScore >= 0.6) {
          color = const Color(0xFF1E88E5);
        }

        segments.add(ColoredSegment(points: segPoints, color: color));
      }

      _routePoints = allPoints;
      _segments = segments;

      // build instructions
      _buildTurnInstructions();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Route error: $e");
      }
      _routePoints = [];
      _segments = [];
      _instructions = [];
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
    _instructions = [];
    _totalDistanceKm = 0;
    _totalHazards = 0;
    _avgPoiScore = 0;
    _startSuggestions = [];
    _endSuggestions = [];
    stopNavigation();
  }
}
