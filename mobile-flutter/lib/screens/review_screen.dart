import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/ui/ui.dart';

class ReviewScreen extends StatefulWidget {
  final int bookingId;
  const ReviewScreen({super.key, required this.bookingId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ApiService _apiService = ApiService();
  final _commentController = TextEditingController();
  int _rating = 5;
  int _hotelRating = 0; // 0 = skip (tourist didn't stay at a hotel, or doesn't want to rate it)
  int _vehicleRating = 0; // 0 = skip
  File? _photo;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await pickPhotoSource(context);
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      await _apiService.submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentController.text.trim(),
        hotelRating: _hotelRating > 0 ? _hotelRating : null,
        vehicleRating: _vehicleRating > 0 ? _vehicleRating : null,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          "We couldn't submit your review. Please try again.",
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_submitted ? "Review" : "Leave a review")),
      body: AnimatedSwitcher(
        duration: Motion.slow,
        child: _submitted ? _buildThanks() : _buildForm(),
      ),
    );
  }

  Widget _buildThanks() {
    return Center(
      key: const ValueKey('thanks'),
      child: Padding(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: Motion.slow,
              curve: Motion.spring,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const IconTile(
                Icons.check_rounded,
                tone: Tone.success,
                size: 88,
              ),
            ),
            const SizedBox(height: Space.xl),
            Text("Thank you!", style: context.text.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(
              "Your review helps other travellers and rewards great guides.",
              textAlign: TextAlign.center,
              style: context.text.bodyLarge!.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: Space.xxl),
            AppButton(
              label: "Done",
              onPressed: () => Navigator.pop(context),
              expand: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(Space.xl),
      children: [
        AppCard(
          child: _StarRating(
            label: "Rate your guide",
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
            required: true,
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: _StarRating(
            label: "Rate the hotel",
            value: _hotelRating,
            onChanged: (v) => setState(() => _hotelRating = v),
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: _StarRating(
            label: "Rate the vehicle",
            value: _vehicleRating,
            onChanged: (v) => setState(() => _vehicleRating = v),
          ),
        ),
        const SizedBox(height: Space.xl),
        AppTextField(
          label: "Your experience",
          controller: _commentController,
          maxLines: 4,
          hint: "Tell us about your trip…",
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Space.lg),
        if (_photo != null) ...[
          PickedPhoto(file: _photo!),
          const SizedBox(height: Space.sm),
        ],
        AppButton(
          label: _photo == null ? "Add a photo" : "Change photo",
          icon: Icons.add_a_photo_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: _pickImage,
        ),
        const SizedBox(height: Space.xxl),
        AppButton(
          label: "Submit review",
          loading: _isSubmitting,
          onPressed: _submitReview,
        ),
      ],
    );
  }
}

class PickedPhoto extends StatelessWidget {
  const PickedPhoto({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: kIsWeb
          ? Image.network(
              file.path,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : Image.file(
              file,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
    );
  }
}

/// 5-star tap rating with large touch targets. Optional ratings can be cleared.
class _StarRating extends StatelessWidget {
  const _StarRating({
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleSmall)),
            if (!required)
              value > 0
                  ? TextButton(
                      onPressed: () => onChanged(0),
                      child: const Text("Clear"),
                    )
                  : Text("Optional", style: context.text.bodySmall),
          ],
        ),
        Semantics(
          label: "$label: $value out of 5",
          child: Row(
            children: List.generate(5, (i) {
              final filled = i < value;
              return Expanded(
                child: IconButton(
                  tooltip: "${i + 1} star${i == 0 ? '' : 's'}",
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onChanged(i + 1);
                  },
                  icon: AnimatedSwitcher(
                    duration: Motion.fast,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey(filled),
                      size: 36,
                      color: filled
                          ? const Color(0xFFF59E0B)
                          : context.palette.textTertiary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
