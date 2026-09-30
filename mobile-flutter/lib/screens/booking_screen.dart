import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> package;
  const BookingScreen({super.key, required this.package});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _apiService = ApiService();
  int _groupSize = 1;
  bool _isBooking = false;
  String? _error;
  DateTime? _startDate;

  int get _maxPeople => (widget.package["maxPeople"] as num?)?.toInt() ?? 999;

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _confirmBooking() async {
    if (_startDate == null) {
      setState(() => _error = "Please select a trip start date.");
      return;
    }
    setState(() { _isBooking = true; _error = null; });
    try {
      final booking = await _apiService.createBooking(
        packageId: widget.package["id"],
        groupSize: _groupSize,
        startDate: _startDate!,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PaymentScreen(booking: booking)),
        );
      }
    } catch (e) {
      setState(() => _error = "Booking failed. Please try again.");
    } finally {
      setState(() => _isBooking = false);
    }
  }

  // Builds a Google Maps directions link from the package's destinations (already ordered
  // by DayNumber from the backend) and opens it — same pattern used on the AI trip-plan
  // review screen and the admin Packages page.
  Future<void> _viewRouteOnMap() async {
    final destinations = (widget.package["destinations"] as List?) ?? [];
    final points = destinations
        .where((d) => d["latitude"] != null && d["longitude"] != null)
        .toList();
    if (points.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This package has no mapped destinations yet.")),
        );
      }
      return;
    }
    final origin = "${points.first["latitude"]},${points.first["longitude"]}";
    final destination = "${points.last["latitude"]},${points.last["longitude"]}";
    final waypoints = points.length > 2
        ? points.sublist(1, points.length - 1).map((p) => "${p["latitude"]},${p["longitude"]}").join("|")
        : "";
    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination"
      "${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}&travelmode=driving",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final total = (pkg["basePrice"] ?? 0) * _groupSize;
    final destinations = (pkg["destinations"] as List?) ?? [];
    final hotels = (pkg["hotels"] as List?) ?? [];
    final suggestedGuideName = pkg["suggestedGuideName"];
    final suggestedVehicleName = pkg["suggestedVehicleName"];
    final startLabel = _startDate == null
        ? "Select a date"
        : "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: const Text("Book Package")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pkg["name"] ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if ((pkg["description"] ?? "").toString().isNotEmpty)
              Text(pkg["description"], style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text("Duration: ${pkg["durationDays"]} days"),
            Text("Base Price: LKR ${pkg["basePrice"]} per person"),
            Text("Max group size: $_maxPeople"),
            const SizedBox(height: 16),

            if (destinations.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Destinations & Route", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _viewRouteOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text("View Route"),
                  ),
                ],
              ),
              ...destinations.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("Day ${d["dayNumber"]}: ${d["name"]} (${d["region"]})"),
                  )),
              const SizedBox(height: 16),
            ],

            if (hotels.isNotEmpty) ...[
              const Text("Hotels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ...hotels.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("${h["name"]} (${h["region"]}) — LKR ${h["pricePerNight"]}/night"),
                  )),
              const SizedBox(height: 16),
            ],

            if (suggestedGuideName != null || suggestedVehicleName != null) ...[
              const Text("Suggested Guide & Vehicle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (suggestedGuideName != null) Text("Guide: $suggestedGuideName"),
              if (suggestedVehicleName != null) Text("Vehicle: $suggestedVehicleName"),
              const SizedBox(height: 16),
            ],

            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Group Size:", style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _groupSize > 1 ? () => setState(() => _groupSize--) : null,
                ),
                Text("$_groupSize", style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _groupSize < _maxPeople ? () => setState(() => _groupSize++) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: const Text("Trip Start Date", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(startLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDate,
            ),
            const Divider(height: 32),
            Text("Total: LKR $total", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _confirmBooking,
                child: _isBooking
                    ? const CircularProgressIndicator()
                    : const Text("Confirm Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
