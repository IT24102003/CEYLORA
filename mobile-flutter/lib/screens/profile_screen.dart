import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getMyBookings();
      setState(() => _bookings = results);
    } catch (e) {
      // ignore, empty state handles it
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      (auth.name?.isNotEmpty == true) ? auth.name![0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 28, color: Colors.teal),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(auth.name ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(auth.role ?? "", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                      ).then((_) => _loadBookings());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text("Booking & Payment History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_bookings.isEmpty)
              const Text("No bookings yet.", style: TextStyle(color: Colors.grey))
            else
              ..._bookings.map((b) {
                const statusNames = ["Pending", "Confirmed", "Cancelled", "Completed"];
                final statusLabel = b["status"] is int ? statusNames[b["status"]] : b["status"];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text("Booking #${b["id"]} — ${b["package"]?["name"] ?? ''}"),
                    subtitle: Text("LKR ${b["totalPrice"]} • $statusLabel"),
                    trailing: Text(
                      (b["createdAt"] ?? "").toString().substring(0, 10),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}