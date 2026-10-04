import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';

// f The full "tap a booking, see everything" screen — shared by the Tourist (their own
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
      final d = await _apiService.getBookingDetails(widget.bookingId);
      if (mounted) setState(() => _details = d);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load this booking.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _date(dynamic v) {
    final s = (v ?? "").toString();
    return s.length >= 10 ? s.substring(0, 10) : null;
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    if (children.every((w) => w is SizedBox)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.palette.textTertiary),
                const SizedBox(width: Space.sm),
                Text(title, style: context.text.titleSmall),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Booking #${widget.bookingId}")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateView(
          loading: _isLoading,
          error: _error,
          onRetry: _load,
          skeleton: const SkeletonList(count: 4, leading: false),
          child: _details == null ? const SizedBox.shrink() : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final d = _details!;
    final statusLabel = bookingStatusLabel(d["status"]);
    final tourist = d["tourist"];
    final package = d["package"];
    final customTrip = d["customTrip"];
    final guide = d["guide"];
    final vehicle = d["vehicle"];
    final destinations = (package?["destinations"] as List?) ?? [];
    final hotels = (package?["hotels"] as List?) ?? [];
    final paid = d["isPaid"] == true;

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text(d["tripName"] ?? "Tour", style: context.text.headlineSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            BookingStatusBadge(d["status"]),
            StatusBadge(
              paid ? "Paid" : "Unpaid",
              tone: paid ? Tone.success : Tone.danger,
              icon: paid ? Icons.check_rounded : Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        _section("Tour info", Icons.info_outline_rounded, [
          InfoRow("Group size", "${d["groupSize"] ?? 1}"),
          InfoRow("Total price", "LKR ${d["totalPrice"]}"),
          InfoRow("Start date", _date(d["plannedStartDate"])),
          InfoRow("Tour started", _date(d["tripStartedAt"])),
          InfoRow("Booked on", _date(d["createdAt"])),
        ]),
        if (package != null)
          _section("Package", Icons.luggage_rounded, [
            if ((package["description"] ?? "").toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  package["description"],
                  style: context.text.bodyMedium!.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            InfoRow("Duration", "${package["durationDays"]} days"),
            InfoRow("Base price", "LKR ${package["basePrice"]} / person"),
            InfoRow("Max people", "${package["maxPeople"]}"),
          ]),
        if (customTrip != null)
          _section("Custom tour", Icons.route_rounded, [
            InfoRow("Objective", customTrip["objective"]),
            InfoRow("Duration", "${customTrip["durationDays"]} days"),
          ]),
        if (destinations.isNotEmpty)
          _section("Destinations", Icons.place_rounded, [
            for (final dest in destinations)
              InfoRow(
                "Day ${dest["dayNumber"]}",
                "${dest["name"]} (${dest["region"]})",
              ),
          ]),
        if (hotels.isNotEmpty)
          _section("Hotels", Icons.hotel_rounded, [
            for (final h in hotels)
              InfoRow(
                h["region"] ?? "",
                "${h["name"]} — LKR ${h["pricePerNight"]}/night",
              ),
          ]),
        _section("Tourist", Icons.person_outline_rounded, [
          InfoRow("Name", tourist?["name"]),
          InfoRow("Email", tourist?["email"]),
          InfoRow("Phone", tourist?["mobileNumber"]),
        ]),
        if (guide != null)
          _section("Guide", Icons.hiking_rounded, [
            InfoRow("Name", guide["name"]),
            InfoRow("Region", guide["region"]),
            InfoRow("Phone", guide["mobileNumber"]),
            InfoRow(
              "Rating",
              "★ ${((guide["rating"] as num?) ?? 0).toStringAsFixed(1)}",
            ),
          ]),
        if (vehicle != null)
          _section("Vehicle", Icons.directions_car_rounded, [
            InfoRow("Vehicle", "${vehicle["name"]} (${vehicle["type"]})"),
            InfoRow("Capacity", "${vehicle["capacity"]} seats"),
            InfoRow("Rate", "LKR ${vehicle["pricePerKm"]}/km"),
            InfoRow("Owner", vehicle["ownerName"]),
            InfoRow("Owner phone", vehicle["ownerPhone"]),
          ]),
        if (guide == null && vehicle == null && statusLabel != "Pending")
          const InlineAlert(
            "No guide or vehicle has been assigned yet.",
            tone: Tone.info,
          ),
      ],
    );
  }
}
