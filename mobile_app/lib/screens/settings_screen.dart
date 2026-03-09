import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue)),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ─── Appearance ───
          _SectionLabel("Appearance"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              Consumer<ThemeProvider>(
                builder: (ctx, themeProvider, _) => _ToggleTile(
                  icon: isDark ? Icons.dark_mode : Icons.light_mode,
                  iconColor: isDark ? Colors.amber : Colors.orange,
                  title: "Dark Mode",
                  subtitle: isDark ? "Dark theme active" : "Light theme active",
                  subtitleColor: subtitleColor,
                  value: themeProvider.isDark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Ride Preferences ───
          _SectionLabel("Ride Preferences"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              _TapTile(
                icon: Icons.route,
                iconColor: const Color(0xFF0E417A),
                title: "Default Route Profile",
                subtitle: "Balanced",
                subtitleColor: subtitleColor,
                onTap: () => _showRouteProfilePicker(context),
              ),
              _divider(isDark),
              _TapTile(
                icon: Icons.speed,
                iconColor: Colors.teal,
                title: "Speed Units",
                subtitle: "km/h",
                subtitleColor: subtitleColor,
                onTap: () => _showUnitsPicker(context),
              ),
              _divider(isDark),
              _ToggleTile(
                icon: Icons.volume_up,
                iconColor: Colors.blue,
                title: "Voice Navigation",
                subtitle: "Turn-by-turn voice guidance",
                subtitleColor: subtitleColor,
                value: true,
                onChanged: (v) {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Sensor & Data ───
          _SectionLabel("Sensor & Data"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              _ToggleTile(
                icon: Icons.sensors,
                iconColor: Colors.green,
                title: "Background Tracking",
                subtitle: "Collect sensor data while riding",
                subtitleColor: subtitleColor,
                value: true,
                onChanged: (v) {},
              ),
              _divider(isDark),
              _ToggleTile(
                icon: Icons.cloud_upload,
                iconColor: Colors.cyan,
                title: "Auto Upload",
                subtitle: "Upload data every 5 minutes",
                subtitleColor: subtitleColor,
                value: true,
                onChanged: (v) {},
              ),
              _divider(isDark),
              _TapTile(
                icon: Icons.timer,
                iconColor: Colors.purple,
                title: "Sampling Rate",
                subtitle: "200ms (recommended)",
                subtitleColor: subtitleColor,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Hazard & Safety ───
          _SectionLabel("Hazard & Safety"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              _ToggleTile(
                icon: Icons.warning_amber,
                iconColor: Colors.orange,
                title: "Hazard Alerts",
                subtitle: "Alert when approaching hazards",
                subtitleColor: subtitleColor,
                value: true,
                onChanged: (v) {},
              ),
              _divider(isDark),
              _TapTile(
                icon: Icons.social_distance,
                iconColor: Colors.redAccent,
                title: "Alert Distance",
                subtitle: "50 meters",
                subtitleColor: subtitleColor,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Notifications ───
          _SectionLabel("Notifications"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              _ToggleTile(
                icon: Icons.notifications_active,
                iconColor: Colors.pink,
                title: "Push Notifications",
                subtitle: "Receive ride and hazard alerts",
                subtitleColor: subtitleColor,
                value: true,
                onChanged: (v) {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── About ───
          _SectionLabel("About"),
          _SettingsCard(
            cardColor: cardColor,
            children: [
              _TapTile(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: "App Version",
                subtitle: "1.0.0",
                subtitleColor: subtitleColor,
                onTap: null,
              ),
              _divider(isDark),
              _TapTile(
                icon: Icons.description_outlined,
                iconColor: Colors.blueGrey,
                title: "Terms & Conditions",
                subtitleColor: subtitleColor,
                onTap: () {},
              ),
              _divider(isDark),
              _TapTile(
                icon: Icons.shield_outlined,
                iconColor: Colors.indigo,
                title: "Privacy Policy",
                subtitleColor: subtitleColor,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Logout ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              label: const Text(
                "Logout",
                style: TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showRouteProfilePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Default Route Profile",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          _profileOption(ctx, Icons.bolt, "Shortest", "Fastest path"),
          _profileOption(
              ctx, Icons.balance, "Balanced", "Balance speed & safety"),
          _profileOption(
              ctx, Icons.shield, "Safest", "Avoid hazardous roads"),
          _profileOption(ctx, Icons.park, "Scenic", "Prefer scenic routes"),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _profileOption(
      BuildContext ctx, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: ThemeProvider.primaryDarkBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: ThemeProvider.primaryDarkBlue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () => Navigator.pop(ctx),
    );
  }

  void _showUnitsPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Speed Units",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text("km/h"),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text("mph"),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────
// Section Label
// ──────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.7),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────
// Grouped card container
// ──────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color cardColor;
  const _SettingsCard({required this.children, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ──────────────────────────────────────
// Toggle tile (switch)
// ──────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.subtitleColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 13, color: subtitleColor))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: ThemeProvider.accentCyan,
      ),
    );
  }
}

// ──────────────────────────────────────
// Tap tile (with arrow)
// ──────────────────────────────────────
class _TapTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final VoidCallback? onTap;

  const _TapTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.subtitleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 13, color: subtitleColor))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: subtitleColor)
          : null,
      onTap: onTap,
    );
  }
}
