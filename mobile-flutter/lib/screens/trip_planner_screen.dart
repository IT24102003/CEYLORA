///the trip planner
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
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

  static const _ideas = [
    "3 days in Kandy for 2 people, nature and culture",
    "A relaxed 5-day beach holiday on the south coast",
    "Family wildlife safari with a stop in Ella",
  ];

  @override
  void dispose() {
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    final objective = _objectiveController.text.trim();
    if (objective.isEmpty) {
      setState(() => _error = "Tell us a little about the tour you'd like.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _apiService.previewAgentWorkflow(objective);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TripPlanReviewScreen(objective: objective, aiResult: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = "We couldn't generate your plan. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan a tour")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                const IconTile(
                  Icons.route_rounded,
                  tone: Tone.accent,
                  size: 52,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    "Where do you want to go?",
                    style: context.text.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              "Our AI planner suggests destinations, hotels, a guide and a vehicle. You can review and customise everything before it's sent for approval.",
              style: context.text.bodyLarge!.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: Space.xxl),
            AppTextField(
              label: "Your tour",
              controller: _objectiveController,
              maxLines: 4,
              enabled: !_isSubmitting,
              error: _error,
              hint: "e.g. 3-day tour to Kandy for 2 people, interested in nature and culture",
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: Space.lg),
            Text("Need inspiration?", style: context.text.labelMedium),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final idea in _ideas)
                  ActionChip(
                    label: Text(idea, style: context.text.labelMedium),
                    onPressed: _isSubmitting
                        ? null
                        : () =>
                              setState(() => _objectiveController.text = idea),
                  ),
              ],
            ),
            const SizedBox(height: Space.xxl),
            AppButton(
              label: _isSubmitting
                  ? "Planning your tour…"
                  : "Generate tour plan",
              icon: Icons.route_rounded,
              loading: _isSubmitting,
              onPressed: _generatePlan,
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.out,
              child: _isSubmitting
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: Text(
                        "This can take up to a minute.",
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
