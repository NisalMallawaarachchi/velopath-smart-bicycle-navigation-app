import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/poi_map_screen.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../providers/theme_provider.dart';

class PoiScreen extends StatefulWidget {
  const PoiScreen({super.key});

  @override
  State<PoiScreen> createState() => _PoiScreenState();
}

class _PoiScreenState extends State<PoiScreen> {
  List<dynamic> pois = [];
  List<dynamic> filteredPois = [];
  bool isLoading = true;
  int loyaltyPoints = 0;

  String selectedDistrict = "All";
  String selectedTier = "All";
  String searchQuery = "";
  bool showLowQuality = false;

  LatLng? myLocation;
  final double displayRadiusKm = 5.0;
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    initAll();
  }

  Future<void> initAll() async {
    await getMyLocation(silent: true);
    await fetchPOIs();
  }

  Future<void> fetchPOIs() async {
    if (mounted) setState(() => isLoading = true);

    final districtParam = selectedDistrict != "All"
        ? "?district=${Uri.encodeComponent(selectedDistrict)}"
        : "";
    final url = "${ApiConfig.rankedPois}$districtParam";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        pois = List<dynamic>.from(data['pois']);
        for (var poi in pois) {
          poi['district'] ??= "Other";
          poi['tier'] ??= "new";
        }
        applyFilters();
      } else {
        throw Exception('Failed to load POIs (status ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("Error fetching POIs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching POIs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Mirrors the backend qualityTier logic.
  /// Returns "new" if no votes, otherwise "high"/"medium"/"low".
  String _recalculateTier(double score, int voteCount) {
    if (voteCount == 0) return "new";
    final normalizedScore = (score / 5) * 100;
    final scorePart = normalizedScore * 0.7;
    final votePart = math.log(1 + voteCount) * (30 / math.log(101));
    final qs = (scorePart + votePart).clamp(0.0, 100.0);
    if (qs >= 65) return "high";
    if (qs >= 35) return "medium";
    return "low";
  }

  void applyFilters() {
    final q = searchQuery.toLowerCase();

    final filtered = pois.where((poi) {
      final amenity   = (poi['amenity'] ?? "").toString().toLowerCase();
      final name      = (poi['name']    ?? "").toString().toLowerCase();
      final tier      = (poi['tier']    ?? "new").toString();
      final voteCount = _parseInt(poi['vote_count']);

      final matchesSearch = amenity.contains(q) || name.contains(q);

      // Filter by tier — "new" means strictly zero votes
      bool matchesTierFilter;
      if (selectedTier == "All") {
        matchesTierFilter = true;
      } else if (selectedTier == "new") {
        matchesTierFilter = voteCount == 0; // only genuinely unvoted POIs
      } else {
        matchesTierFilter = voteCount > 0 && tier == selectedTier;
      }

      // Unvoted POIs are always shown; low-tier POIs respect the toggle
      final matchesVisibility =
          voteCount == 0 || showLowQuality || tier != "low";

      bool matchesProximity = true;
      if (myLocation != null && selectedDistrict == "All") {
        final latRaw = poi['lat'];
        final lonRaw = poi['lon'];
        double? poiLat;
        double? poiLon;
        if (latRaw is String) poiLat = double.tryParse(latRaw);
        if (lonRaw is String) poiLon = double.tryParse(lonRaw);
        if (latRaw is num) poiLat = latRaw.toDouble();
        if (lonRaw is num) poiLon = lonRaw.toDouble();
        if (poiLat != null && poiLon != null) {
          final distKm =
              distance(LatLng(poiLat, poiLon), myLocation!) / 1000.0;
          matchesProximity = distKm <= displayRadiusKm;
        } else {
          matchesProximity = false;
        }
      }

      return matchesSearch &&
          matchesTierFilter &&
          matchesVisibility &&
          matchesProximity;
    }).toList();

    if (!mounted) return;
    setState(() => filteredPois = filtered);
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Future<void> getMyLocation({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      if (!mounted) return;
      setState(
          () => myLocation = LatLng(position.latitude, position.longitude));
      applyFilters();
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'high':   return Colors.green;
      case 'medium': return Colors.orange;
      case 'new':    return Colors.blue;
      default:       return Colors.grey;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'high':   return Icons.star_rounded;
      case 'medium': return Icons.star_half_rounded;
      case 'new':    return Icons.fiber_new_rounded;
      default:       return Icons.star_border_rounded;
    }
  }

  Widget _buildStarRow(double score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        if (starValue <= score) {
          icon = Icons.star_rounded;
        } else if (starValue - 0.5 <= score) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: Colors.amber, size: 14);
      }),
    );
  }

  Widget _buildPoiCard(Map<String, dynamic> poi) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : ThemeProvider.primaryDarkBlue;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final name      = poi['name']     ?? "Unnamed";
    final amenity   = poi['amenity']  ?? "";
    final district  = poi['district'] ?? "";
    final tier      = (poi['tier']    ?? "new").toString();
    final rawScore  = poi['adjustedScore'] ?? poi['score'] ?? 0;
    final voteCount = _parseInt(poi['vote_count']);
    final isNew     = voteCount == 0;

    final starScore = _parseDouble(rawScore);
    final displayTier = isNew ? 'new' : tier;
    final color = _tierColor(displayTier);
    final icon  = _tierIcon(displayTier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white12) : Border.all(color: Colors.transparent),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: ThemeProvider.primaryDarkBlue.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          if (!isDark && tier == 'high')
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (myLocation == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enable "Use My Location" first.')),
              );
              return;
            }

            final updatedPoi = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => POIMapScreen(
                  startPoint: myLocation!,
                  selectedPoi: poi,
                  onLoyaltyUpdated: (points) {
                    setState(() => loyaltyPoints += points);
                  },
                ),
              ),
            );

            if (updatedPoi != null) {
              setState(() {
                final index = pois.indexWhere((p) => p['id'] == updatedPoi['id']);
                if (index != -1) {
                  final merged = Map<String, dynamic>.from(pois[index]);
                  merged['score']         = updatedPoi['score']         ?? merged['score'];
                  merged['vote_count']    = updatedPoi['vote_count']    ?? merged['vote_count'];
                  merged['adjustedScore'] = updatedPoi['adjustedScore'] ?? merged['adjustedScore'];

                  final newScore      = _parseDouble(merged['score']);
                  final newVoteCount  = _parseInt(merged['vote_count']);
                  merged['tier'] = _recalculateTier(newScore, newVoteCount);

                  pois[index] = merged;
                  applyFilters();
                }
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              isNew ? "NEW" : tier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "$amenity • $district",
                              style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isNew ? ThemeProvider.accentCyan.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: isNew
                                ? const Text(
                                    "Be the first to rate",
                                    style: TextStyle(fontSize: 11, color: ThemeProvider.accentCyan, fontWeight: FontWeight.bold),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStarRow(starScore),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${starScore.toStringAsFixed(1)} (👥 $voteCount)",
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, thickness: 1.5)),
        ],
      ),
    );
  }

  List<Widget> _buildSectionedList() {
    final ranked = filteredPois.where((p) => _parseInt(p['vote_count']) > 0).toList();
    final newPois = filteredPois.where((p) => _parseInt(p['vote_count']) == 0).toList();

    final items = <Widget>[];

    if (ranked.isNotEmpty) {
      items.add(_buildSectionHeader("Rated Places", Icons.star_rounded, Colors.orange));
      for (final poi in ranked) {
        items.add(_buildPoiCard(Map<String, dynamic>.from(poi)));
      }
    }

    if (newPois.isNotEmpty) {
      items.add(_buildSectionHeader("New Unrated Places", Icons.fiber_new_rounded, ThemeProvider.accentCyan));
      for (final poi in newPois) {
        items.add(_buildPoiCard(Map<String, dynamic>.from(poi)));
      }
    }

    return items;
  }

  int get _lowQualityTotal => pois.where((p) => (p['tier'] ?? 'new') == 'low').length;

  int get _newTotal => pois.where((p) => _parseInt(p['vote_count']) == 0).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Places to visit",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: ThemeProvider.primaryDarkBlue,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: ThemeProvider.accentCyan.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
          ],
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: ThemeProvider.accentCyan,
          icon: const Icon(Icons.add_location_alt, color: ThemeProvider.primaryDarkBlue),
          label: const Text("Add POI", style: TextStyle(color: ThemeProvider.primaryDarkBlue, fontWeight: FontWeight.bold)),
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddPOIScreen()),
            );
            if (added == true) fetchPOIs();
          },
        ),
      ),
      body: Column(
        children: [
          // ── Minimalist Filter Section ──
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151E2E) : Colors.white,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDistrict,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            dropdownColor: inputBgColor,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: [
                              "All", "Colombo", "Gampaha", "Kalutara", "Kandy",
                              "Matale", "Nuwara Eliya", "Galle", "Matara",
                              "Hambantota", "Jaffna", "Kilinochchi", "Mannar",
                              "Vavuniya", "Mullaitivu", "Batticaloa", "Ampara",
                              "Trincomalee", "Kurunegala", "Puttalam", "Anuradhapura",
                              "Polonnaruwa", "Badulla", "Monaragala", "Ratnapura",
                              "Kegalle",
                            ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => selectedDistrict = val);
                              fetchPOIs();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTier,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            dropdownColor: inputBgColor,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: [
                              DropdownMenuItem(value: "All", child: Text("All Tiers", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                              DropdownMenuItem(value: "new", child: Text("New", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue))),
                              DropdownMenuItem(value: "high", child: Text("High", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green))),
                              DropdownMenuItem(value: "medium", child: Text("Medium", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange))),
                              DropdownMenuItem(value: "low", child: Text("Low", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey))),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => selectedTier = val);
                              applyFilters();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search type (e.g. cafe, repair)",
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          onChanged: (val) {
                            searchQuery = val.toLowerCase();
                            applyFilters();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeProvider.primaryDarkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location, color: ThemeProvider.primaryDarkBlue),
                        onPressed: () => getMyLocation(silent: false),
                        tooltip: "Near Me",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Row 2: Tier dropdown ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: DropdownButtonFormField<String>(
              value: selectedTier,
              decoration: const InputDecoration(
                labelText: "Quality Tier",
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: "All",
                  child: Row(children: [
                    const Icon(Icons.layers,
                        size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    const Text("All Tiers"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "new",
                  child: Row(children: [
                    const Icon(Icons.fiber_new_rounded,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Text("New (Unrated)"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "high",
                  child: Row(children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: Colors.green[600]),
                    const SizedBox(width: 6),
                    const Text("High Quality"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "medium",
                  child: Row(children: [
                    const Icon(Icons.star_half_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text("Medium Quality"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "low",
                  child: Row(children: [
                    const Icon(Icons.star_border_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text("Low Quality"),
                  ]),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => selectedTier = val);
                applyFilters();
              },
            ),
          ),

          // ── Row 3: Search field ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by type (park,cafe…)",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                searchQuery = val.toLowerCase();
                applyFilters();
              },
            ),
          ),

          // ── Row 4: Stats badges + toggle ─── uses Wrap ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_newTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text("$_lowQualityTotal low hidden", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() => showLowQuality = !showLowQuality);
                        applyFilters();
                      },
                      child: Text(
                        showLowQuality ? "Hide Low" : "Show All",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemeProvider.primaryDarkBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${filteredPois.length} place${filteredPois.length == 1 ? '' : 's'} found",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: ThemeProvider.accentCyan))
                : filteredPois.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "No POIs found.",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade500),
                            ),
                            if (!showLowQuality && _lowQualityTotal > 0) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => showLowQuality = true);
                                  applyFilters();
                                },
                                child: const Text("Show low quality POIs too?", style: TextStyle(color: ThemeProvider.primaryDarkBlue, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: _buildSectionedList(),
                      ),
          ),
        ],
      ),
    );
  }
}
