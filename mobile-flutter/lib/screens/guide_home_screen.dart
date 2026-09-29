import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({super.key});

  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isAvailable = true;
  bool _isUpdating = false;

  Future<void> _toggleAvailability(int guideId) async {
    setState(() => _isUpdating = true);
    try {
      await _apiService.toggleGuideAvailability(guideId, !_isAvailable);
      setState(() => _isAvailable = !_isAvailable);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update availability.")),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${auth.name ?? ''}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Guide / Vehicle Owner Dashboard",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                title: const Text("Available for Assignments"),
                subtitle: Text(_isAvailable ? "You are visible to the matching system" : "You are hidden from new trips"),
                value: _isAvailable,
                onChanged: _isUpdating
                    ? null
                    : (val) {
                        // Note: pass your actual guide ID here (fetched from a guides-by-user lookup in a fuller build)
                        setState(() => _isAvailable = val);
                      },
              ),
            ),
            const SizedBox(height: 20),
            const Text("Assigned Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Expanded(
              child: Center(
                child: Text(
                  "No trips assigned yet.\nCheck back once the admin approves a plan that matches you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}