import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'trip_plan_review_screen.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final _objectiveController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _generatePlan() async {
    if (_objectiveController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _apiService.previewAgentWorkflow(_objectiveController.text.trim());
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripPlanReviewScreen(
              objective: _objectiveController.text.trim(),
              aiResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = "Failed to generate your trip plan. Please try again.");
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
              "Describe your ideal trip and let our AI planner suggest destinations, "
              "hotels, a guide and a vehicle. You'll be able to review and customize "
              "everything before it's sent for approval.",
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
                label: Text(_isSubmitting ? "Generating..." : "Generate Trip Plan"),
                onPressed: _isSubmitting ? null : _generatePlan,
              ),
            ),
            const SizedBox(height: 20),
            if (_isSubmitting) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}