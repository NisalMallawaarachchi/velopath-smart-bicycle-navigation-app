import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motion_trace/services/storage_service.dart';
import 'package:motion_trace/services/api_service.dart';
import 'package:motion_trace/utils/csv_exporter.dart';
import 'package:motion_trace/screens/prediction_result_screen.dart';
import 'graph_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<String> sessions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  Future<void> loadSessions() async {
    setState(() => isLoading = true);
    final list = StorageService.getAllSessionKeys();
    setState(() {
      sessions = list.reversed.toList(); // Most recent first
      isLoading = false;
    });
  }

  String _formatSessionDate(String key) {
    try {
      final date = DateTime.parse(key);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[date.month - 1]} ${date.day}, ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return key.substring(0, 19).replaceAll('T', ' ');
    }
  }

  Future<void> _openGraph(String key) async {
    HapticFeedback.lightImpact();
    final readings = StorageService.getSessionData(key);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GraphScreen(readings: readings)));
    }
  }

  Future<void> _exportCSV(String key) async {
    HapticFeedback.lightImpact();
    final readings = StorageService.getSessionData(key);
    final filePath = await CSVExporter.exportToCSV(readings, key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text("CSV exported to Downloads/MotionTrace")),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _uploadSession(String key) async {
    HapticFeedback.lightImpact();
    
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Upload Session",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose what to do with this data",
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            _buildUploadOption(
              icon: Icons.analytics_rounded,
              title: "Run Prediction",
              subtitle: "Analyze hazards with ML model",
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.pop(context, 'predict'),
            ),
            const SizedBox(height: 12),
            _buildUploadOption(
              icon: Icons.school_rounded,
              title: "Add to Training",
              subtitle: "Use labels to improve the model",
              color: const Color(0xFF10B981),
              onTap: () => Navigator.pop(context, 'train'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (mode == null) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFF3B82F6)),
              const SizedBox(width: 20),
              Text(
                mode == 'predict' ? "Analyzing..." : "Uploading...",
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final readings = StorageService.getSessionData(key);
      final result = await ApiService.uploadSession(readings, mode);

      if (mounted) Navigator.pop(context);

      if (result.success) {
        if (mode == 'predict' && result.predictionResult != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PredictionResultScreen(result: result.predictionResult!)),
          );
        } else if (mounted) {
          _showSuccessDialog(result);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${result.error}"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(UploadResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              "Upload Successful",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              result.message ?? "Data added to training set",
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (result.stats != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatRow("Readings added", "${result.stats!.addedReadings}"),
                    _buildStatRow("Total training data", "${result.stats!.totalReadings}"),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String key) async {
    HapticFeedback.lightImpact();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Session?", style: TextStyle(color: Colors.white)),
        content: Text(
          "This action cannot be undone.",
          style: TextStyle(color: Colors.grey.shade500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteSession(key);
      await loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sessions"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : sessions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: loadSessions,
                  color: const Color(0xFF3B82F6),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) => _buildSessionCard(sessions[index], index),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Sessions Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Start recording to capture road data",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(String key, int index) {
    final readings = StorageService.getSessionData(key);
    final hasLabels = readings.any((r) => r.label != 'smooth');
    final duration = readings.length * 0.2;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openGraph(key),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.route, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Session ${sessions.length - index}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatSessionDate(key),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (hasLabels)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "LABELED",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildSessionStat(Icons.data_usage, "${readings.length} pts"),
                    const SizedBox(width: 16),
                    _buildSessionStat(Icons.timer_outlined, "${duration.toStringAsFixed(1)}s"),
                    const Spacer(),
                    _buildActionButton(Icons.cloud_upload_rounded, const Color(0xFF10B981), () => _uploadSession(key)),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.download_rounded, const Color(0xFF3B82F6), () => _exportCSV(key)),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.delete_outline, const Color(0xFFEF4444), () => _deleteSession(key)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}