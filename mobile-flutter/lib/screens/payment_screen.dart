import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'review_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isPaying = false;
  bool _paid = false;
  String? _error;

  Future<void> _pay() async {
    setState(() { _isPaying = true; _error = null; });
    try {
      await _apiService.createPayment(
        bookingId: widget.booking["id"],
        amount: (widget.booking["totalPrice"] as num).toDouble(),
      );
      setState(() => _paid = true);
    } catch (e) {
      setState(() => _error = "Payment failed. Please try again.");
    } finally {
      setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _paid ? _buildSuccess() : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Booking #${widget.booking["id"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Amount Due: LKR ${widget.booking["totalPrice"]}",
                    style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text("Sandbox Payment", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const TextField(decoration: InputDecoration(labelText: "Card Number", hintText: "4242 4242 4242 4242")),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: TextField(decoration: InputDecoration(labelText: "Expiry", hintText: "12/28"))),
            SizedBox(width: 12),
            Expanded(child: TextField(decoration: InputDecoration(labelText: "CVV", hintText: "123"))),
          ],
        ),
        const SizedBox(height: 24),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPaying ? null : _pay,
            child: _isPaying ? const CircularProgressIndicator() : const Text("Pay Now"),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text("Payment Successful!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Booking #${widget.booking["id"]} is now confirmed."),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReviewScreen(bookingId: widget.booking["id"])),
                );
            },
            child: const Text("Leave a Review"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Back to Home"),
          ),
        ],
      ),
    );
  }
}