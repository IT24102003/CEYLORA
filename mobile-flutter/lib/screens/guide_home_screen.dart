import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';
import 'chat_screen.dart';
import 'chats_list_screen.dart';
import 'profile_edit_screen.dart';
import 'currency_converter_screen.dart';
import 'booking_details_screen.dart';

class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({super.key});

  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _guideProfile; // includes id, isAvailable, rating, region
  List<dynamic> _assignments = [];
  Map<String, dynamic>? _earnings;
  Map<int, int> _unreadChatCounts = {};
  bool _isUpdatingAvailability = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Pick up a fresh verification status too, so the "pending review" banner clears
      // as soon as an Admin has approved — no separate manual check needed.
      await context.read<AuthProvider>().refreshVerificationStatus();
      final profile = await _apiService.getMyGuideProfile();
      if (profile == null) {
        setState(() => _error = "No guide profile is linked to this account yet. Contact the admin.");
        return;
      }
      final results = await Future.wait([
        _apiService.getMyAssignments(),
        _apiService.getGuideEarnings(profile["id"]),
        _apiService.getChatUnreadCounts(),
      ]);
      setState(() {
        _guideProfile = profile;
        _assignments = results[0] as List<dynamic>;
        _earnings = results[1] as Map<String, dynamic>?;
        _unreadChatCounts = results[2] as Map<int, int>;
      });
    } catch (e) {
      setState(() => _error = "Failed to load your dashboard.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrip(int assignmentId) async {
    try {
      await _apiService.startTrip(assignmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip started — status is now On Going.")));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to start trip.")));
      }
    }
  }

  Future<void> _endTrip(int assignmentId) async {
    try {
      await _apiService.endTrip(assignmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip ended.")));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
        );
      }
    }
  }

  Future<void> _toggleAvailability(bool newValue) async {
    if (_guideProfile == null) return;
    setState(() => _isUpdatingAvailability = true);
    try {
      await _apiService.toggleGuideAvailability(_guideProfile!["id"], newValue);
      if (!mounted) return;
      setState(() => _guideProfile!["isAvailable"] = newValue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${auth.name ?? ''}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Profile",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen())).then((_) => _loadAll());
            },
          ),
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            tooltip: "Currency Converter",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "guide_chat_fab",
        tooltip: "Chats",
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsListScreen())).then((_) => _loadAll());
        },
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ],
      );
    }

    final auth = context.watch<AuthProvider>();
    final guide = _guideProfile!;
    final rating = (guide["rating"] as num?)?.toDouble() ?? 0;
    // "Completed" was renamed to "Ended" (Booking.cs BookingStatus enum).
    final assigned = _assignments.where((a) => a["bookingStatus"] != "Ended").toList();
    final completed = _assignments.where((a) => a["bookingStatus"] == "Ended").toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Guide Dashboard", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        if (!auth.isVerified)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Pending Admin verification — you're not visible to tourists yet, "
                    "but the rest of the app works normally.",
                    style: TextStyle(color: Colors.orange.shade900, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text("${rating.toStringAsFixed(1)} rating", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(guide["region"] ?? "", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: SwitchListTile(
            title: const Text("Available for Assignments"),
            subtitle: Text(
              guide["isAvailable"] == true
                  ? "You are visible to the matching system"
                  : "You are hidden from new trips",
            ),
            value: guide["isAvailable"] == true,
            onChanged: _isUpdatingAvailability ? null : _toggleAvailability,
          ),
        ),
        const SizedBox(height: 20),

        // ---------------- EARNINGS ----------------
        const Text("Earnings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_earnings != null)
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Earned", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "LKR ${(_earnings!["totalEstimatedEarnings"] as num).toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Completed Trips", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "${_earnings!["totalCompletedTrips"]}",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Estimated at LKR ${(_earnings!["flatFeePerDay"] as num).toStringAsFixed(0)}/day guided — a flat rate estimate.",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_earnings != null && (_earnings!["trips"] as List).isNotEmpty)
          ...(_earnings!["trips"] as List).map((t) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  title: Text(t["packageName"] ?? "Booking #${t["bookingId"]}"),
                  subtitle: Text("${t["durationDays"]} day(s) • ${(t["completedAt"] ?? '').toString().substring(0, 10)}"),
                  trailing: Text("LKR ${(t["estimatedEarning"] as num).toStringAsFixed(2)}"),
                ),
              ))
        else
          const Text("No completed trips yet.", style: TextStyle(color: Colors.grey)),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        // ---------------- ASSIGNED TRIPS ----------------
        const Text("Assigned Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (assigned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "No trips assigned yet.\nCheck back once the admin approves a plan that matches you.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...assigned.map((a) {
            final unread = _unreadChatCounts[a["bookingId"]] ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.card_travel),
                    title: Text(a["packageName"] ?? "Booking #${a["bookingId"]}"),
                    subtitle: Text(
                      "Status: ${a["bookingStatus"]} • ${a["durationDays"] ?? 1} day(s)"
                      "${a["vehicleName"] != null ? ' • Vehicle: ${a["vehicleName"]}' : ''}"
                      "${a["bookingStatus"] == "OnGoing" && a["canEndTrip"] == false ? '\nCan end trip on/after ${a["earliestEndDate"]}' : ''}",
                    ),
                    trailing: Text(
                      (a["assignedAt"] ?? "").toString().substring(0, 10),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: a["bookingId"])),
                      );
                    },
                  ),
                  if (a["estimatedEarning"] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 16, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text(
                            "Estimated earning for this trip: LKR ${(a["estimatedEarning"] as num).toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 12.5, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (a["bookingStatus"] == "Confirmed" && a["isPaid"] != true)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("Awaiting tourist payment", style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        if (a["bookingStatus"] == "Confirmed" && a["isPaid"] == true)
                          TextButton.icon(
                            icon: const Icon(Icons.play_circle_outline, size: 18, color: Colors.green),
                            label: const Text("Start Trip", style: TextStyle(color: Colors.green)),
                            onPressed: () => _startTrip(a["assignmentId"]),
                          ),
                        if (a["bookingStatus"] == "OnGoing")
                          TextButton.icon(
                            icon: Icon(Icons.stop_circle_outlined, size: 18, color: a["canEndTrip"] == false ? Colors.grey : Colors.red),
                            label: Text("End Trip", style: TextStyle(color: a["canEndTrip"] == false ? Colors.grey : Colors.red)),
                            // Still allow the tap even when not yet allowed by date, so the
                            // guide sees the exact reason from the server rather than a
                            // silently-disabled button.
                            onPressed: () => _endTrip(a["assignmentId"]),
                          ),
                        TextButton.icon(
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text("$unread"),
                            child: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.teal),
                          ),
                          label: const Text("Chat with Tourist", style: TextStyle(color: Colors.teal)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  bookingId: a["bookingId"],
                                  title: a["packageName"] ?? "Chat",
                                ),
                              ),
                            ).then((_) => _loadAll());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 20),

        // ---------------- COMPLETED TRIPS ----------------
        const Text("Completed Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (completed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("No completed trips yet.", style: TextStyle(color: Colors.grey)),
          )
        else
          ...completed.map((a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(a["packageName"] ?? "Booking #${a["bookingId"]}"),
                  subtitle: Text(
                    "Status: ${a["bookingStatus"]}"
                    "${a["vehicleName"] != null ? ' • Vehicle: ${a["vehicleName"]}' : ''}",
                  ),
                  trailing: a["estimatedEarning"] != null
                      ? Text(
                          "LKR ${(a["estimatedEarning"] as num).toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: a["bookingId"])),
                    );
                  },
                ),
              )),
      ],
    );
  }
}
