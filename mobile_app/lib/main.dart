import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modules/routing_engine/providers/routing_engine_provider.dart';
import 'routes/app_routes.dart';

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
        theme: ThemeData(primarySwatch: Colors.teal),
        initialRoute: AppRoutes.routingEngineTest,
        routes: AppRoutes.routes,
      ),
    );
  }
}
