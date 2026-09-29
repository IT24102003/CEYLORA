import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _guides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuides();
  }

  Future<void> _loadGuides() async {
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getGuides();
      setState(() => _guides = results);
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guides")),
      body: RefreshIndicator(
        onRefresh: _loadGuides,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _guides.isEmpty
                ? const Center(child: Text("No guides available."))
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
                          trailing: Icon(
                            Icons.circle,
                            size: 12,
                            color: g["isAvailable"] == true ? Colors.green : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}