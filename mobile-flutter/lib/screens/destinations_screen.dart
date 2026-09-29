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

  final Map<int, Map<String, dynamic>?> _weatherCache = {};

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

  Future<void> _loadWeatherFor(int destId, double? lat, double? lon) async {
    if (lat == null || lon == null || _weatherCache.containsKey(destId)) return;
    final weather = await _apiService.getWeather(lat, lon);
    if (mounted) setState(() => _weatherCache[destId] = weather);
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
        final destId = dest["id"];
        final lat = (dest["latitude"] as num?)?.toDouble();
        final lon = (dest["longitude"] as num?)?.toDouble();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.place, color: Colors.teal),
            ),
            title: Text(dest["name"] ?? ""),
            subtitle: Text("${dest["region"] ?? ""} • ${dest["category"] ?? "General"}"),
            trailing: _buildWeatherTrailing(destId, lat, lon),
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
                      if (_weatherCache[destId]?["available"] == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Weather: ${_weatherCache[destId]!["temperature"].toStringAsFixed(0)}°C, "
                          "${_weatherCache[destId]!["description"]}",
                        ),
                      ],
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

  Widget _buildWeatherTrailing(int destId, double? lat, double? lon) {
    if (lat == null || lon == null) return const SizedBox.shrink();

    if (!_weatherCache.containsKey(destId)) {
      // Trigger the fetch once, show a small loading indicator meanwhile
      _loadWeatherFor(destId, lat, lon);
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final w = _weatherCache[destId];
    if (w == null || w["available"] != true) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${(w["temperature"] as num).toStringAsFixed(0)}°C",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          w["isRainy"] == true ? "🌧️" : "☀️",
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}