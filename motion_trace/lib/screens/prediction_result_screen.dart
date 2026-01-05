import 'package:flutter/material.dart';
import 'package:motion_trace/services/api_service.dart';

/// Screen to display hazard prediction results
class PredictionResultScreen extends StatelessWidget {
  final HazardPredictionResult result;

  const PredictionResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Hazard Analysis",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 16),
            
            // Hazard Counts Card
            _buildHazardCountsCard(),
            const SizedBox(height: 16),
            
            // Hazard Locations
            if (result.summary.hazardLocations.isNotEmpty) ...[
              const Text(
                "Detected Hazards",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...result.summary.hazardLocations.map((h) => _buildHazardCard(h)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final hazardsDetected = result.summary.hazardsDetected;
    final totalWindows = result.summary.totalWindows;
    final hazardPercentage = totalWindows > 0 
        ? (hazardsDetected / totalWindows * 100).toStringAsFixed(1)
        : "0";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hazardsDetected > 0
              ? [Colors.orange.shade400, Colors.red.shade400]
              : [Colors.green.shade400, Colors.teal.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: hazardsDetected > 0 
                ? Colors.orange.shade200 
                : Colors.green.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            hazardsDetected > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            hazardsDetected > 0 
                ? "$hazardsDetected Hazards Detected"
                : "Road Looks Safe!",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$totalWindows segments analyzed • $hazardPercentage% hazardous",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardCountsCard() {
    final counts = result.summary.hazardCounts;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Segment Analysis",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCountChip("Smooth", counts['smooth'] ?? 0, Colors.green),
              const SizedBox(width: 8),
              _buildCountChip("Pothole", counts['pothole'] ?? 0, Colors.red),
              const SizedBox(width: 8),
              _buildCountChip("Bump", counts['bump'] ?? 0, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardCard(HazardPrediction hazard) {
    final color = hazard.hazardType == 'pothole' ? Colors.red : Colors.orange;
    final icon = hazard.hazardType == 'pothole' 
        ? Icons.dangerous 
        : Icons.warning_rounded;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hazard.hazardType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Confidence: ${(hazard.confidence * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (hazard.latitude != 0 && hazard.longitude != 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    "📍 ${hazard.latitude.toStringAsFixed(4)}, ${hazard.longitude.toStringAsFixed(4)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
