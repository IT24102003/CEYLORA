import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'buttons.dart';

/// Bordered surface. Pass [onTap] to make the whole card a pressable target.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? context.scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.palette.border),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return PressScale(onTap: onTap, scale: 0.985, child: card);
  }
}

enum Tone { neutral, success, warning, danger, info, accent }

extension ToneColors on Tone {
  (Color fg, Color bg) colors(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      Tone.success => (p.success, p.successSoft),
      Tone.warning => (p.warning, p.warningSoft),
      Tone.danger => (p.danger, p.dangerSoft),
      Tone.info => (p.info, p.infoSoft),
      Tone.accent => (p.accent, p.accentSoft),
      Tone.neutral => (p.textSecondary, p.surface2),
    };
  }
}

/// Status pill. Always pairs colour with text (and optionally an icon) so state is never colour-only.
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.text.labelMedium!.copyWith(color: fg, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Booking status (shared by Trips, booking details and the guide/owner dashboards).
const kBookingStatusNames = [
  'Pending',
  'Confirmed',
  'Cancelled',
  'Ended',
  'OnGoing',
  'Rejected',
];

String bookingStatusLabel(dynamic status) =>
    status is int ? kBookingStatusNames[status] : '$status';

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge(this.status, {super.key});
  final dynamic status;

  @override
  Widget build(BuildContext context) {
    final s = bookingStatusLabel(status);
    final (tone, icon, text) = switch (s) {
      'Pending' => (Tone.warning, Icons.schedule_rounded, 'Pending'),
      'Confirmed' => (
        Tone.info,
        Icons.check_circle_outline_rounded,
        'Confirmed',
      ),
      'OnGoing' => (Tone.accent, Icons.directions_walk_rounded, 'Ongoing'),
      'Ended' => (Tone.success, Icons.flag_rounded, 'Completed'),
      'Cancelled' => (Tone.neutral, Icons.block_rounded, 'Cancelled'),
      'Rejected' => (Tone.danger, Icons.close_rounded, 'Rejected'),
      _ => (Tone.neutral, Icons.help_outline_rounded, s),
    };
    return StatusBadge(text, tone: tone, icon: icon);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleMedium),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                foregroundColor: context.scheme.onSurface,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Label/value row for detail screens. Renders nothing when [value] is empty.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: context.palette.textTertiary),
            const SizedBox(width: Space.sm),
          ],
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.textTertiary,
              ),
            ),
          ),
          Expanded(child: Text(value!, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar(this.name, {super.key, this.size = 44, this.imageUrl});

  final String? name;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.primarySoft,
        image: resolveImageUrl(imageUrl) != null
            ? DecorationImage(image: NetworkImage(resolveImageUrl(imageUrl)!), fit: BoxFit.cover, onError: (_, _) {})
            : null,
      ),
      child: resolveImageUrl(imageUrl) != null
          ? null
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: context.scheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.36,
              ),
            ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {super.key, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: size + 2,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: context.text.labelMedium!.copyWith(fontSize: size - 2),
          ),
        ],
      ),
    );
  }
}

/// Rounded icon tile used for category shortcuts / list leading icons.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.info, this.size = 44});
  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// Network image with a skeleton while loading and an icon fallback on error.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.height,
    this.width,
    this.fallbackIcon = Icons.landscape_rounded,
    this.radius = Radii.md,
    this.overlay = false,
  });

  /// When true the image is drawn over an existing background and shows nothing while loading / on error.
  final bool overlay;
  final String? url;
  final double? height;
  final double? width;
  final IconData fallbackIcon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = overlay
        ? const SizedBox.shrink()
        : Container(
            height: height,
            width: width,
            color: p.surface2,
            alignment: Alignment.center,
            child: Icon(fallbackIcon, color: p.textTertiary, size: 28),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (resolveImageUrl(url) == null)
          ? fallback
          : Image.network(
              resolveImageUrl(url)!,
              height: height,
              width: width,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              // On web, fall back to a plain <img> so images from servers without CORS headers still show.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: Motion.slow,
                curve: Motion.out,
                child: child,
              ),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Inline message block (form-level errors, review banners, helper notices).
class InlineAlert extends StatelessWidget {
  const InlineAlert(
    this.message, {
    super.key,
    this.tone = Tone.danger,
    this.icon,
  });

  final String message;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.colors(context);
    final ic =
        icon ??
        switch (tone) {
          Tone.danger => Icons.error_outline_rounded,
          Tone.warning => Icons.hourglass_top_rounded,
          Tone.success => Icons.check_circle_outline_rounded,
          _ => Icons.info_outline_rounded,
        };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ic, color: fg, size: 20),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium!.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image paths from the API are often relative (e.g. "/uploads/x.jpg"); make them absolute.
String? resolveImageUrl(String? raw) {
  final u = raw?.trim();
  if (u == null || u.isEmpty) return null;
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  final origin = ApiService.baseUrl.replaceAll('/api', '');
  return u.startsWith('/') ? '$origin$u' : '$origin/$u';
}
