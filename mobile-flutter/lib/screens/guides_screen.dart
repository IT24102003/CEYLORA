import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/browse.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _guides = [];
  bool _isLoading = true;
  String? _error;
  String? _regionFilter;
  bool _availableOnly = false;

  @override
  void initState() {
    super.initState();
    _loadGuides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGuides() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getGuides(
        search: _searchController.text.trim(),
        region: _regionFilter,
        available: _availableOnly ? true : null,
      );
      if (mounted) setState(() => _guides = results);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load guides.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFilters() {
    showFilterSheet(
      context,
      onApply: _loadGuides,
      onReset: () {
        setState(() {
          _regionFilter = null;
          _availableOnly = false;
        });
        _loadGuides();
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
    final active = (_regionFilter != null ? 1 : 0) + (_availableOnly ? 1 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text("Guides")),
      body: Column(
        children: [
          FilterBar(
            controller: _searchController,
            onSearch: _loadGuides,
            hint: "Search by region or language",
            activeFilters: active,
            onFilters: _openFilters,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGuides,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadGuides,
                isEmpty: _guides.isEmpty,
                emptyIcon: Icons.person_search_rounded,
                emptyTitle: "No guides found",
                emptyMessage: "Try a different search, or clear the filters.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: _guides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) {
                    final g = _guides[index];
                    final name = (g["name"] ?? "").toString();
                    final available = g["isAvailable"] == true;
                    final languages = (g["languages"] ?? "").toString();
                    return FadeInUp(
                      index: index,
                      child: AppCard(
                        child: Row(
                          children: [
                            AppAvatar(name.isEmpty ? "G" : name, size: 52),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? "Guide #${g["id"]}" : name,
                                    style: context.text.titleSmall!.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${g["region"] ?? ""}${languages.isNotEmpty ? " · $languages" : ""}",
                                    style: context.text.bodyMedium!.copyWith(
                                      color: context.palette.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: Space.sm),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      RatingStars(
                                        ((g["rating"] ?? 0) as num).toDouble(),
                                      ),
                                      StatusBadge(
                                        available ? "Available" : "Unavailable",
                                        tone: available
                                            ? Tone.success
                                            : Tone.neutral,
                                        icon: available
                                            ? Icons.check_circle_rounded
                                            : Icons.pause_circle_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            FavoriteButton(itemType: "Guide", itemId: g["id"]),
                          ],
                        ),
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
