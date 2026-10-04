///vehicel owner home screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/ui/ui.dart';
import 'booking_details_screen.dart';

/// Vehicle-owner dashboard (the second tab for VehicleOwner accounts).
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
    if (!mounted) return;
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
        if (mounted) {
          setState(
            () => _error = "No vehicle owner profile is linked to this account yet. Contact the admin.",
          );
        }
        return;
      }
      final results = await Future.wait([
        _apiService.getMyVehicles(),
        _apiService.getMyVehicleAssignments(),
        _apiService.getVehicleOwnerEarnings(profile["id"]),
      ]);
      if (!mounted) return;
      setState(() {
        _ownerProfile = profile;
        _vehicles = results[0] as List<dynamic>;
        _assignments = results[1] as List<dynamic>;
        _earnings = results[2] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load your dashboard.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability(int vehicleId, bool newValue) async {
    setState(() => _updatingVehicleIds.add(vehicleId));
    try {
      await _apiService.toggleVehicleAvailability(vehicleId, newValue);
      if (!mounted) return;
      setState(() {
        final v = _vehicles.firstWhere(
          (v) => v["id"] == vehicleId,
          orElse: () => null,
        );
        if (v != null) v["isAvailable"] = newValue;
      });
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e.toString().replaceFirst("Exception: ", ""),
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingVehicleIds.remove(vehicleId));
    }
  }

  double get _averageRating {
    if (_vehicles.isEmpty) return 0;
    final ratings = _vehicles
        .map((v) => (v["rating"] as num?)?.toDouble() ?? 0)
        .toList();
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: StateView(
          loading: _isLoading,
          error: _error,
          onRetry: _loadAll,
          skeleton: const SkeletonList(count: 4, leading: false),
          // 🔥 Fix: same bug as the Guide dashboard — `child:` is evaluated
          // immediately when this widget is built, no matter whether
          // StateView ends up showing the loading/error view instead. So
          // `_buildBody()` (which does `_ownerProfile!`) used to run on the
          // very first build too, before `_loadAll()` finished and
          // `_ownerProfile` was still null — crashing with "Null check
          // operator used on a null value". Only call it once loaded.
          child: _ownerProfile != null
              ? _buildBody()
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final auth = context.watch<AuthProvider>();
    final owner = _ownerProfile!;
    // "Completed" was renamed to "Ended" (Booking.cs BookingStatus enum).
    final assigned = _assignments
        .where((a) => a["bookingStatus"] != "Ended")
        .toList();
    final completed = _assignments
        .where((a) => a["bookingStatus"] == "Ended")
        .toList();

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        if (!auth.isVerified) ...[
          const VerificationBanner(what: "your vehicles aren't"),
          const SizedBox(height: Space.lg),
        ],
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: "Avg. rating · ${owner["region"] ?? ""}",
                value: _averageRating.toStringAsFixed(1),
                icon: Icons.star_rounded,
                tone: Tone.warning,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: "Vehicles",
                value: "${_vehicles.length}",
                icon: Icons.directions_car_rounded,
              ),
            ),
          ],
        ),

        // ---------------- VEHICLES ----------------
        const SizedBox(height: Space.xxl),
        const SectionHeader("My vehicles"),
        const SizedBox(height: Space.sm),
        if (_vehicles.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.directions_car_rounded,
              title: "No vehicles on file",
              message: "Vehicles you register will appear here.",
            ),
          )
        else
          for (final v in _vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "${v["name"] ?? v["type"]} (${v["type"]})",
                    style: context.text.titleSmall,
                  ),
                  subtitle: Text(
                    "${v["capacity"]} seats"
                    "${v["manufacturerYear"] != null ? ' · ${v["manufacturerYear"]}' : ''}"
                    " · ★ ${((v["rating"] as num?) ?? 0).toStringAsFixed(1)}\n"
                    "${v["isAvailable"] == true ? "Available for tours" : "Hidden from new tours"}",
                  ),
                  isThreeLine: true,
                  value: v["isAvailable"] == true,
                  onChanged: _updatingVehicleIds.contains(v["id"])
                      ? null
                      : (val) => _toggleAvailability(v["id"], val),
                ),
              ),
            ),

        // ---------------- EARNINGS ----------------
        const SizedBox(height: Space.xxl),
        const SectionHeader("Earnings"),
        const SizedBox(height: Space.sm),
        if (_earnings != null)
          EarningsCard(
            total: (_earnings!["totalEstimatedEarnings"] as num).toDouble(),
            trips: (_earnings!["totalCompletedTrips"] as num).toInt(),
            footnote:
                "Estimated using your vehicle's per-km rate × ${(_earnings!["estimatedKmPerDay"] as num).toStringAsFixed(0)} km/day assumed driving distance.",
          ),

        // ---------------- ASSIGNED TOURS ----------------
        const SizedBox(height: Space.xxl),
        SectionHeader(
          "Assigned tours${assigned.isEmpty ? "" : " (${assigned.length})"}",
        ),
        const SizedBox(height: Space.sm),
        if (assigned.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.luggage_rounded,
              title: "No tours assigned yet",
              message: "Assigned tours will show up here.",
            ),
          )
        else
          for (var i = 0; i < assigned.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: FadeInUp(
                index: i,
                child: AssignmentCard(
                  title:
                      assigned[i]["packageName"] ??
                      "Booking #${assigned[i]["bookingId"]}",
                  status: assigned[i]["bookingStatus"],
                  lines: [
                    "${assigned[i]["durationDays"] ?? 1} day(s)"
                        "${assigned[i]["vehicleName"] != null ? " · ${assigned[i]["vehicleName"]}" : ""}"
                        "${assigned[i]["guideName"] != null ? " · Guide: ${assigned[i]["guideName"]}" : ""}",
                  ],
                  earning: assigned[i]["estimatedEarning"] as num?,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsScreen(
                        bookingId: assigned[i]["bookingId"],
                      ),
                    ),
                  ),
                ),
              ),
            ),

        // ---------------- COMPLETED TOURS ----------------
        const SizedBox(height: Space.lg),
        const SectionHeader("Completed tours"),
        const SizedBox(height: Space.sm),
        if (completed.isEmpty)
          Text(
            "No completed tours yet.",
            style: context.text.bodyMedium!.copyWith(
              color: context.palette.textTertiary,
            ),
          )
        else
          for (final a in completed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: AssignmentCard(
                title: a["packageName"] ?? "Booking #${a["bookingId"]}",
                status: a["bookingStatus"],
                lines: [a["vehicleName"] ?? ""],
                earning: a["estimatedEarning"] as num?,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailsScreen(bookingId: a["bookingId"]),
                  ),
                ),
              ),
            ),
        const SizedBox(height: Space.xxl),
      ],
    );
  }
}
