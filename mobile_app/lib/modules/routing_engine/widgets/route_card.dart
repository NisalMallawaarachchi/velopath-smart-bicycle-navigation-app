import 'package:flutter/material.dart';
import '../../../data/models/route_model.dart';

class RouteCard extends StatelessWidget {
  final RouteModel route;

  const RouteCard({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: ListTile(
        title: Text('${route.startPoint} ➜ ${route.endPoint}'),
        subtitle: Text(
          'Distance: ${route.distance.toStringAsFixed(2)} km\n'
          'POI Score: ${route.poiScore}, Hazard Score: ${route.hazardScore}',
        ),
      ),
    );
  }
}
