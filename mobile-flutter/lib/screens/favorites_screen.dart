import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/favorite_button.dart';

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

      final destIds = favorites.where((f) => f["itemType"] == "Destination").map((f) => f["itemId"]).toSet();
      final pkgIds = favorites.where((f) => f["itemType"] == "Package").map((f) => f["itemId"]).toSet();
      final hotelIds = favorites.where((f) => f["itemType"] == "Hotel").map((f) => f["itemId"]).toSet();
      final guideIds = favorites.where((f) => f["itemType"] == "Guide").map((f) => f["itemId"]).toSet();
      final vehicleIds = favorites.where((f) => f["itemType"] == "Vehicle").map((f) => f["itemId"]).toSet();

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
        _favoriteDestinations = (results[0]).where((d) => destIds.contains(d["id"])).toList();
        _favoritePackages = (results[1]).where((p) => pkgIds.contains(p["id"])).toList();
        _favoriteHotels = (results[2]).where((h) => hotelIds.contains(h["id"])).toList();
        _favoriteGuides = (results[3]).where((g) => guideIds.contains(g["id"])).toList();
        _favoriteVehicles = (results[4]).where((v) => vehicleIds.contains(v["id"])).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Failed to load favorites.");
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
      appBar: AppBar(title: const Text("My Favorites")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.favorite_border, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text("No favorites yet. Tap the heart icon on any listing to save it here.")),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_favoriteDestinations.isNotEmpty) ..._section("Destinations", Icons.place, _favoriteDestinations, "Destination", (d) => d["name"], (d) => d["region"]),
        if (_favoritePackages.isNotEmpty) ..._section("Packages", Icons.card_travel, _favoritePackages, "Package", (p) => p["name"], (p) => "LKR ${p["basePrice"]}"),
        if (_favoriteHotels.isNotEmpty) ..._section("Hotels", Icons.hotel, _favoriteHotels, "Hotel", (h) => h["name"], (h) => "${h["region"] ?? ''} • LKR ${h["pricePerNight"]}/night"),
        if (_favoriteGuides.isNotEmpty) ..._section("Guides", Icons.person, _favoriteGuides, "Guide", (g) => "Guide #${g["id"]}", (g) => g["region"]),
        if (_favoriteVehicles.isNotEmpty) ..._section("Vehicles", Icons.directions_car, _favoriteVehicles, "Vehicle", (v) => v["type"], (v) => v["region"]),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      ...items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(titleOf(item) ?? ""),
              subtitle: Text(subtitleOf(item) ?? ""),
              trailing: FavoriteButton(itemType: itemType, itemId: item["id"]),
            ),
          )),
    ];
  }
}
