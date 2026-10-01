import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/browse.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _destinations = [];
  bool _isLoading = true;
  String? _error;
  String? _categoryFilter;

  final Map<int, Map<String, dynamic>?> _weatherCache = {};
  final Set<int> _weatherRequested = {};

  static const _categories = [
    "Nature",
    "Cultural",
    "Adventure",
    "Beach",
    "Wildlife",
    "Historical",
  ];

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getDestinations(
        search: _searchController.text.trim(),
        category: _categoryFilter,
      );
      if (mounted) setState(() => _destinations = results);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load destinations.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeatherFor(int destId, double? lat, double? lon) async {
    if (lat == null || lon == null || !_weatherRequested.add(destId)) return;
    final weather = await _apiService.getWeather(lat, lon);
    if (mounted) setState(() => _weatherCache[destId] = weather);
  }

  void _showDetails(dynamic dest) {
    final w = _weatherCache[dest["id"]];
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((dest["imageUrl"] ?? '').toString().isNotEmpty) ...[
            NetImage(dest["imageUrl"], height: 180, radius: Radii.lg),
            const SizedBox(height: Space.lg),
          ],
          Text(dest["name"] ?? "", style: ctx.text.headlineSmall),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              StatusBadge(
                dest["region"] ?? "Sri Lanka",
                tone: Tone.info,
                icon: Icons.place_rounded,
              ),
              StatusBadge(
                dest["category"] ?? "General",
                icon: Icons.category_rounded,
              ),
              if (w != null && w["available"] == true)
                StatusBadge(
                  "${(w["temperature"] as num).toStringAsFixed(0)}°C · ${w["description"]}",
                  tone: w["isRainy"] == true ? Tone.info : Tone.warning,
                  icon: w["isRainy"] == true
                      ? Icons.water_drop_rounded
                      : Icons.wb_sunny_rounded,
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            dest["description"] ?? "No description available.",
            style: ctx.text.bodyLarge!.copyWith(
              color: ctx.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Destinations")),
      body: Column(
        children: [
          FilterBar(
            controller: _searchController,
            onSearch: _loadDestinations,
            hint: "Search destinations",
          ),
          ChoiceChipRow<String>(
            options: _categories,
            value: _categoryFilter,
            onChanged: (v) {
              setState(() => _categoryFilter = v);
              _loadDestinations();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDestinations,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadDestinations,
                isEmpty: _destinations.isEmpty,
                emptyIcon: Icons.explore_off_rounded,
                emptyTitle: "No destinations found",
                emptyMessage: "Try a different search or category.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: _destinations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) {
                    final dest = _destinations[index];
                    final destId = dest["id"] as int;
                    final lat = (dest["latitude"] as num?)?.toDouble();
                    final lon = (dest["longitude"] as num?)?.toDouble();
                    if (lat != null && lon != null) {
                      _loadWeatherFor(destId, lat, lon);
                    }
                    final w = _weatherCache[destId];
                    return ListingCard(
                      index: index,
                      title: dest["name"] ?? "",
                      subtitle: dest["region"] ?? "",
                      imageUrl: dest["imageUrl"],
                      fallbackIcon: Icons.landscape_rounded,
                      onTap: () => _showDetails(dest),
                      badges: [
                        StatusBadge(dest["category"] ?? "General"),
                        if (w != null && w["available"] == true)
                          StatusBadge(
                            "${(w["temperature"] as num).toStringAsFixed(0)}°C",
                            tone: w["isRainy"] == true
                                ? Tone.info
                                : Tone.warning,
                            icon: w["isRainy"] == true
                                ? Icons.water_drop_rounded
                                : Icons.wb_sunny_rounded,
                          ),
                      ],
                      trailing: FavoriteButton(
                        itemType: "Destination",
                        itemId: destId,
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
