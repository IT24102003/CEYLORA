import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/browse.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = "id";
  String? _regionFilter;
  String? _typeFilter;
  bool _availableOnly = false;

  static const _types = ["Car", "Van", "SUV", "Bus", "Tuk Tuk"];
  static const _sorts = {"id": "Default", "rating": "Rating", "price": "Price"};

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getVehicles(
        search: _searchController.text.trim(),
        sortBy: _sortBy,
        region: _regionFilter,
        type: _typeFilter,
        available: _availableOnly ? true : null,
      );
      if (mounted) setState(() => _vehicles = results);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load vehicles.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFilters() {
    showFilterSheet(
      context,
      onApply: _loadVehicles,
      onReset: () {
        setState(() {
          _sortBy = "id";
          _regionFilter = null;
          _typeFilter = null;
          _availableOnly = false;
        });
        _loadVehicles();
      },
      sections: (set) => [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Available only"),
          value: _availableOnly,
          onChanged: (v) {
            _availableOnly = v;
            set(() {});
          },
        ),
        FilterChips<String>(
          title: "Sort by",
          options: _sorts.keys.toList(),
          labelOf: (k) => _sorts[k]!,
          value: _sortBy,
          onChanged: (v) {
            _sortBy = v ?? "id";
            set(() {});
          },
        ),
        FilterChips<String>(
          title: "Type",
          options: _types,
          value: _typeFilter,
          onChanged: (v) {
            _typeFilter = v;
            set(() {});
          },
        ),
        FilterChips<String>(
          title: "Region",
          options: kRegions,
          value: _regionFilter,
          onChanged: (v) {
            _regionFilter = v;
            set(() {});
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active =
        [_regionFilter, _typeFilter].where((e) => e != null).length +
        (_availableOnly ? 1 : 0) +
        (_sortBy != "id" ? 1 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicles")),
      body: Column(
        children: [
          FilterBar(
            controller: _searchController,
            onSearch: _loadVehicles,
            hint: "Search by type or region",
            activeFilters: active,
            onFilters: _openFilters,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadVehicles,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadVehicles,
                isEmpty: _vehicles.isEmpty,
                emptyIcon: Icons.directions_car_rounded,
                emptyTitle: "No vehicles found",
                emptyMessage: "Try a different search, or clear the filters.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: _vehicles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    final rating = (v["rating"] as num?)?.toDouble() ?? 0;
                    final available = v["isAvailable"] == true;
                    final images = v["images"] as List?;
                    final cover = images != null && images.isNotEmpty
                        ? (images.firstWhere(
                                (i) => i["isCover"] == true,
                                orElse: () => images.first,
                              ))["imageUrl"]
                              as String?
                        : null;
                    return ListingCard(
                      index: index,
                      title: (v["name"] ?? v["type"] ?? "").toString(),
                      subtitle:
                          "${v["region"] ?? ""} · ${v["capacity"]} seats · LKR ${v["pricePerKm"] ?? 0}/km",
                      imageUrl: cover,
                      fallbackIcon: Icons.directions_car_rounded,
                      meta: rating > 0 ? RatingStars(rating, size: 14) : null,
                      badges: [
                        StatusBadge(
                          available ? "Available" : "Unavailable",
                          tone: available ? Tone.success : Tone.neutral,
                          icon: available
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_rounded,
                        ),
                      ],
                      trailing: FavoriteButton(
                        itemType: "Vehicle",
                        itemId: v["id"],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
