// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/routing_engine_provider.dart';

// class RoutingEngineTestScreen extends StatelessWidget {
//   const RoutingEngineTestScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final provider = Provider.of<RoutingEngineProvider>(context);

//     return Scaffold(
//       appBar: AppBar(title: const Text('Routing Engine Test')),
//       body: Center(
//         child: provider.isLoading
//             ? const CircularProgressIndicator()
//             : Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   ElevatedButton(
//                     onPressed: provider.fetchRoutes,
//                     child: const Text("Fetch Generated Routes"),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.pushNamed(context, '/map-screen');
//                     },
//                     child: const Text("Open Map"),
//                   ),
//                   const SizedBox(height: 20),
//                   if (provider.routes.isNotEmpty)
//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: provider.routes.length,
//                         itemBuilder: (context, index) {
//                           final route = provider.routes[index];
//                           return Card(
//                             margin: const EdgeInsets.all(8),
//                             child: ListTile(
//                               title: Text("${route.startPoint} → ${route.endPoint}"),
//                               subtitle: Text(
//                                 "Distance: ${route.distance} km\n"
//                                 "POI Score: ${route.poiScore}, Hazard Score: ${route.hazardScore}",
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     )
//                   else
//                     const Text("No routes available"),
//                 ],
//               ),
//       ),
//     );
//   }
// }
