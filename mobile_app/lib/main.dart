import 'package:flutter/material.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:mobile_app/screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/main_shell.dart';
import 'screens/poi_screen.dart';
import 'screens/poi_map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'screens/all_pois_map_screen.dart';
import 'package:provider/provider.dart';
import 'modules/routing_engine/providers/routing_engine_provider.dart';
import 'modules/motion_trace/providers/motion_trace_provider.dart';
import 'modules/motion_trace/services/sensor_storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

import 'pages/api_test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SensorStorageService.init();
  runApp(const VeloPathApp());
}

class VeloPathApp extends StatelessWidget {
  const VeloPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoutingEngineProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = MotionTraceProvider();
            provider.initialize();
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'VeloPath Smart Bicycle App',
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/dashboard': (context) => const MainShell(),
              '/pois': (context) => const PoiScreen(),
              '/all-pois-map': (context) => const AllPOIsMapScreen(),
              '/add-poi': (context) => const AddPOIScreen(),
              '/api-test': (context) => ApiTestPage(),
              ...AppRoutes.routes,
            },
          );
        },
      ),
    );
  }
}
