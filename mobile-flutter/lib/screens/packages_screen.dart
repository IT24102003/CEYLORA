import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/browse.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';
import 'booking_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _packages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getPackages(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(
        () =>
            _packages = results.where((p) => p["isPublished"] == true).toList(),
      );
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load packages.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Packages")),
      body: Column(
        children: [
          FilterBar(
            controller: _searchController,
            onSearch: _loadPackages,
            hint: "Search packages",
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPackages,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadPackages,
                isEmpty: _packages.isEmpty,
                emptyIcon: Icons.luggage_rounded,
                emptyTitle: "No packages found",
                emptyMessage: "Try a different search, or plan a custom trip with AI from Home.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: _packages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) =>
                      PackageCard(pkg: _packages[index], index: index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the package summary card, shared by the Packages list and the Home screen.
class PackageCard extends StatelessWidget {
  const PackageCard({super.key, required this.pkg, this.index = 0});
  final dynamic pkg;
  final int index;

  @override
  Widget build(BuildContext context) {
    final stops = (pkg["destinations"] as List?)?.length ?? 0;
    return ListingCard(
      index: index,
      title: pkg["name"] ?? "",
      subtitle: "LKR ${pkg["basePrice"]} per person",
      imageUrl: pkg["imageUrl"],
      fallbackIcon: Icons.luggage_rounded,
      badges: [
        StatusBadge(
          "${pkg["durationDays"]} days",
          tone: Tone.info,
          icon: Icons.schedule_rounded,
        ),
        if (stops > 0) StatusBadge(stops == 1 ? "1 stop" : "$stops stops", icon: Icons.route_rounded),
        if (pkg["maxPeople"] != null)
          StatusBadge("Up to ${pkg["maxPeople"]}", icon: Icons.group_rounded),
      ],
      trailing: FavoriteButton(itemType: "Package", itemId: pkg["id"]),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(package: pkg)),
      ),
    );
  }
}
