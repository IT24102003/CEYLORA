import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _packages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await _apiService.getPackages();
      setState(() => _packages = results.where((p) => p["isPublished"] == true).toList());
    } catch (e) {
      setState(() => _error = "Failed to load packages.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Packages")),
      body: RefreshIndicator(
        onRefresh: _loadPackages,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_packages.isEmpty) return const Center(child: Text("No packages available."));

    return ListView.builder(
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final pkg = _packages[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.card_travel)),
            title: Text(pkg["name"] ?? ""),
            subtitle: Text("${pkg["durationDays"]} days • LKR ${pkg["basePrice"]}"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookingScreen(package: pkg)),
              );
            },
          ),
        );
      },
    );
  }
}