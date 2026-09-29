import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final _objectiveController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _submitObjective() async {
    if (_objectiveController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _apiService.startAgentWorkflow(_objectiveController.text.trim());
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = "Failed to plan your trip. Please try again.");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan My Trip (AI)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Describe your ideal trip and let our AI planner find destinations, hotels, a guide and a vehicle for you.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _objectiveController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g. Plan a 3-day trip to Kandy for 2 people, interested in nature and culture",
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(_isSubmitting ? "Planning..." : "Generate Trip Plan"),
                onPressed: _isSubmitting ? null : _submitObjective,
              ),
            ),
            const SizedBox(height: 20),
            if (_isSubmitting) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_result != null) Expanded(child: _buildResult()),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final status = _result?["status"]?.toString() ?? "unknown";
    final validationPassed = _result?["validationPassed"];

    return SingleChildScrollView(
      child: Card(
        color: status == "Completed" ? Colors.green.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == "Completed" ? Icons.check_circle : Icons.hourglass_empty,
                    color: status == "Completed" ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text("Status: $status", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text("Validation: ${validationPassed == true ? 'Passed ✓' : 'Needs review'}"),
              const SizedBox(height: 12),
              const Text(
                "Your trip plan has been generated and sent for admin review. "
                "You'll be notified once it's approved.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}