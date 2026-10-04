////guide home  screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/ui/ui.dart';
import 'chat_screen.dart';
import 'booking_details_screen.dart';

/// Guide dashboard (the second tab for Guide accounts).
class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({super.key});

  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>?
  _guideProfile; // includes id, isAvailable, rating, region
  List<dynamic> _assignments = [];
  Map<String, dynamic>? _earnings;
  Map<int, int> _unreadChatCounts = {};
  bool _isUpdatingAvailability = false;
  int? _busyAssignmentId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      // Pick up a fresh verification status too, so the "pending review" banner clears
      // as soon as an Admin has approved — no separate manual check needed.
      await context.read<AuthProvider>().refreshVerificationStatus();
      final profile = await _apiService.getMyGuideProfile();
      if (profile == null) {
        if (mounted) {
          setState(
            () => _error = "No guide profile is linked to this account yet. Contact the admin.",
          );
        }
        return;
      }
      final results = await Future.wait([
        _apiService.getMyAssignments(),
        _apiService.getGuideEarnings(profile["id"]),
        _apiService.getChatUnreadCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _guideProfile = profile;
        _assignments = results[0] as List<dynamic>;
        _earnings = results[1] as Map<String, dynamic>?;
        _unreadChatCounts = results[2] as Map<int, int>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load your dashboard.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrip(int assignmentId) async {
    final ok = await confirmSheet(
      context,
      title: "Start this tour?",
      message: "The booking will be marked On Going and the tourist will be notified.",
      confirmLabel: "Start tour",
    );
    if (!ok) return;
    setState(() => _busyAssignmentId = assignmentId);
    try {
      await _apiService.startTrip(assignmentId);
      if (mounted) {
        showToast(
          context,
          "Tour started — status is now On Going.",
          tone: Tone.success,
        );
      }
      await _loadAll(silent: true);
    } catch (e) {
      if (mounted) {
        showToast(context, "Failed to start tour.", tone: Tone.danger);
      }
    } finally {
      if (mounted) setState(() => _busyAssignmentId = null);
    }
  }

  Future<void> _endTrip(int assignmentId) async {
    final ok = await confirmSheet(
      context,
      title: "End this tour?",
      message: "This marks the tour as completed and lets the tourist leave a review.",
      confirmLabel: "End tour",
    );
    if (!ok) return;
    setState(() => _busyAssignmentId = assignmentId);
    try {
      await _apiService.endTrip(assignmentId);
      if (mounted) showToast(context, "Tour ended.", tone: Tone.success);
      await _loadAll(silent: true);
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e.toString().replaceFirst("Exception: ", ""),
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busyAssignmentId = null);
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
        showToast(
          context,
          e.toString().replaceFirst("Exception: ", ""),
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
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
          // 🔥 Fix: `_buildBody()` does `_guideProfile!` — but a widget passed as an
          // argument (like `child:` here) is evaluated IMMEDIATELY, regardless of
          // whether StateView ends up showing it or the loading/error view instead.
          // So `_buildBody()` used to run on every single build, including the very
          // first one (before `_loadAll()` finishes and `_guideProfile` is still
          // null) — crashing with "Null check operator used on a null value" before
          // the loading skeleton ever had a chance to show. Only call it once the
          // profile has actually loaded.
          child: _guideProfile != null
              ? _buildBody()
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final auth = context.watch<AuthProvider>();
    final guide = _guideProfile!;
    final rating = (guide["rating"] as num?)?.toDouble() ?? 0;
    // "Completed" was renamed to "Ended" (Booking.cs BookingStatus enum).
    final assigned = _assignments
        .where((a) => a["bookingStatus"] != "Ended")
        .toList();
    final completed = _assignments
        .where((a) => a["bookingStatus"] == "Ended")
        .toList();
    final available = guide["isAvailable"] == true;

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        if (!auth.isVerified) ...[
          const VerificationBanner(what: "you're not"),
          const SizedBox(height: Space.lg),
        ],
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: "Rating · ${guide["region"] ?? ""}",
                value: rating.toStringAsFixed(1),
                icon: Icons.star_rounded,
                tone: Tone.warning,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: "Completed tours",
                value:
                    "${_earnings?["totalCompletedTrips"] ?? completed.length}",
                icon: Icons.flag_rounded,
                tone: Tone.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.sm,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Available for assignments",
              style: context.text.titleSmall,
            ),
            subtitle: Text(
              available
                  ? "You're visible to the matching system."
                  : "You're hidden from new tours.",
            ),
            value: available,
            onChanged: _isUpdatingAvailability ? null : _toggleAvailability,
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
                "Estimated at LKR ${(_earnings!["flatFeePerDay"] as num).toStringAsFixed(0)}/day guided — a flat rate estimate.",
          ),
        if (_earnings != null && (_earnings!["trips"] as List).isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          for (final t in (_earnings!["trips"] as List))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.md,
                ),
                child: Row(
                  children: [
                    const IconTile(
                      Icons.check_rounded,
                      tone: Tone.success,
                      size: 36,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t["packageName"] ?? "Booking #${t["bookingId"]}",
                            style: context.text.titleSmall,
                          ),
                          Text(
                            "${t["durationDays"]} day(s) · ${(t["completedAt"] ?? '').toString().substring(0, 10)}",
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "LKR ${(t["estimatedEarning"] as num).toStringAsFixed(2)}",
                      style: context.text.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
        ],

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
              message:
                  "Check back once the admin approves a plan that matches you.",
            ),
          )
        else
          for (var i = 0; i < assigned.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: FadeInUp(index: i, child: _assignedCard(assigned[i])),
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
                lines: [
                  if (a["vehicleName"] != null) "Vehicle: ${a["vehicleName"]}",
                ],
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

  Widget _assignedCard(dynamic a) {
    final unread = _unreadChatCounts[a["bookingId"]] ?? 0;
    final status = a["bookingStatus"];
    final canEnd = a["canEndTrip"] != false;
    final busy = _busyAssignmentId == a["assignmentId"];
    return AssignmentCard(
      title: a["packageName"] ?? "Booking #${a["bookingId"]}",
      status: status,
      lines: [
        "${a["durationDays"] ?? 1} day(s)${a["vehicleName"] != null ? " · Vehicle: ${a["vehicleName"]}" : ""}",
      ],
      earning: a["estimatedEarning"] as num?,
      footnote: status == "OnGoing" && !canEnd
          ? "You can end this tour on or after ${a["earliestEndDate"]}."
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(bookingId: a["bookingId"]),
        ),
      ),
      actions: [
        if (status == "Confirmed" && a["isPaid"] != true)
          const StatusBadge(
            "Awaiting tourist payment",
            tone: Tone.warning,
            icon: Icons.schedule_rounded,
          ),
        if (status == "Confirmed" && a["isPaid"] == true)
          AppButton(
            label: "Start tour",
            icon: Icons.play_arrow_rounded,
            expand: false,
            compact: true,
            variant: AppButtonVariant.success,
            loading: busy,
            onPressed: () => _startTrip(a["assignmentId"]),
          ),
        if (status == "OnGoing")
          // Still allow the tap even when not yet allowed by date, so the guide sees the
          // exact reason from the server rather than a silently-disabled button.
          AppButton(
            label: "End tour",
            icon: Icons.stop_rounded,
            expand: false,
            compact: true,
            variant: canEnd
                ? AppButtonVariant.danger
                : AppButtonVariant.secondary,
            loading: busy,
            onPressed: () => _endTrip(a["assignmentId"]),
          ),
        AppButton(
          label: unread > 0 ? "Chat ($unread)" : "Chat",
          icon: Icons.chat_bubble_outline_rounded,
          expand: false,
          compact: true,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                bookingId: a["bookingId"],
                title: a["packageName"] ?? "Chat",
              ),
            ),
          ).then((_) => _loadAll(silent: true)),
        ),
      ],
    );
  }
}
