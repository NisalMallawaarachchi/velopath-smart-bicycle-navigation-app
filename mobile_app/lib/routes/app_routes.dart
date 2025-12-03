import 'package:flutter/material.dart';
import '../modules/routing_engine/screens/map_screen.dart';
import '../modules/routing_engine/screens/routing_engine_test_screen.dart';

class AppRoutes {
  static const String routingEngineTest = '/routing-test';
  static const String mapScreen = '/map-screen';

  static Map<String, WidgetBuilder> routes = {
    routingEngineTest: (context) => const RoutingEngineTestScreen(),
    mapScreen: (context) => const MapScreen(),
  };
}
