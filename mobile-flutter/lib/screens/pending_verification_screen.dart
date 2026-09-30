import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// Shown when a logged-in Guide/VehicleOwner account hasn't been approved by an Admin yet.
class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() => _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  final ApiService _apiService = ApiService();
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    try {
      final stillPending = await context.read<AuthProvider>().refreshVerificationStatus();
      if (mounted && !stillPending) {
        // AuthWrapper will now route to the real dashboard automatically.
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Still under review. Please check back later.")),
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
      appBar: AppBar(title: const Text("Application Pending")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                "Hi ${auth.name ?? ''}, your application is under review",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Our admin team is checking your submitted details and documents. "
                "You'll get a notification once your account is verified — this usually "
                "doesn't take long.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: _isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text("Check Again"),
                onPressed: _isChecking ? null : _checkAgain,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text("Logout"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
