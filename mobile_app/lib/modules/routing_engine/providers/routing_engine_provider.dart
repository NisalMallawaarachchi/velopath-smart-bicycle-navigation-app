import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum RouteProfile { shortest, safest, scenic, balanced }

class PlaceSuggestion {
  final String name;
  final double lat;
  final double lon;

  PlaceSuggestion({required this.name, required this.lat, required this.lon});
}

class TurnInstruction {
  final String textEn;
  final LatLng location;

  TurnInstruction({required this.textEn, required this.location});
}

class ColoredSegment {
  final List<LatLng> points;
  final Color color;

  ColoredSegment({required this.points, required this.color});
}

class MapPoi {
  final String id;
  final String name;
  final String amenity;
  final LatLng location;

  MapPoi({
    required this.id,
    required this.name,
    required this.amenity,
    required this.location,
  });
}

class MapHazard {
  final String id;
  final String type;
  final LatLng location;

  MapHazard({
    required this.id,
    required this.type,
    required this.location,
  });
}

class RoutingEngineProvider extends ChangeNotifier {
  static const _backendBaseUrl = "http://127.0.0.1:5001";
  static const _geoapifyKey = "32bb4486a6864bbbb20904ff39d832ca";

  final FlutterTts _tts = FlutterTts();
  final Distance _distance = Distance();

  RouteProfile _activeProfile = RouteProfile.balanced;
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation;

  final List<LatLng> _routePoints = [];
  final List<TurnInstruction> _instructions = [];
  List<ColoredSegment> _segments = [];

  final List<MapPoi> _routePois = [];
  final List<MapHazard> _routeHazards = [];

  final List<PlaceSuggestion> _startSuggestions = [];
  final List<PlaceSuggestion> _endSuggestions = [];

  int _currentInstructionIndex = 0;
  bool _isNavigating = false;
  bool _isSpeaking = false;

  String? _currentAlertMessage;
  final Set<String> _alertedPoiIds = {};
  final Set<String> _alertedHazardIds = {};

  double _totalDistanceKm = 0;
  int _totalHazards = 0;
  double _avgPoiScore = 0.0;

  StreamSubscription<Position>? _posSub;
  int _fetchRouteId = 0;

  // ================= GETTERS =================
  RouteProfile get activeProfile => _activeProfile;
  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;
  LatLng? get currentLocation => _currentLocation;
  List<LatLng> get routePoints => _routePoints;
  List<TurnInstruction> get instructions => _instructions;
  List<MapPoi> get routePois => _routePois;
  List<MapHazard> get routeHazards => _routeHazards;
  int get currentInstructionIndex => _currentInstructionIndex;
  bool get isNavigating => _isNavigating;
  String? get currentAlertMessage => _currentAlertMessage;
  double get totalDistanceKm => _totalDistanceKm;
  int get totalHazards => _totalHazards;
  double get avgPoiScore => _avgPoiScore;
  DateTime? _navigationStartedAt;
  LatLng? _lastLocation;
  double _distanceMoved = 0;
  String _profileToParam(RouteProfile profile) {
    switch (profile) {
      case RouteProfile.shortest:
        return "shortest";
      case RouteProfile.balanced:
        return "balanced";
      case RouteProfile.safest:
        return "safest";
      case RouteProfile.scenic:
        return "scenic";
    }
  }

  TurnInstruction? get currentInstruction =>
      (_currentInstructionIndex < _instructions.length)
      ? _instructions[_currentInstructionIndex]
      : null;

  List<PlaceSuggestion> get startSuggestions => _startSuggestions;
  List<PlaceSuggestion> get endSuggestions => _endSuggestions;

  List<Polyline> get coloredPolylines => _segments
      .map((s) => Polyline(points: s.points, strokeWidth: 5, color: s.color))
      .toList();

  RoutingEngineProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.25);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking || text.trim().isEmpty) return;
    _isSpeaking = true;
    try {
      await _tts.speak(text);
    } finally {
      _isSpeaking = false;
    }
  }

  // ================= SEARCH =================
  Future<void> searchPlaces(String q, {required bool isStart}) async {
    if (q.length < 3) {
      if (isStart)
        _startSuggestions.clear();
      else
        _endSuggestions.clear();
      notifyListeners();
      return;
    }

    final url = Uri.parse(
      "https://api.geoapify.com/v1/geocode/autocomplete"
      "?text=$q&filter=countrycode:lk&limit=10&apiKey=$_geoapifyKey",
    );

    final res = await http.get(url);
    if (res.statusCode != 200) return;

    final items = (jsonDecode(res.body)["features"] as List)
        .map(
          (f) => PlaceSuggestion(
            name: f["properties"]["formatted"],
            lat: f["properties"]["lat"],
            lon: f["properties"]["lon"],
          ),
        )
        .toList();

    if (isStart) {
      _startSuggestions
        ..clear()
        ..addAll(items);
    } else {
      _endSuggestions
        ..clear()
        ..addAll(items);
    }

    notifyListeners();
  }

  Future<void> selectSuggestion(
    PlaceSuggestion s, {
    required bool isStart,
  }) async {
    if (isStart) {
      _startPoint = LatLng(s.lat, s.lon);
      _startSuggestions.clear();
    } else {
      _endPoint = LatLng(s.lat, s.lon);
      _endSuggestions.clear();
    }

    if (_startPoint != null && _endPoint != null) {
      await _fetchRoute();
    } else {
      notifyListeners();
    }
  }

  // ================= PROFILE =================
  Future<void> setProfile(RouteProfile p) async {
    _activeProfile = p;
    notifyListeners();

    if (_startPoint != null && _endPoint != null) {
      await _fetchRoute();
    }
  }

  // ================= LOCATION =================
  Future<void> useCurrentLocationAsStart() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    _startPoint = LatLng(pos.latitude, pos.longitude);

    if (_endPoint != null) {
      await _fetchRoute();
    } else {
      notifyListeners();
    }
  }

  // ================= ROUTING =================
  Future<void> _fetchRoute() async {
    final int currentFetchId = ++_fetchRouteId;

    _routePoints.clear();
    _instructions.clear();
    _segments.clear();
    _routePois.clear();
    _routeHazards.clear();
    _currentInstructionIndex = 0;
    _totalDistanceKm = 0;
    _totalHazards = 0;
    _avgPoiScore = 0.0;

    try {
      final profileParam = _profileToParam(_activeProfile);

      final url = Uri.parse(
        "$_backendBaseUrl/api/pg-routing/route"
        "?startLon=${_startPoint!.longitude}"
        "&startLat=${_startPoint!.latitude}"
        "&endLon=${_endPoint!.longitude}"
        "&endLat=${_endPoint!.latitude}"
        "&mode=$profileParam",
      );

      print("🌐 Fetching route from: $url");

      final res = await http.get(url);

      // Discard stale responses if a newer fetch was initiated
      if (currentFetchId != _fetchRouteId) {
        print("⚠️ Discarding stale route response #$currentFetchId");
        return;
      }

      print("📡 Response status: ${res.statusCode}");
      print("📦 Response body: ${res.body}");

      if (res.statusCode != 200) {
        print("❌ Route fetch failed with status ${res.statusCode}");
        return;
      }

      final json = jsonDecode(res.body);

      print("✅ Parsed JSON: $json");

      // Check if geometry exists
      if (json["geometry"] == null) {
        print("❌ No geometry in response");
        return;
      }

      // Process geometry
      for (final c in json["geometry"]) {
        _routePoints.add(LatLng(c[1], c[0]));
      }
      print("✅ Loaded ${_routePoints.length} route points");

      // Process instructions
      if (json["instructions"] != null) {
        for (final i in json["instructions"]) {
          _instructions.add(
            TurnInstruction(
              textEn: i["textEn"],
              location: LatLng(i["lat"], i["lon"]),
            ),
          );
        }
        print("✅ Loaded ${_instructions.length} instructions");
      }

      // Create colored segment
      _segments.add(
        ColoredSegment(
          points: List.of(_routePoints),
          color: const Color(0xFF1E88E5),
        ),
      );
      print("✅ Created route segment");

      // Process POIs
      if (json["pois"] != null) {
        for (final p in json["pois"]) {
          _routePois.add(
            MapPoi(
              id: p["id"].toString(),
              name: p["name"] ?? "Point of Interest",
              amenity: p["amenity"] ?? "unknown",
              location: LatLng(
                (p["lat"] as num).toDouble(),
                (p["lon"] as num).toDouble(),
              ),
            ),
          );
        }
        print("✅ Loaded ${_routePois.length} route POIs");
      }

      // Process Hazards
      if (json["hazards"] != null) {
        for (final h in json["hazards"]) {
          _routeHazards.add(
            MapHazard(
              id: h["id"].toString(),
              type: h["type"] ?? "Hazard",
              location: LatLng(
                (h["lat"] as num).toDouble(),
                (h["lon"] as num).toDouble(),
              ),
            ),
          );
        }
        print("✅ Loaded ${_routeHazards.length} route Hazards");
      }

      // Get summary stats
      if (json["summary"] != null) {
        final summary = json["summary"];
        if (summary["totalDistanceKm"] != null) {
          _totalDistanceKm = (summary["totalDistanceKm"] as num).toDouble();
          print("✅ Total distance: $_totalDistanceKm km");
        }
        if (summary["totalHazards"] != null) {
          _totalHazards = (summary["totalHazards"] as num).toInt();
          print("✅ Total hazards: $_totalHazards");
        }
        if (summary["avgPoiScore"] != null) {
          _avgPoiScore = (summary["avgPoiScore"] as num).toDouble();
          print("✅ Avg POI score: $_avgPoiScore");
        }
      }

      notifyListeners();
      print("✅ Route fetch completed successfully");
    } catch (e, stackTrace) {
      print("❌ ERROR in _fetchRoute: $e");
      print("❌ Stack trace: $stackTrace");
    }
  }

  // ================= NAVIGATION =================
  Future<void> startNavigation() async {
    if (_instructions.isEmpty) return;

    _isNavigating = true;
    _currentInstructionIndex = 0;
    _navigationStartedAt = DateTime.now();
    _distanceMoved = 0;
    _lastLocation = null;
    _currentAlertMessage = null;
    _alertedPoiIds.clear();
    _alertedHazardIds.clear();

    // Speak AFTER navigation truly starts
    await _speak("Navigation started");

    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((pos) {
          final newLoc = LatLng(pos.latitude, pos.longitude);

          if (_lastLocation != null) {
            _distanceMoved += _distance.as(
              LengthUnit.Meter,
              _lastLocation!,
              newLoc,
            );
          }

          _lastLocation = newLoc;
          _currentLocation = newLoc;

          _checkInstructionProgress();
          _checkFeatureProximity();
          notifyListeners();
        });

    notifyListeners();
  }

  Future<void> stopNavigation() async {
    _isNavigating = false;
    _currentLocation = null;
    await _posSub?.cancel();
    notifyListeners();
  }

  // ================= TURN PROGRESS =================
  void _checkInstructionProgress() {
    if (!_isNavigating || _currentLocation == null) return;
    if (_currentInstructionIndex >= _instructions.length) return;

    // 🛑 Ignore first 3 seconds
    if (_navigationStartedAt != null &&
        DateTime.now().difference(_navigationStartedAt!).inSeconds < 3) {
      return;
    }

    // 🛑 Require at least 10 meters of movement
    if (_distanceMoved < 10) return;

    final instr = _instructions[_currentInstructionIndex];
    final d = _distance.as(LengthUnit.Meter, _currentLocation!, instr.location);

    // 🛑 Do NOT auto-arrive on first instruction
    if (_currentInstructionIndex == 0 && d < 15) {
      return;
    }

    // ✅ Arrival / turn threshold
    if (d <= 10) {
      _currentInstructionIndex++;

      if (_currentInstructionIndex < _instructions.length) {
        _speak(_instructions[_currentInstructionIndex].textEn);
      } else {
        _speak("You have arrived at your destination");
        stopNavigation();
      }
    }
  }

  // ================= FEATURE PROXIMITY CHECK =================
  void _checkFeatureProximity() {
    if (!_isNavigating || _currentLocation == null) return;

    const double alertDistanceMeters = 30.0; // Trigger alert within 30m

    // 1. Check Hazards (Priority text-to-speech)
    for (final hazard in _routeHazards) {
      if (_alertedHazardIds.contains(hazard.id)) continue;

      final dist = _distance.as(LengthUnit.Meter, _currentLocation!, hazard.location);
      if (dist <= alertDistanceMeters) {
        _alertedHazardIds.add(hazard.id);
        final titleType = hazard.type.toUpperCase();
        _currentAlertMessage = "⚠️ HAZARD AHEAD: $titleType";
        _speak("Caution, approaching a ${hazard.type.replaceAll('_', ' ')} hazard");
        
        // Clear visually after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentAlertMessage?.contains("HAZARD") == true) {
            _currentAlertMessage = null;
            notifyListeners();
          }
        });
        return; // Don't speak over it with a POI
      }
    }

    // 2. Check POIs
    for (final poi in _routePois) {
      if (_alertedPoiIds.contains(poi.id)) continue;

      final dist = _distance.as(LengthUnit.Meter, _currentLocation!, poi.location);
      if (dist <= alertDistanceMeters) {
        _alertedPoiIds.add(poi.id);
        _currentAlertMessage = "✨ NEARBY: ${poi.name}";
        _speak("You are nearing ${poi.name}");

        // Clear visually after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentAlertMessage?.contains("NEARBY") == true) {
            _currentAlertMessage = null;
            notifyListeners();
          }
        });
        return;
      }
    }
  }
}

