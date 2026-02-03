import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/device_helper.dart';


class POIsScreen extends StatefulWidget {
  final String title;
  const POIsScreen({super.key, this.title = "Leaderboard"});

  @override
  State<POIsScreen> createState() => _POIsScreenState();
}

class _POIsScreenState extends State<POIsScreen> {
  int poiCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchPOICount();
  }

  Future<void> fetchPOICount() async {
    try {
      final deviceId = await getDeviceId();

      final response = await http.get(
        Uri.parse("http://10.75.197.44:5001/api/dashboard/$deviceId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          poiCount = data["poiCount"];
          loading = false;
        });
      } else {
        throw Exception("Failed to load POI count");
      }
    } catch (e) {
      print("POI count fetch error: $e");
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching POI count: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 20, 147, 169),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ---------------- HEADER----------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Explore The Places!",
                          style: TextStyle(
                            color: Color.fromARGB(255, 66, 65, 65),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Image.asset(
                            "assets/bicycle.gif",
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------------- BUTTONS ----------------
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/pois');
                          },
                          icon: const Icon(Icons.list_alt),
                          label: const Text("View List of Places"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: const Color(0xFF184652),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/all-pois-map');
                          },
                          icon: const Icon(Icons.map),
                          label: const Text("View All POIs on Map"),
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

                  const SizedBox(height: 20),

                  // ---------------- POI COUNT CARD ----------------
                 
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color.fromARGB(255, 5, 118, 126), Color.fromARGB(255, 107, 183, 204)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "POI Count",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$poiCount",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final result =
                                    await Navigator.pushNamed(context, '/add-poi');
                                if (result == true) fetchPOICount();
                              },
                              child: const Text(
                                "Add New",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                "Votes",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
