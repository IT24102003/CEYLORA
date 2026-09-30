import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';
import 'currency_converter_screen.dart';
import 'booking_details_screen.dart';

class VehicleOwnerHomeScreen extends StatefulWidget {
  const VehicleOwnerHomeScreen({super.key});

  @override
  State<VehicleOwnerHomeScreen> createState() => _VehicleOwnerHomeScreenState();
}

class _VehicleOwnerHomeScreenState extends State<VehicleOwnerHomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _ownerProfile;
  List<dynamic> _vehicles = [];
  List<dynamic> _assignments = [];
  Map<String, dynamic>? _earnings;
  final Set<int> _updatingVehicleIds = {};

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
      final profile = await _apiService.getMyVehicleOwnerProfile();
      if (profile == null) {
        setState(() => _error = "No vehicle owner profile is linked to this account yet. Contact the admin.");
        return;
      }
      final results = await Future.wait([
        _apiService.getMyVehicles(),
        _apiService.getMyVehicleAssignments(),
        _apiService.getVehicleOwnerEarnings(profile["id"]),
      ]);
      setState(() {
        _ownerProfile = profile;
        _vehicles = results[0] as List<dynamic>;
        _assignments = results[1] as List<dynamic>;
        _earnings = results[2] as Map<String, dynamic>?;
      });
    } catch (e) {
      setState(() => _error = "Failed to load your dashboard.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability(int vehicleId, bool newValue) async {
    setState(() => _updatingVehicleIds.add(vehicleId));
    try {
      await _apiService.toggleVehicleAvailability(vehicleId, newValue);
      if (!mounted) return;
      setState(() {
        final v = _vehicles.firstWhere((v) => v["id"] == vehicleId, orElse: () => null);
        if (v != null) v["isAvailable"] = newValue;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingVehicleIds.remove(vehicleId));
    }
  }

  double get _averageRating {
    if (_vehicles.isEmpty) return 0;
    final ratings = _vehicles.map((v) => (v["rating"] as num?)?.toDouble() ?? 0).toList();
    return ratings.reduce((a, b) => a + b) / ratings.length;
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
    final owner = _ownerProfile!;
    // "Completed" was renamed to "Ended" (Booking.cs BookingStatus enum).
    final assigned = _assignments.where((a) => a["bookingStatus"] != "Ended").toList();
    final completed = _assignments.where((a) => a["bookingStatus"] == "Ended").toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Vehicle Owner Dashboard", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    "Pending Admin verification — your vehicles aren't visible to tourists yet, "
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
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text("${_averageRating.toStringAsFixed(1)} avg. rating", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(owner["region"] ?? "", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ---------------- VEHICLES ----------------
        const Text("My Vehicles", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_vehicles.isEmpty)
          const Text("No vehicles on file.", style: TextStyle(color: Colors.grey))
        else
          ..._vehicles.map((v) {
            final isUpdating = _updatingVehicleIds.contains(v["id"]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                title: Text("${v["name"] ?? v["type"]} (${v["type"]})"),
                subtitle: Text(
                  "${v["capacity"]} seats"
                  "${v["manufacturerYear"] != null ? ' • ${v["manufacturerYear"]}' : ''}"
                  " • ⭐ ${((v["rating"] as num?) ?? 0).toStringAsFixed(1)}",
                ),
                value: v["isAvailable"] == true,
                onChanged: isUpdating ? null : (val) => _toggleAvailability(v["id"], val),
              ),
            );
          }),
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
                    "Estimated using your vehicle's per-km rate × "
                    "${(_earnings!["estimatedKmPerDay"] as num).toStringAsFixed(0)} km/day assumed driving distance.",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        // ---------------- ASSIGNED TRIPS ----------------
        const Text("Assigned Trips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (assigned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("No trips assigned yet.", style: TextStyle(color: Colors.grey)),
          )
        else
          ...assigned.map((a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.card_travel),
                      title: Text(a["packageName"] ?? "Booking #${a["bookingId"]}"),
                      subtitle: Text(
                        "Status: ${a["bookingStatus"]} • ${a["durationDays"] ?? 1} day(s)"
                        "${a["vehicleName"] != null ? ' • ${a["vehicleName"]}' : ''}"
                        "${a["guideName"] != null ? ' • Guide: ${a["guideName"]}' : ''}",
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
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
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
                  ],
                ),
              )),

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
                  subtitle: Text(a["vehicleName"] ?? ""),
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
