import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import '../widgets/device_helper.dart';
import '../modules/motion_trace/providers/motion_trace_provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';
import '../providers/theme_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kept for backward compatibility (routes etc.)
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: DashboardContent());
  }
}

/// Dashboard content — used inside MainShell tab.
class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  int loyaltyPoints = 0;
  int poiCount = 0;

  Timer? _dashboardTimer;

  @override
  void initState() {
    super.initState();
    loadDashboard();

    _dashboardTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => loadDashboard(),
    );

  }

  @override
  void dispose() {
    _dashboardTimer?.cancel();
    super.dispose();
  }

  Future<void> incrementLoyalty(int points) async {
  setState(() {
    loyaltyPoints += points;
  });
}
  Future<void> loadDashboard() async {
    final deviceId = await getDeviceId();

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.dashboard(deviceId)),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            loyaltyPoints = data["loyaltyPoints"] ?? 0;
            poiCount = data["poiCount"] ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final username = auth.user?.username ?? "Rider";
    final reputation = auth.user?.reputationScore ?? 5.0;
    final contributions = auth.user?.totalContributions ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ─── Glassmorphism App Bar ───
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: ThemeProvider.primaryDarkBlue.withValues(alpha: 0.9),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ThemeProvider.primaryDarkBlue,
                          ThemeProvider.primaryDarkBlue.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: ThemeProvider.accentCyan.withValues(alpha: 0.2),
                                  child: Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      color: ThemeProvider.accentCyan,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${_getGreeting()} 👋",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Search bar
                            GestureDetector(
                              onTap: () => showSearch(
                                context: context,
                                delegate: _PlaceSearchDelegate(),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                    )
                                  ]
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search,
                                        color: Colors.white.withValues(alpha: 0.7)),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Search places, POIs...",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Body ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Stats Grid ───
                  Row(
                    children: [
                      _StatTile(
                        icon: Icons.star,
                        label: "Reputation",
                        value: reputation.toStringAsFixed(1),
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        icon: Icons.emoji_events,
                        label: "Loyalty",
                        value: "$loyaltyPoints pts",
                        color: Colors.amber.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatTile(
                        icon: Icons.handshake,
                        label: "Contributions",
                        value: "$contributions",
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        icon: Icons.place,
                        label: "POIs",
                        value: "$poiCount",
                        color: ThemeProvider.primaryDarkBlue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ─── Quick Actions ───
                  Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : ThemeProvider.primaryDarkBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Riding — Hero button
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeProvider.primaryDarkBlue.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                          context, AppRoutes.routingEngineTest),
                      icon: const Icon(Icons.route, size: 26, color: ThemeProvider.accentCyan),
                      label: const Text("Start Riding",
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.primaryDarkBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary actions row
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.explore,
                          label: "Explore POIs",
                          color: Colors.deepPurple,
                          onTap: () =>
                              Navigator.pushNamed(context, '/pois'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.map,
                          label: "View Map",
                          color: Colors.teal,
                          onTap: () => Navigator.pushNamed(
                              context, '/all-pois-map'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────
// Stat Tile
// ──────────────────────────────────────
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────
// Action Card
// ──────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────
// Full-screen Place Search Delegate
// ──────────────────────────────────────
class _PlaceSearchDelegate extends SearchDelegate<String> {
  _PlaceSearchDelegate() : super(searchFieldLabel: "Search places, POIs...");

  List<Map<String, dynamic>> _cachedPois = [];
  bool _loaded = false;

  Future<List<Map<String, dynamic>>> _fetchPois() async {
    if (_loaded) return _cachedPois;
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.pois),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _cachedPois = list.cast<Map<String, dynamic>>();
        _loaded = true;
      }
    } catch (_) {}
    return _cachedPois;
  }

  IconData _iconForAmenity(String? amenity) {
    switch (amenity?.toLowerCase()) {
      case 'cafe':
      case 'restaurant':
        return Icons.restaurant;
      case 'fuel':
      case 'fuel_station':
        return Icons.local_gas_station;
      case 'hospital':
      case 'clinic':
        return Icons.local_hospital;
      case 'park':
        return Icons.park;
      case 'shop':
      case 'supermarket':
        return Icons.store;
      case 'bike_shop':
      case 'bicycle':
        return Icons.pedal_bike;
      case 'parking':
        return Icons.local_parking;
      case 'water':
      case 'drinking_water':
        return Icons.water_drop;
      case 'viewpoint':
        return Icons.landscape;
      default:
        return Icons.place;
    }
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E417A),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildQuickActions(context);
    }
    return _buildResults(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResults(context);
  }

  Widget _buildQuickActions(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0E417A),
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          icon: Icons.route,
          title: "Start Riding",
          subtitle: "Open map and plan a route",
          onTap: () {
            close(context, '');
            Navigator.pushNamed(context, AppRoutes.routingEngineTest);
          },
        ),
        _QuickActionTile(
          icon: Icons.explore,
          title: "Explore POIs",
          subtitle: "Discover places near you",
          onTap: () {
            close(context, '');
            Navigator.pushNamed(context, '/pois');
          },
        ),
        _QuickActionTile(
          icon: Icons.map,
          title: "View All POIs on Map",
          subtitle: "See all points of interest",
          onTap: () {
            close(context, '');
            Navigator.pushNamed(context, '/all-pois-map');
          },
        ),
        const SizedBox(height: 24),
        Text(
          "Type to search POIs by name...",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPois(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_loaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPois = snapshot.data ?? [];
        final q = query.toLowerCase();
        final filtered = allPois.where((poi) {
          final name = (poi['name'] ?? '').toString().toLowerCase();
          final amenity = (poi['amenity'] ?? '').toString().toLowerCase();
          final district = (poi['district'] ?? '').toString().toLowerCase();
          return name.contains(q) ||
              amenity.contains(q) ||
              district.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No places found for "$query"',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, i) {
            final poi = filtered[i];
            final name = poi['name'] ?? 'Unknown';
            final amenity = poi['amenity'] ?? '';
            final district = poi['district'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF0E417A).withValues(alpha: 0.1),
                child: Icon(
                  _iconForAmenity(amenity),
                  color: const Color(0xFF0E417A),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                [amenity, district].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              trailing:
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () {
                close(context, name);
                Navigator.pushNamed(context, AppRoutes.routingEngineTest);
              },
            );
          },
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0E417A).withValues(alpha: 0.1),
          child: Icon(icon, color: const Color(0xFF0E417A)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}