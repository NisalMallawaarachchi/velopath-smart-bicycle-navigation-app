import 'package:flutter/material.dart';
import 'package:mobile_app/modules/routing_engine/screens/map_screen.dart';

class AppRoutes {
  static const String routingEngineTest = '/routing-test';
  static const String mapScreen = '/map-screen';

  static Map<String, WidgetBuilder> routes = {
    routingEngineTest: (_) => MapScreen(),
    mapScreen: (_) => MapScreen(),
  };
}
