import 'package:flutter/material.dart';

import 'package:mobile_app/modules/routing_engine/screens/map_screen.dart';

import 'package:mobile_app/screens/auth/login_screen.dart';
import 'package:mobile_app/screens/dashboard_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 52, 134, 146),
            ),
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                height: 150,
                width: 150,
              ),
            ),
          ),

          // HOME → Dashboard
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Home"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),

          // PROFILE → null (no screen yet)
          const ListTile(
            leading: Icon(Icons.person),
            title: Text("Profile"),
            onTap: null, // no screen yet
          ),

          // MAP → Routing Engine Test
          ListTile(

  leading: const Icon(Icons.location_on),
  title: const Text("Map"),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(), 
      ),
    );
  },
),



          // SETTINGS → null
          const ListTile(
            leading: Icon(Icons.settings),
            title: Text("Settings"),
            onTap: null,
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Log out"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
