import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getVehicles();
      setState(() => _vehicles = results);
    } catch (e) {
      // ignore, empty state handles it
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicles")),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? const Center(child: Text("No vehicles available."))
                : ListView.builder(
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final v = _vehicles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                          title: Text(v["type"] ?? ""),
                          subtitle: Text(
                            "${v["region"] ?? ""} • Capacity: ${v["capacity"]} • LKR ${v["pricePerKm"] ?? 0}/km",
                          ),
                          trailing: Icon(
                            Icons.circle,
                            size: 12,
                            color: v["isAvailable"] == true ? Colors.green : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}