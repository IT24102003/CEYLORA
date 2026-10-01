import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/browse.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _hotels = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = "stars"; // stars | rating | price
  String? _regionFilter;

  static const _sorts = {
    "stars": "Stars",
    "rating": "Guest rating",
    "price": "Price",
  };

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHotels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getHotels(
        search: _searchController.text.trim(),
        sortBy: _sortBy,
        region: _regionFilter,
      );
      if (mounted) setState(() => _hotels = results);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load hotels.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFilters() {
    showFilterSheet(
      context,
      onApply: _loadHotels,
      onReset: () {
        setState(() {
          _sortBy = "stars";
          _regionFilter = null;
        });
        _loadHotels();
      },
      sections: (set) => [
        FilterChips<String>(
          title: "Sort by",
          options: _sorts.keys.toList(),
          labelOf: (k) => _sorts[k]!,
          value: _sortBy,
          onChanged: (v) {
            _sortBy = v ?? "stars";
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
        (_regionFilter != null ? 1 : 0) + (_sortBy != "stars" ? 1 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text("Hotels")),
      body: Column(
        children: [
          FilterBar(
            controller: _searchController,
            onSearch: _loadHotels,
            hint: "Search hotels",
            activeFilters: active,
            onFilters: _openFilters,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHotels,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadHotels,
                isEmpty: _hotels.isEmpty,
                emptyIcon: Icons.hotel_rounded,
                emptyTitle: "No hotels found",
                emptyMessage: "Try a different search or region.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: _hotels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) {
                    final h = _hotels[index];
                    final rating = (h["rating"] as num?)?.toDouble() ?? 0;
                    final stars = (h["starRating"] as num?)?.toInt() ?? 0;
                    return ListingCard(
                      index: index,
                      title: h["name"] ?? "",
                      subtitle:
                          "${h["region"] ?? ""} · LKR ${h["pricePerNight"]}/night",
                      imageUrl: h["imageUrl"],
                      fallbackIcon: Icons.hotel_rounded,
                      meta: Row(
                        children: [
                          for (var i = 0; i < stars; i++)
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                          if (rating > 0) ...[
                            const SizedBox(width: Space.sm),
                            RatingStars(rating, size: 14),
                          ],
                        ],
                      ),
                      badges: [
                        StatusBadge(
                          "${h["roomsAvailable"]} rooms left",
                          tone: (h["roomsAvailable"] ?? 0) <= 3
                              ? Tone.warning
                              : Tone.neutral,
                        ),
                      ],
                      trailing: FavoriteButton(
                        itemType: "Hotel",
                        itemId: h["id"],
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
