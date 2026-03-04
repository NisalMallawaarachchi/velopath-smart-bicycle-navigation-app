import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Simple API test page - Uses hardcoded coordinates from your database
class ApiTestPage extends StatefulWidget {
  @override
  _ApiTestPageState createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  static const String baseUrl = 'http://192.168.8.191:5001'; // CHANGE THIS TO YOUR IP!
  
  // Test coordinates from your database
  double testLat = 7.2088;
  double testLon = 79.8358;
  String userId = 'demo_user_001';
  
  String _response = '';
  bool _isLoading = false;
  
  // Test 1: Get System Stats
  Future<void> testStats() async {
    setState(() {
      _isLoading = true;
      _response = 'Loading...';
    });
    
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/stats'));
      setState(() {
        _response = 'Status: ${res.statusCode}\n\n${_formatJson(res.body)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  // Test 2: Get Hazards in Area
  Future<void> testGetHazards() async {
    setState(() {
      _isLoading = true;
      _response = 'Loading...';
    });
    
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/hazards?minLat=7.20&maxLat=7.22&minLon=79.83&maxLon=79.84&minConfidence=0.1')
      );
      setState(() {
        _response = 'Status: ${res.statusCode}\n\n${_formatJson(res.body)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  // Test 3: Get Approaching Hazards
  Future<void> testApproaching() async {
    setState(() {
      _isLoading = true;
      _response = 'Loading...';
    });
    
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/notifications/approaching?lat=$testLat&lon=$testLon&userId=$userId')
      );
      setState(() {
        _response = 'Status: ${res.statusCode}\n\n${_formatJson(res.body)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e\n\nMake sure server is running and IP is correct!';
        _isLoading = false;
      });
    }
  }
  
  // Test 4: Get Passed Hazards
  Future<void> testPassed() async {
    setState(() {
      _isLoading = true;
      _response = 'Loading...';
    });
    
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/notifications/passed?lat=$testLat&lon=$testLon&userId=$userId')
      );
      setState(() {
        _response = 'Status: ${res.statusCode}\n\n${_formatJson(res.body)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  // Test 5: Confirm Hazard (you'll need to get hazard ID from test 3 or 4)
  Future<void> testConfirm(String hazardId) async {
    setState(() {
      _isLoading = true;
      _response = 'Sending confirmation...';
    });
    
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/notifications/$hazardId/respond'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'response': 'yes',
        }),
      );
      setState(() {
        _response = 'Status: ${res.statusCode}\n\n${_formatJson(res.body)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  String _formatJson(String jsonStr) {
    try {
      final jsonObj = json.decode(jsonStr);
      return JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (e) {
      return jsonStr;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Test Page'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Configuration Section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Base URL: $baseUrl', style: TextStyle(fontSize: 12)),
                Text('Test Location: $testLat, $testLon', style: TextStyle(fontSize: 12)),
                Text('User ID: $userId', style: TextStyle(fontSize: 12)),
                SizedBox(height: 8),
                Text(
                  '⚠️ Update baseUrl with your computer\'s IP!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Test Buttons
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'API Tests',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  ElevatedButton(
                    onPressed: testStats,
                    child: Text('1. Get System Stats'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  ElevatedButton(
                    onPressed: testGetHazards,
                    child: Text('2. Get Hazards in Area'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  ElevatedButton(
                    onPressed: testApproaching,
                    child: Text('3. Get Approaching Hazards'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  ElevatedButton(
                    onPressed: testPassed,
                    child: Text('4. Get Passed Hazards'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  ElevatedButton(
                    onPressed: () {
                      // Show dialog to enter hazard ID
                      _showConfirmDialog();
                    },
                    child: Text('5. Confirm a Hazard (YES)'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),
                  
                  // Response Display
                  Text(
                    'Response:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: BoxConstraints(minHeight: 200),
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.white))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SelectableText(
                              _response.isEmpty ? 'Tap a button to test API...' : _response,
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'Courier',
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showConfirmDialog() {
    String hazardId = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Hazard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter Hazard ID from previous response:'),
            SizedBox(height: 12),
            TextField(
              onChanged: (value) => hazardId = value,
              decoration: InputDecoration(
                hintText: 'e.g., 2b565910-5ef7-464d...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (hazardId.isNotEmpty) {
                testConfirm(hazardId);
              }
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }
}