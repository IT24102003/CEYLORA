import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/favorite_button.dart';

class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _hotels = [];
  bool _isLoading = true;
  String _sortBy = "stars"; // stars | rating | price
  String? _regionFilter;

  static const _regions = [
    "Colombo", "Kandy", "Galle", "Nuwara Eliya", "Ella", "Sigiriya",
    "Jaffna", "Trincomalee", "Anuradhapura", "Mirissa",
  ];

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadHotels);
  }

  Future<void> _loadHotels() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getHotels(
        search: _searchController.text.trim(),
        sortBy: _sortBy,
        region: _regionFilter,
      );
      if (!mounted) return;
      setState(() => _hotels = results);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hotels")),
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
                      hintText: "Search hotels...",
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
                    DropdownMenuItem(value: "stars", child: Text("Stars")),
                    DropdownMenuItem(value: "rating", child: Text("Rating")),
                    DropdownMenuItem(value: "price", child: Text("Price")),
                  ],
                  onChanged: (val) {
                    setState(() => _sortBy = val ?? "stars");
                    _loadHotels();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<String?>(
                value: _regionFilter,
                hint: const Text("All regions"),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text("All regions")),
                  ..._regions.map((r) => DropdownMenuItem<String?>(value: r, child: Text(r))),
                ],
                onChanged: (val) {
                  setState(() => _regionFilter = val);
                  _loadHotels();
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHotels,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hotels.isEmpty
                      ? const Center(child: Text("No hotels found."))
                      : ListView.builder(
                          itemCount: _hotels.length,
                          itemBuilder: (context, index) {
                            final h = _hotels[index];
                            final rating = (h["rating"] as num?)?.toDouble() ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.hotel)),
                                title: Text(h["name"] ?? ""),
                                subtitle: Text(
                                  "${h["region"] ?? ""} • ${List.filled((h["starRating"] ?? 0) as int, "★").join()} • LKR ${h["pricePerNight"]}/night"
                                  "${rating > 0 ? '\n⭐ ${rating.toStringAsFixed(1)} guest rating' : ''}",
                                ),
                                isThreeLine: rating > 0,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("${h["roomsAvailable"]} rooms", style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    FavoriteButton(itemType: "Hotel", itemId: h["id"]),
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
