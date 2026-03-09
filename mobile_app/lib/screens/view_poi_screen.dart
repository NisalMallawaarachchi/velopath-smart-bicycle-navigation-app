import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/device_helper.dart';
import '../config/api_config.dart';
import '../providers/theme_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : ThemeProvider.primaryDarkBlue;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: ThemeProvider.primaryDarkBlue,
        elevation: 0, // ensure no double shadow
        centerTitle: true,
        actions: [
          
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
          ? const Center(child: CircularProgressIndicator(color: ThemeProvider.accentCyan))
          : RefreshIndicator(
              color: ThemeProvider.accentCyan,
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Loyalty Level Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [ThemeProvider.primaryDarkBlue, Color(0xFF103A60)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeProvider.primaryDarkBlue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getLevelTitle(loyaltyPoints),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Loyalty Level",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$loyaltyPoints",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _getLevelProgress(loyaltyPoints),
                              minHeight: 10,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(ThemeProvider.accentCyan),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${_getNextLevelThreshold(loyaltyPoints) - loyaltyPoints} points to ${_getNextLevelThreshold(loyaltyPoints) >= 1500 ? 'max level' : 'next level'}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Contributions ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Contributions",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThemeProvider.accentCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "From This Device",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ThemeProvider.accentCyan,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: ThemeProvider.primaryDarkBlue.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Total POIs in System",
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$poiCount",
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: ThemeProvider.primaryDarkBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: ThemeProvider.primaryDarkBlue,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionLink(
                                icon: Icons.add_circle_outline,
                                label: "Add New",
                                isDark: isDark,
                                onPressed: () async {
                                  final result = await Navigator.pushNamed(context, '/add-poi');
                                  if (result == true) fetchDashboardData();
                                },
                              ),
                              Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                              _buildActionLink(
                                icon: Icons.how_to_vote_outlined,
                                label: "Vote",
                                isDark: isDark,
                                onPressed: () => Navigator.pushNamed(context, '/pois'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: ThemeProvider.primaryDarkBlue.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 22, color: ThemeProvider.accentCyan),
                              const SizedBox(width: 10),
                              Text(
                                "How to Earn Points",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPointsRule(
                              icon: Icons.add_location_alt,
                              text: "Add a new Point of Interest",
                              points: "+5 points",
                              subtitleColor: subtitleColor),
                          const SizedBox(height: 12),
                          _buildPointsRule(
                              icon: Icons.thumb_up_alt_outlined,
                              text: "Vote on an existing POI",
                              points: "+2 points",
                              subtitleColor: subtitleColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      "Explore The Places!",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ThemeProvider.accentCyan.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          "assets/bicycle.gif",
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildActionButton(
                      icon: Icons.list_alt_rounded,
                      label: "View List of Places",
                      onPressed: () => Navigator.pushNamed(context, '/pois'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.map_outlined,
                      label: "View All POIs on Map",
                      onPressed: () => Navigator.pushNamed(context, '/all-pois-map'),
                    ),

                    const SizedBox(height: 30),
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
    required Color subtitleColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThemeProvider.primaryDarkBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: ThemeProvider.primaryDarkBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(points, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: ThemeProvider.primaryDarkBlue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeProvider.primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildActionLink({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      style: TextButton.styleFrom(
        foregroundColor: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
