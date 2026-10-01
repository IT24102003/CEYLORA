import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;

  List<dynamic> _favoriteDestinations = [];
  List<dynamic> _favoritePackages = [];
  List<dynamic> _favoriteHotels = [];
  List<dynamic> _favoriteGuides = [];
  List<dynamic> _favoriteVehicles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final favorites = await _apiService.getFavorites();

      Set<dynamic> idsOf(String type) => favorites
          .where((f) => f["itemType"] == type)
          .map((f) => f["itemId"])
          .toSet();
      final destIds = idsOf("Destination");
      final pkgIds = idsOf("Package");
      final hotelIds = idsOf("Hotel");
      final guideIds = idsOf("Guide");
      final vehicleIds = idsOf("Vehicle");

      // Only fetch full lists for categories that actually have favorites, to save requests.
      final results = await Future.wait([
        destIds.isNotEmpty ? _apiService.getDestinations() : Future.value([]),
        pkgIds.isNotEmpty ? _apiService.getPackages() : Future.value([]),
        hotelIds.isNotEmpty ? _apiService.getHotels() : Future.value([]),
        guideIds.isNotEmpty ? _apiService.getGuides() : Future.value([]),
        vehicleIds.isNotEmpty ? _apiService.getVehicles() : Future.value([]),
      ]);

      if (!mounted) return;
      setState(() {
        _favoriteDestinations = (results[0])
            .where((d) => destIds.contains(d["id"]))
            .toList();
        _favoritePackages = (results[1])
            .where((p) => pkgIds.contains(p["id"]))
            .toList();
        _favoriteHotels = (results[2])
            .where((h) => hotelIds.contains(h["id"]))
            .toList();
        _favoriteGuides = (results[3])
            .where((g) => guideIds.contains(g["id"]))
            .toList();
        _favoriteVehicles = (results[4])
            .where((v) => vehicleIds.contains(v["id"]))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load your favorites.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isEmpty =>
      _favoriteDestinations.isEmpty &&
      _favoritePackages.isEmpty &&
      _favoriteHotels.isEmpty &&
      _favoriteGuides.isEmpty &&
      _favoriteVehicles.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateView(
          loading: _isLoading,
          error: _error,
          onRetry: _load,
          isEmpty: _isEmpty,
          emptyIcon: Icons.favorite_border_rounded,
          emptyTitle: "No favorites yet",
          emptyMessage: "Tap the heart on any destination, package, hotel, guide or vehicle to save it here.",
          child: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              if (_favoriteDestinations.isNotEmpty)
                ..._section(
                  "Destinations",
                  Icons.place_rounded,
                  _favoriteDestinations,
                  "Destination",
                  (d) => d["name"],
                  (d) => d["region"],
                ),
              if (_favoritePackages.isNotEmpty)
                ..._section(
                  "Packages",
                  Icons.luggage_rounded,
                  _favoritePackages,
                  "Package",
                  (p) => p["name"],
                  (p) => "LKR ${p["basePrice"]}",
                ),
              if (_favoriteHotels.isNotEmpty)
                ..._section(
                  "Hotels",
                  Icons.hotel_rounded,
                  _favoriteHotels,
                  "Hotel",
                  (h) => h["name"],
                  (h) =>
                      "${h["region"] ?? ''} · LKR ${h["pricePerNight"]}/night",
                ),
              if (_favoriteGuides.isNotEmpty)
                ..._section(
                  "Guides",
                  Icons.person_rounded,
                  _favoriteGuides,
                  "Guide",
                  (g) => g["name"] ?? "Guide #${g["id"]}",
                  (g) => g["region"],
                ),
              if (_favoriteVehicles.isNotEmpty)
                ..._section(
                  "Vehicles",
                  Icons.directions_car_rounded,
                  _favoriteVehicles,
                  "Vehicle",
                  (v) => v["name"] ?? v["type"],
                  (v) => v["region"],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _section(
    String title,
    IconData icon,
    List<dynamic> items,
    String itemType,
    String Function(dynamic) titleOf,
    String? Function(dynamic) subtitleOf,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.sm),
        child: SectionHeader(title),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: GlassTile(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                IconTile(icon),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleOf(item), style: context.text.titleSmall),
                      if ((subtitleOf(item) ?? "").isNotEmpty)
                        Text(
                          subtitleOf(item)!,
                          style: context.text.bodyMedium!.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                FavoriteButton(itemType: itemType, itemId: item["id"]),
              ],
            ),
          ),
        ),
    ];
  }
}
