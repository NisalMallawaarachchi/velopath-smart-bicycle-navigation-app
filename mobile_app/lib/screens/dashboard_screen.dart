import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/device_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;



class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  int loyaltyPoints = 0;
  int poiCount = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard(); 
  }

  Future<void> loadDashboard() async {
    final deviceId = await getDeviceId();

    final res = await http.get(
      Uri.parse("http://10.75.197.45:5001/api/dashboard/$deviceId"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        loyaltyPoints = data["loyaltyPoints"];
        poiCount = data["poiCount"];
      });
    }
  }

  String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String getFormattedTime() {
    final now = DateTime.now();
    int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    String period = now.hour < 12 ? "A.M" : "P.M";
    String minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),

      appBar: AppBar(
        title: const Text("Velopath", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(184, 5, 75, 83),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---------------- SEARCH BAR ----------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search VeloPath",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Icon(Icons.search, color: Colors.grey.shade600),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---------------- WELCOME CARD ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color.fromARGB(184, 5, 75, 83),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Text("Welcome",
                          style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("👋", style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text("Let's Get You Started With VeloPath",
                      style: TextStyle(fontSize: 14, color: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ----------- GREETING + TIME ------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(getGreeting(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(getFormattedTime(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ----------------- LOYALTY CARD -----------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color.fromARGB(255, 152, 210, 224)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Loyalty",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("$loyaltyPoints points",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  LinearProgressIndicator(
                    value: (loyaltyPoints / 1000).clamp(0.0, 1.0),
                    color: const Color.fromARGB(255, 6, 94, 119),
                    backgroundColor: Colors.blue.shade100,
                    minHeight: 6,
                  ),

                  const SizedBox(height: 8),
                  const Text("Click for details"),
                ],
              ),
            ),

            const SizedBox(height: 20),


            // ----------------- DASHBOARD BUTTONS -----------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.routingEngineTest),
                    icon: const Icon(Icons.route),
                    label: const Text("Start Riding"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF184652),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNav(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 2) {
            Navigator.pushNamed(context, AppRoutes.routingEngineTest);
          }
        },
      ),
    );
  }


}
