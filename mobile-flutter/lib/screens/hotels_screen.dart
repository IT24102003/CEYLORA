import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _hotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getHotels();
      setState(() => _hotels = results);
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hotels")),
      body: RefreshIndicator(
        onRefresh: _loadHotels,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hotels.isEmpty
                ? const Center(child: Text("No hotels available."))
                : ListView.builder(
                    itemCount: _hotels.length,
                    itemBuilder: (context, index) {
                      final h = _hotels[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.hotel)),
                          title: Text(h["name"] ?? ""),
                          subtitle: Text(
                            "${h["region"] ?? ""} • ${List.filled((h["starRating"] ?? 0) as int, "★").join()} • LKR ${h["pricePerNight"]}/night",
                          ),
                          trailing: Text("${h["roomsAvailable"]} rooms"),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}