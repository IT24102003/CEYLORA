import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/favorite_button.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _guides = [];
  bool _isLoading = true;
  String? _regionFilter;
  bool _availableOnly = false;

  static const _regions = [
    "Colombo", "Kandy", "Galle", "Nuwara Eliya", "Ella", "Sigiriya",
    "Jaffna", "Trincomalee", "Anuradhapura", "Mirissa",
  ];

  @override
  void initState() {
    super.initState();
    _loadGuides();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadGuides);
  }

  Future<void> _loadGuides() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getGuides(
        search: _searchController.text.trim(),
        region: _regionFilter,
        available: _availableOnly ? true : null,
      );
      if (!mounted) return;
      setState(() => _guides = results);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guides")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search by region or language...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
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
                    _loadGuides();
                  },
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text("Available only"),
                  selected: _availableOnly,
                  onSelected: (val) {
                    setState(() => _availableOnly = val);
                    _loadGuides();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGuides,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _guides.isEmpty
                      ? const Center(child: Text("No guides found."))
                      : ListView.builder(
                          itemCount: _guides.length,
                          itemBuilder: (context, index) {
                            final g = _guides[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text("Guide #${g["id"]}"),
                                subtitle: Text(
                                  "${g["region"] ?? ""} • ${g["languages"] ?? ""} • Rating: ${(g["rating"] ?? 0).toStringAsFixed(1)}",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 12,
                                      color: g["isAvailable"] == true ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    FavoriteButton(itemType: "Guide", itemId: g["id"]),
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
