import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Full "tap a booking, see everything" screen — shared by the Tourist (their own
// bookings), the assigned Guide, and the assigned Vehicle's Owner. What's visible is
// decided server-side (GET /api/bookings/{id}/details).
class BookingDetailsScreen extends StatefulWidget {
  final int bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  static const _statusNames = ["Pending", "Confirmed", "Cancelled", "Ended", "OnGoing", "Rejected"];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final d = await _apiService.getBookingDetails(widget.bookingId);
      if (mounted) setState(() => _details = d);
    } catch (e) {
      if (mounted) setState(() => _error = "Failed to load booking details.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _section(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Booking #${widget.bookingId}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _details!;
    final statusLabel = d["status"] is int ? _statusNames[d["status"]] : d["status"];
    final tourist = d["tourist"];
    final package = d["package"];
    final customTrip = d["customTrip"];
    final guide = d["guide"];
    final vehicle = d["vehicle"];
    final destinations = (package?["destinations"] as List?) ?? [];
    final hotels = (package?["hotels"] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(d["tripName"] ?? "Trip", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Chip(label: Text(statusLabel ?? "")),
              const SizedBox(width: 8),
              Chip(
                label: Text(d["isPaid"] == true ? "Paid" : "Unpaid"),
                backgroundColor: d["isPaid"] == true ? Colors.green.shade50 : Colors.red.shade50,
              ),
            ],
          ),
          const SizedBox(height: 20),

          _section("Trip Info", [
            _row("Group Size", "${d["groupSize"] ?? 1}"),
            _row("Total Price", "LKR ${d["totalPrice"]}"),
            _row("Start Date", (d["plannedStartDate"] ?? "").toString().isNotEmpty ? (d["plannedStartDate"]).toString().substring(0, 10) : null),
            _row("Trip Started", (d["tripStartedAt"] ?? "").toString().isNotEmpty ? (d["tripStartedAt"]).toString().substring(0, 10) : null),
            _row("Booked On", (d["createdAt"] ?? "").toString().substring(0, 10)),
          ]),

          if (package != null)
            _section("Package", [
              if ((package["description"] ?? "").toString().isNotEmpty) Text(package["description"]),
              _row("Duration", "${package["durationDays"]} days"),
              _row("Base Price", "LKR ${package["basePrice"]} / person"),
              _row("Max People", "${package["maxPeople"]}"),
            ]),

          if (customTrip != null)
            _section("Custom AI Trip", [
              _row("Objective", customTrip["objective"]),
              _row("Duration", "${customTrip["durationDays"]} days"),
            ]),

          if (destinations.isNotEmpty)
            _section("Destinations", destinations.map<Widget>((dest) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("Day ${dest["dayNumber"]}: ${dest["name"]} (${dest["region"]})"),
                )).toList()),

          if (hotels.isNotEmpty)
            _section("Hotels", hotels.map<Widget>((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("${h["name"]} (${h["region"]}) — LKR ${h["pricePerNight"]}/night"),
                )).toList()),

          _section("Tourist", [
            _row("Name", tourist?["name"]),
            _row("Email", tourist?["email"]),
            _row("Phone", tourist?["mobileNumber"]),
          ]),

          if (guide != null)
            _section("Guide", [
              _row("Name", guide["name"]),
              _row("Region", guide["region"]),
              _row("Phone", guide["mobileNumber"]),
              _row("Rating", "⭐ ${((guide["rating"] as num?) ?? 0).toStringAsFixed(1)}"),
            ]),

          if (vehicle != null)
            _section("Vehicle", [
              _row("Vehicle", "${vehicle["name"]} (${vehicle["type"]})"),
              _row("Capacity", "${vehicle["capacity"]} seats"),
              _row("Rate", "LKR ${vehicle["pricePerKm"]}/km"),
              _row("Owner", vehicle["ownerName"]),
              _row("Owner Phone", vehicle["ownerPhone"]),
            ]),

          if (guide == null && vehicle == null && statusLabel != "Pending")
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("No guide/vehicle assigned yet.", style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}
