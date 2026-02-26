import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/device_helper.dart';
import '../config/api_config.dart';

class POIDetailsScreen extends StatefulWidget {
  final dynamic poi;
  final Function(int)? onLoyaltyUpdated;
  const POIDetailsScreen({super.key, required this.poi, this.onLoyaltyUpdated});

  @override
  State<POIDetailsScreen> createState() => _POIDetailsScreenState();
}

class _POIDetailsScreenState extends State<POIDetailsScreen> {
  late double score;
  late int voteCount;
  late dynamic poiData;
  List<dynamic> comments = [];
  bool loadingComments = true;
  final TextEditingController _commentController = TextEditingController();

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
    fetchPoiDetails();
    fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> fetchPoiDetails() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.poiById(poiData['id']))
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

  Future<void> fetchComments() async {
    try {
      setState(() => loadingComments = true);
      
      final response = await http.get(
        Uri.parse(ApiConfig.getComments(poiData['id']))
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          comments = data['comments'] ?? [];
          loadingComments = false;
        });
      } else {
        setState(() => loadingComments = false);
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
      setState(() => loadingComments = false);
    }
  }

  Future<void> submitComment() async {
    final commentText = _commentController.text.trim();
    
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a comment"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse(ApiConfig.addComment(poiData['id'])),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "comment": commentText,
          "deviceId": deviceId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Comment added successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh comments
        fetchComments();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? "Failed to add comment"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to submit comment. Try again later."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> submitVote(BuildContext context, double percentage) async {
    try {
      final deviceId = await getDeviceId();

      final response = await http.post(
        Uri.parse(ApiConfig.votePoi(poiData['id'])),
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
              await http.get(Uri.parse(ApiConfig.poiById(fetchId)));
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
        if (widget.onLoyaltyUpdated != null) {
          widget.onLoyaltyUpdated!(data['rewardPoints'] ?? 2);
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

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
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
            // POI Image
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),

            // POI Name and Details
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              "$amenity • $district",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 20),

            // Score
            Center(
              child: Text(
                "Score: ${score.toStringAsFixed(1)}% ($voteCount vote${voteCount == 1 ? '' : 's'})",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Vote Button
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

            const SizedBox(height: 30),

            // Comments Section
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Comments",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${comments.length}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add Comment Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Share your thoughts about this place...",
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: submitComment,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text("Post Comment"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 9, 71, 98),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Comments List
            loadingComments
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No comments yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Be the first to share your experience!",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color.fromARGB(255, 9, 71, 98),
                                      child: Text(
                                        (comment['device_id'] ?? 'U')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "User ${comment['device_id']?.toString().substring(0, 8) ?? 'Anonymous'}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(comment['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  comment['comment'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}