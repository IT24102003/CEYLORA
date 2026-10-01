import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';
import 'surfaces.dart';

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + 3 * t, 0),
                end: Alignment(-0.5 + 3 * t, 0),
                colors: [p.surface2, p.border, p.surface2],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Generic list-of-cards loading placeholder.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 5,
    this.leading = true,
    this.padding = const EdgeInsets.all(Space.lg),
  });

  final int count;
  final bool leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) => AppCard(
          child: Row(
            children: [
              if (leading) ...[
                const Skeleton(width: 56, height: 56, radius: Radii.md),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 120.0 + (i % 3) * 30, height: 14),
                    const SizedBox(height: Space.sm),
                    const Skeleton(height: 11),
                    const SizedBox(height: 6),
                    const Skeleton(width: 80, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateBody(
    icon: icon,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _StateBody(
    icon: Icons.cloud_off_rounded,
    tone: Tone.danger,
    title: title,
    message: message ?? 'Check your connection and try again.',
    actionLabel: onRetry != null ? 'Try again' : null,
    onAction: onRetry,
  );
}

class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = Tone.info,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon, tone: tone, size: 64),
          const SizedBox(height: Space.lg),
          Text(
            title,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              message!,
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: Space.xl),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              variant: AppButtonVariant.secondary,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Picks between skeleton / error / empty / content, cross-fading between them.
/// Empty and error bodies are scrollable so a surrounding RefreshIndicator still works.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.loading,
    required this.child,
    this.error,
    this.isEmpty = false,
    this.onRetry,
    this.skeleton,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final VoidCallback? onRetry;
  final Widget? skeleton;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (loading) {
      body = KeyedSubtree(
        key: const ValueKey('loading'),
        child: skeleton ?? const SkeletonList(),
      );
    } else if (error != null) {
      body = KeyedSubtree(
        key: const ValueKey('error'),
        child: _scrollCenter(ErrorState(message: error, onRetry: onRetry)),
      );
    } else if (isEmpty) {
      body = KeyedSubtree(
        key: const ValueKey('empty'),
        child: _scrollCenter(
          EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          ),
        ),
      );
    } else {
      body = KeyedSubtree(key: const ValueKey('content'), child: child);
    }
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.out,
      child: body,
    );
  }

  Widget _scrollCenter(Widget w) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Center(child: w),
      ),
    ),
  );
}

/// Fade + rise entrance, staggered by [index] (capped so long lists don't lag).
class FadeInUp extends StatelessWidget {
  const FadeInUp({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = Duration(milliseconds: (index.clamp(0, 8)) * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow + delay,
      curve: Interval(
        delay.inMilliseconds / (Motion.slow + delay).inMilliseconds,
        1,
        curve: Motion.out,
      ),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Floating toast with a tone icon (replaces ad-hoc SnackBars).
void showToast(
  BuildContext context,
  String message, {
  Tone tone = Tone.neutral,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final (icon, color) = switch (tone) {
    Tone.success => (Icons.check_circle_rounded, context.palette.success),
    Tone.danger => (Icons.error_rounded, context.palette.danger),
    Tone.warning => (Icons.warning_amber_rounded, context.palette.warning),
    _ => (Icons.info_rounded, context.palette.info),
  };
  if (tone == Tone.success) HapticFeedback.lightImpact();
  if (tone == Tone.danger) HapticFeedback.mediumImpact();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: tone == Tone.danger ? 5 : 3),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: Space.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Modal bottom sheet that handles keyboard insets and safe areas.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.lg),
                child: Text(title, style: ctx.text.titleLarge),
              ),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation as a bottom sheet — used for every destructive action.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconTile(
              destructive
                  ? Icons.warning_amber_rounded
                  : Icons.help_outline_rounded,
              tone: destructive ? Tone.danger : Tone.info,
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(title, style: ctx.text.titleLarge)),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          message,
          style: ctx.text.bodyLarge!.copyWith(color: ctx.palette.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: confirmLabel,
          variant: destructive
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.pop(ctx, false),
        ),
      ],
    ),
  );
  return result == true;
}
