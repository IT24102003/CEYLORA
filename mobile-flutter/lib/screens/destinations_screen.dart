import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _destinations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getDestinations();
      setState(() => _destinations = results);
    } catch (e) {
      setState(() => _error = "Failed to load destinations.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Destinations")),
      body: RefreshIndicator(
        onRefresh: _loadDestinations,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDestinations, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_destinations.isEmpty) {
      return const Center(child: Text("No destinations found."));
    }

    return ListView.builder(
      itemCount: _destinations.length,
      itemBuilder: (context, index) {
        final dest = _destinations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.place, color: Colors.teal),
            ),
            title: Text(dest["name"] ?? ""),
            subtitle: Text("${dest["region"] ?? ""} • ${dest["category"] ?? "General"}"),
            isThreeLine: false,
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dest["name"] ?? "",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(dest["description"] ?? "No description available."),
                      const SizedBox(height: 8),
                      Text("Region: ${dest["region"] ?? ""}"),
                      Text("Category: ${dest["category"] ?? "General"}"),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}