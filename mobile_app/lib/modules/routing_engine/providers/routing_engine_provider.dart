// lib/modules/routing_engine/providers/routing_engine_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class RoutingEngineProvider extends ChangeNotifier {
  // =======================
  // CONFIG
  // =======================

  /// Backend server
  static const String _backendBaseUrl = 'http://192.168.8.176:5001';

  /// Geoapify API Key 
  static const String geoapifyKey = "32bb4486a6864bbbb20904ff39d832ca";

  // =======================
  // OLD LIST VIEW (test screen)
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
      print('❌ Error fetching routes list: $e');
      _routes = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // =======================
  // NEW: MAP ROUTING STATE
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

  // Final route points
  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;

  double _totalDistanceKm = 0.0;
  int _totalHazards = 0;
  double _avgPoiScore = 0.0;

  double get totalDistanceKm => _totalDistanceKm;
  int get totalHazards => _totalHazards;
  double get avgPoiScore => _avgPoiScore;

  bool _isRouting = false;
  bool get isRouting => _isRouting;

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
  // GEOAPIFY AUTOCOMPLETE SEARCH
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
        print("❌ Geoapify HTTP error: ${response.statusCode}");
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
            lat: p["lat"],
            lon: p["lon"],
          ),
        );
      }

      if (isStart) {
        _startSuggestions = out;
      } else {
        _endSuggestions = out;
      }
    } catch (e) {
      print("❌ Geoapify error: $e");
    }

    notifyListeners();
  }

  // =======================
  // WHEN USER SELECTS A SUGGESTION
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

  // =======================
  // ROUTING CALL TO BACKEND
  // =======================

  Future<void> _fetchRouteInternal() async {
    if (_startPoint == null || _endPoint == null) return;

    _isRouting = true;
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
        print("❌ Routing error ${response.statusCode}");
        _isRouting = false;
        notifyListeners();
        return;
      }

      final json = jsonDecode(response.body);

      // Summary
      final summary = json["summary"];
      _totalDistanceKm =
          (summary["totalDistanceKm"] as num?)?.toDouble() ?? 0.0;
      _totalHazards = (summary["totalHazard"] as num?)?.toInt() ?? 0;
      _avgPoiScore = (summary["avgPoiScore"] as num?)?.toDouble() ?? 0.0;

      // Coordinates
      List<LatLng> points = [];
      for (var edge in json["edges"]) {
        var geo = edge["geojson"];
        for (var c in geo["coordinates"]) {
          points.add(LatLng(c[1], c[0])); // lat, lon
        }
      }

      _routePoints = points;
    } catch (e) {
      print("❌ Route error: $e");
      _routePoints = [];
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
    _totalDistanceKm = 0;
    _totalHazards = 0;
    _avgPoiScore = 0;
    _startSuggestions = [];
    _endSuggestions = [];
    notifyListeners();
  }
}
