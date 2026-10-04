import 'package:flutter/material.dart';

import 'ui/ui.dart';

/// Shown to Guides / Vehicle Owners until an Admin verifies their account.
class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key, required this.what});

  /// "you're" / "your vehicles aren't" phrase, e.g. "you're not"
  final String what;

  @override
  Widget build(BuildContext context) {
    return InlineAlert(
      "Pending admin verification — $what visible to tourists yet, but the rest of the app works normally.",
      tone: Tone.warning,
      icon: Icons.hourglass_top_rounded,
    );
  }
}

/// Big-number stat for dashboards.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = Tone.info,
  });

  final String label;
  final String value;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, tone: tone, size: 36),
          const SizedBox(height: Space.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.text.headlineSmall),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Earnings summary card with a footnote explaining the estimate.
class EarningsCard extends StatelessWidget {
  const EarningsCard({
    super.key,
    required this.total,
    required this.trips,
    required this.footnote,
  });

  final double total;
  final int trips;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.palette.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total earned", style: context.text.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      "LKR ${total.toStringAsFixed(2)}",
                      style: context.text.headlineSmall!.copyWith(
                        color: context.scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Completed tours", style: context.text.bodySmall),
                  const SizedBox(height: 2),
                  Text("$trips", style: context.text.headlineSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(footnote, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Row card for an assigned / completed trip on a dashboard.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.title,
    required this.status,
    required this.lines,
    this.earning,
    this.onTap,
    this.actions = const [],
    this.footnote,
  });

  final String title;
  final dynamic status;
  final List<String> lines;
  final num? earning;
  final VoidCallback? onTap;
  final List<Widget> actions;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall!.copyWith(fontSize: 16),
                ),
              ),
              const SizedBox(width: Space.sm),
              BookingStatusBadge(status),
            ],
          ),
          const SizedBox(height: Space.xs),
          for (final l in lines)
            Text(
              l,
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          if (earning != null) ...[
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: context.scheme.primary,
                ),
                const SizedBox(width: Space.xs),
                Text(
                  "Est. earning LKR ${earning!.toStringAsFixed(2)}",
                  style: context.text.labelMedium!.copyWith(
                    color: context.scheme.primary,
                  ),
                ),
              ],
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: Space.sm),
            Text(footnote!, style: context.text.bodySmall),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: actions),
          ],
        ],
      ),
    );
  }
}
