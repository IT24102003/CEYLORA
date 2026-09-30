import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/favorite_button.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  String _sortBy = "id";
  String? _regionFilter;
  String? _typeFilter;
  bool _availableOnly = false;

  static const _regions = [
    "Colombo", "Kandy", "Galle", "Nuwara Eliya", "Ella", "Sigiriya",
    "Jaffna", "Trincomalee", "Anuradhapura", "Mirissa",
  ];
  static const _types = ["Car", "Van", "SUV", "Bus", "Tuk Tuk"];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadVehicles);
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getVehicles(
        search: _searchController.text.trim(),
        sortBy: _sortBy,
        region: _regionFilter,
        type: _typeFilter,
        available: _availableOnly ? true : null,
      );
      if (!mounted) return;
      setState(() => _vehicles = results);
    } catch (e) {
      // ignore, empty state handles it
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicles")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search by type or region...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: "id", child: Text("Default")),
                    DropdownMenuItem(value: "rating", child: Text("Rating")),
                    DropdownMenuItem(value: "price", child: Text("Price")),
                  ],
                  onChanged: (val) {
                    setState(() => _sortBy = val ?? "id");
                    _loadVehicles();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  value: _regionFilter,
                  hint: const Text("All regions"),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text("All regions")),
                    ..._regions.map((r) => DropdownMenuItem<String?>(value: r, child: Text(r))),
                  ],
                  onChanged: (val) {
                    setState(() => _regionFilter = val);
                    _loadVehicles();
                  },
                ),
                DropdownButton<String?>(
                  value: _typeFilter,
                  hint: const Text("All types"),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text("All types")),
                    ..._types.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                  ],
                  onChanged: (val) {
                    setState(() => _typeFilter = val);
                    _loadVehicles();
                  },
                ),
                FilterChip(
                  label: const Text("Available only"),
                  selected: _availableOnly,
                  onSelected: (val) {
                    setState(() => _availableOnly = val);
                    _loadVehicles();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadVehicles,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _vehicles.isEmpty
                      ? const Center(child: Text("No vehicles found."))
                      : ListView.builder(
                          itemCount: _vehicles.length,
                          itemBuilder: (context, index) {
                            final v = _vehicles[index];
                            final rating = (v["rating"] as num?)?.toDouble() ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                                title: Text(v["type"] ?? ""),
                                subtitle: Text(
                                  "${v["region"] ?? ""} • Capacity: ${v["capacity"]} • LKR ${v["pricePerKm"] ?? 0}/km"
                                  "${rating > 0 ? '\n⭐ ${rating.toStringAsFixed(1)} guest rating' : ''}",
                                ),
                                isThreeLine: rating > 0,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 12,
                                      color: v["isAvailable"] == true ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    FavoriteButton(itemType: "Vehicle", itemId: v["id"]),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
