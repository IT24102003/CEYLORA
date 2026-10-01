import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/ui/ui.dart';

// Shown when a logged-in Guide/VehicleOwner account hasn't been approved by an Admin yet.
class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    try {
      final stillPending = await context
          .read<AuthProvider>()
          .refreshVerificationStatus();
      // When no longer pending, AuthWrapper routes to the real dashboard automatically.
      if (mounted && stillPending) {
        showToast(
          context,
          "Still under review. Please check back later.",
          tone: Tone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Application pending")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(
                Icons.hourglass_top_rounded,
                tone: Tone.warning,
                size: 88,
              ),
              const SizedBox(height: Space.xl),
              Text(
                "Hi ${auth.name ?? ''}, your application is under review",
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.md),
              Text(
                "Our admin team is checking your submitted details and documents. You'll get a notification once your account is verified — this usually doesn't take long.",
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: Space.xxl),
              AppButton(
                label: "Check again",
                icon: Icons.refresh_rounded,
                loading: _isChecking,
                onPressed: _checkAgain,
              ),
              const SizedBox(height: Space.sm),
              AppButton(
                label: "Sign out",
                variant: AppButtonVariant.ghost,
                onPressed: () => context.read<AuthProvider>().logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
