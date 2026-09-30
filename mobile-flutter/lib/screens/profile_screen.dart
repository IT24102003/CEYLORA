import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'profile_edit_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'booking_details_screen.dart';
import 'review_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _bookings = [];
  Map<int, int> _unreadChatCounts = {};
  final Set<int> _reviewedBookingIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getMyBookings();
      final unread = await _apiService.getChatUnreadCounts();
      setState(() {
        _bookings = results;
        _unreadChatCounts = unread;
      });
      // Check which "Ended" trips already have a review, so we don't offer the button twice.
      final endedIds = results
          .where((b) => (b["status"] is int ? b["status"] == 3 : b["status"] == "Ended"))
          .map<int>((b) => b["id"] as int)
          .toList();
      for (final id in endedIds) {
        final reviews = await _apiService.getReviewsForBooking(id);
        if (reviews.isNotEmpty && mounted) {
          setState(() => _reviewedBookingIds.add(id));
        }
      }
    } catch (e) {
      // ignore, empty state handles it
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _payNow(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(booking: booking)),
    ).then((_) => _loadBookings());
  }

  void _openChat(int bookingId, String packageName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(bookingId: bookingId, title: packageName.isNotEmpty ? packageName : "Chat"),
      ),
    ).then((_) => _loadBookings());
  }

  Future<void> _confirmCancelBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Booking?"),
        content: Text("Are you sure you want to cancel booking #$bookingId? This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep Booking")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.cancelBooking(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking cancelled.")),
        );
      }
      _loadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to cancel booking.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      (auth.name?.isNotEmpty == true) ? auth.name![0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 28, color: Colors.teal),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(auth.name ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(auth.role ?? "", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                      ).then((_) => _loadBookings());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text("Booking & Payment History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_bookings.isEmpty)
              const Text("No bookings yet.", style: TextStyle(color: Colors.grey))
            else
              ..._bookings.map((b) {
                // Must match the backend's BookingStatus enum order exactly (Booking.cs).
                const statusNames = ["Pending", "Confirmed", "Cancelled", "Ended", "OnGoing", "Rejected"];
                final statusLabel = b["status"] is int ? statusNames[b["status"]] : b["status"];
                final isCancellable = statusLabel == "Pending" || statusLabel == "Confirmed";
                final canChat = statusLabel == "Confirmed" || statusLabel == "OnGoing" || statusLabel == "Ended";
                final unread = _unreadChatCounts[b["id"]] ?? 0;
                // Package name may come back either as the flat "packageName" string or the
                // nested "package" object, depending on backend version — cover both.
                final packageName = b["packageName"] ?? b["package"]?["name"] ?? '';
                final isPaid = b["isPaid"] == true;
                // AI-planned trips pay AFTER the admin confirms them — show "Pay Now" once
                // Confirmed but not yet paid.
                final needsPayment = statusLabel == "Confirmed" && !isPaid;
                final canReview = statusLabel == "Ended" && !_reviewedBookingIds.contains(b["id"]);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text("Booking #${b["id"]} — $packageName"),
                          subtitle: Text("LKR ${b["totalPrice"]} • $statusLabel${isPaid ? ' • Paid' : ''}"),
                          trailing: Text(
                            (b["createdAt"] ?? "").toString().substring(0, 10),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b["id"])),
                            );
                          },
                        ),
                        if (canReview)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.rate_review_outlined, size: 18, color: Colors.amber),
                                  label: const Text("Leave a Review", style: TextStyle(color: Colors.amber)),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ReviewScreen(bookingId: b["id"])),
                                    );
                                    if (mounted) setState(() => _reviewedBookingIds.add(b["id"]));
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (canChat || isCancellable || needsPayment)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (needsPayment)
                                  TextButton.icon(
                                    icon: const Icon(Icons.payment, size: 18, color: Colors.green),
                                    label: const Text("Pay Now", style: TextStyle(color: Colors.green)),
                                    onPressed: () => _payNow(Map<String, dynamic>.from(b)),
                                  ),
                                if (canChat)
                                  TextButton.icon(
                                    icon: Badge(
                                      isLabelVisible: unread > 0,
                                      label: Text("$unread"),
                                      child: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.teal),
                                    ),
                                    label: const Text("Chat with Guide", style: TextStyle(color: Colors.teal)),
                                    onPressed: () => _openChat(b["id"], packageName),
                                  ),
                                if (isCancellable)
                                  TextButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                    label: const Text("Cancel Booking", style: TextStyle(color: Colors.red)),
                                    onPressed: () => _confirmCancelBooking(b["id"]),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}