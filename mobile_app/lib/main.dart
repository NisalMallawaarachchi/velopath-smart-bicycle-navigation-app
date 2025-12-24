import 'package:flutter/material.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:mobile_app/screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/poi_screen.dart';
import 'screens/poi_map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'screens/all_pois_map_screen.dart';
import 'package:provider/provider.dart';
import 'modules/routing_engine/providers/routing_engine_provider.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

void main() {
  runApp(const VeloPathApp());
}

class VeloPathApp extends StatelessWidget {
  const VeloPathApp({super.key});

  @override
  Widget build(BuildContext context) {

return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => RoutingEngineProvider()),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VeloPath Smart Bicycle App',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    home: const SplashScreen(),
    routes: {
      '/login': (context) => const LoginScreen(),
      '/signup': (context) => const SignupScreen(),
      '/dashboard': (context) => const DashboardScreen(),
      '/pois': (context) => const PoiScreen(),
      '/all-pois-map': (context) => const AllPOIsMapScreen(),
       '/add-poi': (context) => const AddPOIScreen(),
      ...AppRoutes.routes, // Keep existing app routes if needed
    },
  ),

    );
  }
}
