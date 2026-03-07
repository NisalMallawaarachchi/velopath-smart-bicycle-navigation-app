import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/device_helper.dart';
import '../config/api_config.dart';
import 'notifications_screen.dart';

class POIsScreen extends StatefulWidget {
  final String title;
  const POIsScreen({super.key, this.title = "Dashboard"});

  @override
  State<POIsScreen> createState() => _POIsScreenState();
}

class _POIsScreenState extends State<POIsScreen> {
  int poiCount = 0;
  int loyaltyPoints = 0;
  int userPOIsAdded = 0;
  int userVotes = 0;
  bool loading = true;

  // Notification state
  int _notificationCount = 0;
  String? _lastCheckedAt;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // ── Poll every 30 seconds ─────────────────────────────────────────────────
  void _startNotificationPolling() {
    _checkNewNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNewNotifications(),
    );
  }

  Future<void> _checkNewNotifications() async {
    try {
      final deviceId = await getDeviceId();

      String url = ApiConfig.notifications(deviceId);
      if (_lastCheckedAt != null) {
        url += "?since=${Uri.encodeComponent(_lastCheckedAt!)}";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int newCount = data['count'] ?? 0;

        if (newCount > 0 && _lastCheckedAt != null) {
          // Play the device's built-in click/alert sound — no file needed
          SystemSound.play(SystemSoundType.alert);

          if (mounted) {
            setState(() => _notificationCount += newCount);
          }
        }

        _lastCheckedAt = DateTime.now().toUtc().toIso8601String();
      }
    } catch (e) {
      debugPrint("Notification check error: $e");
    }
  }

  void _openNotifications() async {
    setState(() => _notificationCount = 0);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // ── Dashboard data ─────────────────────────────────────────────────────────
  Future<void> fetchDashboardData() async {
    try {
      final deviceId = await getDeviceId();
      final response =
          await http.get(Uri.parse(ApiConfig.dashboard(deviceId)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          poiCount      = data["poiCount"]      ?? 0;
          loyaltyPoints = data["loyaltyPoints"] ?? 0;
          userPOIsAdded = data["userPOIsAdded"] ?? 0;
          userVotes     = data["userVotes"]     ?? 0;
          loading       = false;
        });
      } else {
        throw Exception("Failed to load dashboard data");
      }
    } catch (e) {
      debugPrint("Dashboard fetch error: $e");
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading dashboard: $e"),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  String _getLevelTitle(int points) {
    if (points >= 1000) return "🏆 Legend";
    if (points >= 500)  return "💎 Diamond Explorer";
    if (points >= 250)  return "🌟 Gold Adventurer";
    if (points >= 100)  return "🎯 Silver Rider";
    if (points >= 50)   return "🚀 Bronze Pathfinder";
    return "🌱 Beginner";
  }

  int _getNextLevelThreshold(int points) {
    if (points >= 1000) return 1500;
    if (points >= 500)  return 1000;
    if (points >= 250)  return 500;
    if (points >= 100)  return 250;
    if (points >= 50)   return 100;
    return 50;
  }

  int _getCurrentLevelThreshold(int points) {
    if (points >= 1000) return 1000;
    if (points >= 500)  return 500;
    if (points >= 250)  return 250;
    if (points >= 100)  return 100;
    if (points >= 50)   return 50;
    return 0;
  }

  double _getLevelProgress(int points) {
    final currentThreshold = _getCurrentLevelThreshold(points);
    final nextThreshold    = _getNextLevelThreshold(points);
    if (nextThreshold == currentThreshold) return 0.0;
    return ((points - currentThreshold) /
            (nextThreshold - currentThreshold))
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(184, 5, 75, 83),
        elevation: 0,
        centerTitle: true,
        actions: [
          // ── Bell icon with red badge ──────────────────────────────
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _openNotifications,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                        minWidth: 18, minHeight: 18),
                    child: Text(
                      _notificationCount > 99
                          ? "99+"
                          : "$_notificationCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => loading = true);
              fetchDashboardData();
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Loyalty Level Card ────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(184, 5, 75, 83),
                            Color.fromARGB(255, 6, 94, 119),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(184, 5, 75, 83)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getLevelTitle(loyaltyPoints),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Loyalty Level",
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars,
                                        color: Color(0xFFFFD700),
                                        size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$loyaltyPoints",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _getLevelProgress(loyaltyPoints),
                              minHeight: 8,
                              backgroundColor:
                                  Colors.white.withOpacity(0.3),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFD700)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_getNextLevelThreshold(loyaltyPoints) - loyaltyPoints} points to ${_getNextLevelThreshold(loyaltyPoints) >= 1500 ? 'max level' : 'next level'}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Contributions ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Contributions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(184, 5, 75, 83)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "From This Device",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(184, 5, 75, 83),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Total POIs in System",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$poiCount",
                                    style: const TextStyle(
                                      color:
                                          Color.fromARGB(184, 5, 75, 83),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                          184, 5, 75, 83)
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color.fromARGB(184, 5, 75, 83),
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionLink(
                                icon: Icons.add_circle_outline,
                                label: "Add New",
                                onPressed: () async {
                                  final result =
                                      await Navigator.pushNamed(
                                          context, '/add-poi');
                                  if (result == true)
                                    fetchDashboardData();
                                },
                              ),
                              Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.grey.shade300),
                              _buildActionLink(
                                icon: Icons.how_to_vote,
                                label: "Vote",
                                onPressed: () => Navigator.pushNamed(
                                    context, '/pois'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20,
                                  color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                "How to Earn Points",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildPointsRule(
                              icon: Icons.add_location,
                              text: "Add a new POI",
                              points: "+5 points"),
                          const SizedBox(height: 8),
                          _buildPointsRule(
                              icon: Icons.thumb_up,
                              text: "Vote on a POI",
                              points: "+2 points"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Explore The Places!",
                      style: TextStyle(
                        color: Color(0xFF2C3E50),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Image.asset(
                        "assets/bicycle.gif",
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildActionButton(
                      icon: Icons.list_alt,
                      label: "View List of Places",
                      onPressed: () =>
                          Navigator.pushNamed(context, '/pois'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.map,
                      label: "View All POIs on Map",
                      onPressed: () =>
                          Navigator.pushNamed(context, '/all-pois-map'),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPointsRule({
    required IconData icon,
    required String text,
    required String points,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ),
        Text(points,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50))),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        backgroundColor: const Color.fromARGB(184, 5, 75, 83),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionLink({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
          foregroundColor: const Color.fromARGB(184, 5, 75, 83)),
    );
  }
}