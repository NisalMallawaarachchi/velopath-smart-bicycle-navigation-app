import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'view_poi_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../modules/routing_engine/screens/map_screen.dart';

/// Main app shell — single bottom nav bar, no drawer.
/// Tabs: Home | Ride | Leaderboard | Profile | Settings
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const <Widget>[
    DashboardContent(),
    MapScreen(),
    POIsScreen(title: "Leaderboard"),
    ProfileScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF4A90D9) : const Color(0xFF0E417A);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        elevation: 8,
        shadowColor: Colors.black26,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: primaryColor),
            label: "Home",
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: primaryColor),
            label: "Ride",
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard, color: primaryColor),
            label: "Leaderboard",
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: primaryColor),
            label: "Profile",
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: primaryColor),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
