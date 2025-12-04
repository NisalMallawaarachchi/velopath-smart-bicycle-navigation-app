import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/poi_screen.dart';
import 'screens/poi_map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'screens/all_pois_map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velopath',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
      routes: {
        '/pois': (context) => const PoiScreen(),
         '/all-pois-map': (context) => const AllPOIsMapScreen(),
      },
    );
  }
}
