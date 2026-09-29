import 'package:flutter/material.dart';
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

  Future<void> _confirmBooking() async {
    setState(() { _isBooking = true; _error = null; });
    try {
      final booking = await _apiService.createBooking(
        packageId: widget.package["id"],
        groupSize: _groupSize,
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

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final total = (pkg["basePrice"] ?? 0) * _groupSize;

    return Scaffold(
      appBar: AppBar(title: const Text("Book Package")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pkg["name"] ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(pkg["description"] ?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Text("Duration: ${pkg["durationDays"]} days"),
            Text("Base Price: LKR ${pkg["basePrice"]} per person"),
            const SizedBox(height: 20),
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
                  onPressed: () => setState(() => _groupSize++),
                ),
              ],
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