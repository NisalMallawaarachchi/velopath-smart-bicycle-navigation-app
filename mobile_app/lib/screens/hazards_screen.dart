// screens/hazards_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class HazardsScreen extends StatefulWidget {
  const HazardsScreen({super.key});

  @override
  State<HazardsScreen> createState() => _HazardsScreenState();
}

class _HazardsScreenState extends State<HazardsScreen> {
  final MapController _mapController = MapController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _hazards = [];
  bool _loading = true;
  String? _error;
  LatLng _center = const LatLng(6.9271, 79.8612); // Default: Colombo
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadHazards();
  }

  // ─────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────

  Future<void> _loadHazards() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get GPS location
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 8));
        _center = LatLng(pos.latitude, pos.longitude);
      }

      // Fetch hazards in bounding box (~2km radius)
      const double delta = 0.018;
      final uri = Uri.parse(
        '${ApiConfig.hazards}'
        '?minLat=${_center.latitude - delta}'
        '&maxLat=${_center.latitude + delta}'
        '&minLon=${_center.longitude - delta}'
        '&maxLon=${_center.longitude + delta}'
        '&minConfidence=0.3',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hazards = List<Map<String, dynamic>>.from(data['hazards'] ?? []);
          _loading = false;
        });
        if (_mapReady) {
          _mapController.move(_center, 15.0);
        }
      } else {
        setState(() {
          _error = 'Server error (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load hazards: $e';
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────
  // VOTING
  // ─────────────────────────────────────────────────────────

  Future<void> _vote(String hazardId, String action) async {
    // Get token from secure storage (same key as auth_provider)
    final token = await _storage.read(key: 'velopath_jwt_token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to confirm or deny hazards'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Log In',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
      return;
    }

    final url = action == 'confirm'
        ? ApiConfig.confirmHazard(hazardId)
        : ApiConfig.denyHazard(hazardId);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'comment': ''}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final newConf = double.tryParse(data['new_confidence'].toString()) ?? 0.0;
        final newStatus = data['status'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'confirm'
                  ? '✅ Confirmed! Confidence: ${(newConf * 100).toStringAsFixed(0)}%  [$newStatus]'
                  : '❌ Marked as gone. Confidence: ${(newConf * 100).toStringAsFixed(0)}%',
            ),
            backgroundColor:
                action == 'confirm' ? Colors.green.shade700 : Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadHazards(); // Refresh markers
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Already voted on this hazard'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Could not submit vote')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // BOTTOM SHEET
  // ─────────────────────────────────────────────────────────

  void _showHazardSheet(Map<String, dynamic> hazard) {
    final conf = double.tryParse(hazard['confidence'].toString()) ?? 0.0;
    final type = (hazard['type'] ?? 'unknown') as String;
    final status = (hazard['status'] ?? 'pending') as String;
    final confirms = hazard['confirmationCount'] ?? 0;
    final detections = hazard['detectionCount'] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + status badge
            Row(
              children: [
                Icon(_hazardIcon(type), color: _markerColor(hazard), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'pothole' ? '🕳 Pothole' : '🚧 Speed Bump',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      _statusBadge(status),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Confidence bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confidence',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${(conf * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _confidenceColor(conf),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: conf,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_confidenceColor(conf)),
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _statChip(Icons.sensors, '$detections', 'detections', Colors.blue),
                const SizedBox(width: 12),
                _statChip(Icons.check_circle_outline, '$confirms',
                    'confirmations', Colors.green),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Still There'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _vote(hazard['id'], 'confirm');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Not There'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _vote(hazard['id'], 'deny');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

  Color _markerColor(Map<String, dynamic> h) {
    final status = h['status'] ?? '';
    final type = h['type'] ?? '';
    if (status == 'verified') return Colors.red.shade700;
    if (type == 'pothole') return Colors.red.shade400;
    return Colors.orange.shade500;
  }

  Color _confidenceColor(double conf) {
    if (conf >= 0.80) return Colors.green.shade600;
    if (conf >= 0.50) return Colors.orange.shade600;
    return Colors.red.shade500;
  }

  IconData _hazardIcon(String type) =>
      type == 'pothole' ? Icons.report_problem : Icons.speed;

  Widget _statusBadge(String status) {
    final isVerified = status == 'verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified ? Colors.green.shade400 : Colors.orange.shade400,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isVerified ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFF4A90D9) : const Color(0xFF0E417A);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazard Map'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_hazards.length} hazards',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHazards,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.0,
              onMapReady: () {
                setState(() => _mapReady = true);
                _mapController.move(_center, 15.0);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.velopath.app',
              ),
              MarkerLayer(
                markers: _hazards.map((h) {
                  final loc = h['location'] as Map<String, dynamic>;
                  final lat = (loc['lat'] as num).toDouble();
                  final lon = (loc['lon'] as num).toDouble();
                  final conf =
                      double.tryParse(h['confidence'].toString()) ?? 0.0;

                  return Marker(
                    point: LatLng(lat, lon),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showHazardSheet(h),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Confidence ring
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              value: conf,
                              strokeWidth: 3.5,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _confidenceColor(conf)),
                            ),
                          ),
                          // Marker circle + icon
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _markerColor(h),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _hazardIcon(h['type'] ?? ''),
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── LOADING OVERLAY ───────────────────────────────
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading hazards...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── ERROR BANNER ──────────────────────────────────
          if (_error != null && !_loading)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                borderRadius: BorderRadius.circular(10),
                color: Colors.red.shade700,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadHazards,
                        child: const Icon(Icons.refresh,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── NOT LOGGED IN BANNER ──────────────────────────
          if (!authProvider.isLoggedIn)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(10),
                color: Colors.orange.shade700,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Log in to confirm or deny hazards',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                        child: const Text('Log In',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── LEGEND ───────────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Legend',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    _legendRow(Colors.red.shade700, Icons.report_problem,
                        'Pothole (verified)'),
                    _legendRow(Colors.red.shade400, Icons.report_problem,
                        'Pothole (pending)'),
                    _legendRow(Colors.orange.shade500, Icons.speed,
                        'Speed Bump'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
