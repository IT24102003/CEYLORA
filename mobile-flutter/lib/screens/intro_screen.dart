import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/scenic/scenic.dart';
import '../widgets/ui/ui.dart';

/// First-launch intro over the rotating Sri Lanka scenery: logo, headline and one round "go" button.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ScenicBackground(reach: 1, scrim: true),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, 104),
              child: Column(
                children: [
                  const SizedBox(height: Space.lg),
                  FadeInUp(child: const LogoBadge(height: 150)),
                  const Spacer(),
                  FadeInUp(
                    index: 1,
                    child: ValueListenableBuilder<int>(
                      valueListenable: Scenic.instance.index,
                      builder: (context, _, _) => AnimatedSwitcher(
                        duration: Motion.slow,
                        child: Container(
                          key: ValueKey(Scenic.instance.current),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg,
                            vertical: Space.sm,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Radii.full),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 16,
                                color: AppColors.sun,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                Scenic.instance.current.label,
                                style: context.text.labelMedium!.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  FadeInUp(
                    index: 2,
                    child: Text(
                      "Discover\nSri Lanka",
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  FadeInUp(
                    index: 3,
                    child: Text(
                      "Plan trips, book guides and vehicles.",
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge!.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  FadeInUp(
                    index: 4,
                    child: Semantics(
                      button: true,
                      label: "Get started",
                      excludeSemantics: true,
                      child: PressScale(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onDone();
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.sun,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.ink,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
