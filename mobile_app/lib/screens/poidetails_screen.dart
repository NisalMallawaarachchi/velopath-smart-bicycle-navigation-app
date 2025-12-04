import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class POIDetailsScreen extends StatelessWidget {
  final dynamic poi;

  const POIDetailsScreen({super.key, required this.poi});

  Future<void> submitVote(double percentage) async {
    try {
      await http.post(
        Uri.parse("http://10.75.197.44:5001/api/pois/${poi['id']}/vote"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"percentage": percentage}),
      );
    } catch (e) {
      print("Voting error: $e");
    }
  }

  void openVotePopup(BuildContext context) {
    double selectedValue = 50; // default

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Rate This Place",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// SLIDER
                  Slider(
                    value: selectedValue,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: "${selectedValue.toInt()}%",
                    onChanged: (value) {
                      setState(() => selectedValue = value);
                    },
                  ),

                  Text(
                    "${selectedValue.toInt()}%",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  /// SUBMIT BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 40),
                    ),
                    onPressed: () async {
                      await submitVote(selectedValue);

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Your vote has been submitted")),
                      );
                    },
                    child: const Text(
                      "Submit Vote",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = poi['name'] ?? "POI";
    final amenity = poi['amenity'] ?? "";
    final district = poi['district'] ?? "Unknown";
    final desc = poi['description'] ?? "No description available";
    final imageUrl = poi['image_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  "http://10.75.197.44:5001$imageUrl",
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 16),

            Text(name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text("$amenity • $district",
                style: const TextStyle(fontSize: 16, color: Colors.grey)),

            const SizedBox(height: 12),

            const Text("Description",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 15)),

            const SizedBox(height: 30),

            /// ▶ ONLY ONE VOTE BUTTON
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                ),
                onPressed: () => openVotePopup(context),
                child: const Text(
                  "Vote",
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
