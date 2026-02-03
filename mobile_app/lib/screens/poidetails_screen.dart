import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/device_helper.dart';

class POIDetailsScreen extends StatefulWidget {
  final dynamic poi;
  const POIDetailsScreen({super.key, required this.poi});

  @override
  State<POIDetailsScreen> createState() => _POIDetailsScreenState();
}

class _POIDetailsScreenState extends State<POIDetailsScreen> {
  late double score;
  late int voteCount;
  late dynamic poiData;

  // Helper: safely parse score
  double parseScore(dynamic s) {
    if (s == null) return 0.0;
    if (s is double) return s;
    if (s is int) return s.toDouble();
    if (s is String) return double.tryParse(s) ?? 0.0;
    return 0.0;
  }

  // Helper: safely parse vote count
  int parseVoteCount(dynamic c) {
    if (c == null) return 0;
    if (c is int) return c;
    if (c is double) return c.toInt();
    if (c is String) return int.tryParse(c) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    poiData = widget.poi;
    score = parseScore(poiData['score']);
    voteCount = parseVoteCount(poiData['vote_count']);
    fetchPoiDetails(); // Fetch fresh data on screen load
  }

  Future<void> fetchPoiDetails() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.75.197.44:5001/api/pois/${poiData['id']}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          poiData = data;
          score = parseScore(data['score']);
          voteCount = parseVoteCount(data['vote_count']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching POI details: $e");
    }
  }

  Future<void> submitVote(BuildContext context, double percentage) async {
    try {
      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse("http://10.75.197.44:5001/api/pois/${poiData['id']}/vote"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "percentage": percentage,
          "deviceId": deviceId,
          "source": poiData['source'],
          "poi": {
            "name": poiData['name'],
            "amenity": poiData['amenity'],
            "lat": poiData['lat'],
            "lon": poiData['lon'],
            "district": poiData['district'],
          },
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 409) {
        final fetchId = data['customPoiId'] ?? poiData['id'];

        // Update UI directly from vote response if available
        if (data.containsKey('score') && data.containsKey('voteCount')) {
          setState(() {
            score = parseScore(data['score']);
            voteCount = parseVoteCount(data['voteCount']);
            poiData['id'] = fetchId;
            poiData['source'] = 'custom';
          });
        } else {
          // Fallback: fetch fresh data from backend
          final detailsResponse =
              await http.get(Uri.parse("http://10.75.197.44:5001/api/pois/$fetchId"));
          if (detailsResponse.statusCode == 200) {
            final details = jsonDecode(detailsResponse.body);
            setState(() {
              poiData = details;
              score = parseScore(details['score']);
              voteCount = parseVoteCount(details['vote_count']);
              poiData['source'] = 'custom';
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.statusCode == 200
                ? "Thanks for voting! New score: ${score.toStringAsFixed(1)}%"
                : "You have already voted! Score: ${score.toStringAsFixed(1)}%"),
            backgroundColor:
                response.statusCode == 200 ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? "Something went wrong"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to submit vote. Try again later."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void openVotePopup(BuildContext context) {
    double selectedValue = 50;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Rate This Place",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: selectedValue,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: "${selectedValue.toInt()}%",
                    onChanged: (value) =>
                        setStateModal(() => selectedValue = value),
                  ),
                  Text(
                    "${selectedValue.toInt()}%",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 35, 126, 196),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 40,
                      ),
                    ),
                    onPressed: () async {
                      await submitVote(context, selectedValue);
                      // Return updated POI when closing
                      Navigator.pop(context, poiData);
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
    final name = poiData['name'] ?? "POI";
    final amenity = poiData['amenity'] ?? "";
    final district = poiData['district'] ?? "Unknown";
    final desc = poiData['description'] ?? "No description available";
    final imageUrl = poiData['image_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color.fromARGB(255, 19, 85, 151),
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
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              "$amenity • $district",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 20),

            // LIVE score update
            Center(
              child: Text(
                "Score: ${score.toStringAsFixed(1)}% ($voteCount vote${voteCount == 1 ? '' : 's'})",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 9, 71, 98),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 40,
                  ),
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
