import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
import 'booking_details_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'review_screen.dart';

///The trips tab (tourists): booking & payment history with the actions each status allows.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

enum _TripFilter { active, completed, closed }

class _TripsScreenState extends State<TripsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _bookings = [];
  Map<int, int> _unreadChatCounts = {};
  final Set<int> _reviewedBookingIds = {};
  bool _isLoading = true;
  String? _error;
  _TripFilter? _filter;
  int? _cancellingId;

  static const _filterLabels = {
    _TripFilter.active: "Active",
    _TripFilter.completed: "Completed",
    _TripFilter.closed: "Cancelled",
  };

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getMyBookings();
      final unread = await _apiService.getChatUnreadCounts();
      if (!mounted) return;
      setState(() {
        _bookings = results;
        _unreadChatCounts = unread;
      });
      // Check which "Ended" trips already have a review, so we don't offer the button twice.
      final endedIds = results
          .where((b) => bookingStatusLabel(b["status"]) == "Ended")
          .map<int>((b) => b["id"] as int)
          .toList();
      for (final id in endedIds) {
        final reviews = await _apiService.getReviewsForBooking(id);
        if (reviews.isNotEmpty && mounted) {
          setState(() => _reviewedBookingIds.add(id));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load your trips.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        builder: (_) => ChatScreen(
          bookingId: bookingId,
          title: packageName.isNotEmpty ? packageName : "Chat",
        ),
      ),
    ).then((_) => _loadBookings());
  }

  Future<void> _confirmCancelBooking(int bookingId) async {
    final confirmed = await confirmSheet(
      context,
      title: "Cancel booking #$bookingId?",
      message: "This can't be undone. Check the cancellation terms of your package before continuing.",
      confirmLabel: "Yes, cancel booking",
      cancelLabel: "Keep booking",
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _cancellingId = bookingId);
    try {
      await _apiService.cancelBooking(bookingId);
      if (mounted) showToast(context, "Booking cancelled.", tone: Tone.success);
      await _loadBookings();
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          "We couldn't cancel the booking. Please try again.",
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  bool _matches(dynamic b) {
    final s = bookingStatusLabel(b["status"]);
    return switch (_filter) {
      null => true,
      _TripFilter.active => const {
        "Pending",
        "Confirmed",
        "OnGoing",
      }.contains(s),
      _TripFilter.completed => s == "Ended",
      _TripFilter.closed => s == "Cancelled" || s == "Rejected",
    };
  }

  @override
  Widget build(BuildContext context) {
    final shown = _bookings.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("My tours")),
      body: Column(
        children: [
          const SizedBox(height: Space.xs),
          ChoiceChipRow<_TripFilter>(
            options: _TripFilter.values,
            value: _filter,
            labelOf: (f) => _filterLabels[f]!,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBookings,
              child: StateView(
                loading: _isLoading,
                error: _error,
                onRetry: _loadBookings,
                isEmpty: shown.isEmpty,
                emptyIcon: Icons.luggage_rounded,
                emptyTitle: _filter == null ? "No tours yet" : "Nothing here",
                emptyMessage: _filter == null
                    ? "Book a package or plan a custom tour with AI — it will show up here."
                    : "No tours match this filter.",
                child: ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, index) =>
                      FadeInUp(index: index, child: _bookingCard(shown[index])),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(dynamic b) {
    final statusLabel = bookingStatusLabel(b["status"]);
    final isCancellable =
        statusLabel == "Pending" || statusLabel == "Confirmed";
    final canChat =
        statusLabel == "Confirmed" ||
        statusLabel == "OnGoing" ||
        statusLabel == "Ended";
    final unread = _unreadChatCounts[b["id"]] ?? 0;
    // Package name may come back either as the flat "packageName" string or the
    // nested "package" object, depending on backend version — cover both.
    final packageName = (b["packageName"] ?? b["package"]?["name"] ?? '')
        .toString();
    final isPaid = b["isPaid"] == true;
    // AI-planned trips pay AFTER the admin confirms them — show "Pay now" once Confirmed but not yet paid.
    final needsPayment = statusLabel == "Confirmed" && !isPaid;
    final canReview =
        statusLabel == "Ended" && !_reviewedBookingIds.contains(b["id"]);
    final created = (b["createdAt"] ?? "").toString();

    return GlassTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(bookingId: b["id"]),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageName.isEmpty ? "Custom tour" : packageName,
                      style: context.text.titleSmall!.copyWith(fontSize: 16.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Booking #${b["id"]}${created.length >= 10 ? " · ${created.substring(0, 10)}" : ""}",
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              BookingStatusBadge(b["status"]),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Text("LKR ${b["totalPrice"]}", style: context.text.titleMedium),
              const SizedBox(width: Space.sm),
              StatusBadge(
                isPaid ? "Paid" : "Unpaid",
                tone: isPaid ? Tone.success : Tone.danger,
                icon: isPaid ? Icons.check_rounded : Icons.payments_outlined,
              ),
            ],
          ),
          if (needsPayment || canChat || isCancellable || canReview) ...[
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (needsPayment)
                  AppButton(
                    label: "Pay now",
                    icon: Icons.payment_rounded,
                    expand: false,
                    compact: true,
                    variant: AppButtonVariant.success,
                    onPressed: () => _payNow(Map<String, dynamic>.from(b)),
                  ),
                if (canReview)
                  AppButton(
                    label: "Leave a review",
                    icon: Icons.rate_review_outlined,
                    expand: false,
                    compact: true,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(bookingId: b["id"]),
                        ),
                      );
                      if (mounted) {
                        setState(() => _reviewedBookingIds.add(b["id"]));
                      }
                    },
                  ),
                if (canChat)
                  AppButton(
                    label: unread > 0
                        ? "Chat with guide ($unread)"
                        : "Chat with guide",
                    icon: Icons.chat_bubble_outline_rounded,
                    expand: false,
                    compact: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _openChat(b["id"], packageName),
                  ),
                if (isCancellable)
                  AppButton(
                    label: "Cancel",
                    icon: Icons.close_rounded,
                    expand: false,
                    compact: true,
                    variant: AppButtonVariant.danger,
                    loading: _cancellingId == b["id"],
                    onPressed: () => _confirmCancelBooking(b["id"]),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
