import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';
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
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _error = null;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_startDate == null) {
      setState(() => _error = "Please select a tour start date.");
      return;
    }
    setState(() {
      _isBooking = true;
      _error = null;
    });
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
      if (mounted) setState(() => _error = "Booking failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isBooking = false);
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
        showToast(context, "This package has no mapped destinations yet.");
      }
      return;
    }
    final origin = "${points.first["latitude"]},${points.first["longitude"]}";
    final destination =
        "${points.last["latitude"]},${points.last["longitude"]}";
    final waypoints = points.length > 2
        ? points
              .sublist(1, points.length - 1)
              .map((p) => "${p["latitude"]},${p["longitude"]}")
              .join("|")
        : "";
    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination"
      "${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}&travelmode=driving",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _dateLabel(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final total = (pkg["basePrice"] ?? 0) * _groupSize;
    final destinations = (pkg["destinations"] as List?) ?? [];
    final hotels = (pkg["hotels"] as List?) ?? [];
    final suggestedGuideName = pkg["suggestedGuideName"];
    final suggestedVehicleName = pkg["suggestedVehicleName"];
    final p = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                0,
              ),
              child: Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: "Back",
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: FavoriteButton(
                      itemType: "Package",
                      itemId: pkg["id"],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (resolveImageUrl(pkg["imageUrl"]) != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.sm,
                        Space.lg,
                        Space.lg,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.xl),
                        child: NetImage(
                          pkg["imageUrl"],
                          height: 190,
                          radius: Radii.xl,
                          fallbackIcon: Icons.luggage_rounded,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 190,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1),
                          duration: Motion.slow * 2,
                          curve: Motion.spring,
                          builder: (_, v, child) => Transform.scale(
                            scale: v,
                            child: Opacity(
                              opacity: v.clamp(0, 1),
                              child: child,
                            ),
                          ),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.luggage_rounded,
                              size: 76,
                              color: context.scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(Space.xl),
                        decoration: BoxDecoration(
                          color: context.scheme.surface,
                          borderRadius: BorderRadius.circular(Radii.xl),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pkg["name"] ?? "",
                                    style: context.text.headlineSmall!.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: Space.xs),
                                  Text(
                                    "${pkg["durationDays"]} days · up to $_maxPeople people",
                                    style: context.text.bodySmall,
                                  ),
                                  const SizedBox(height: Space.lg),
                                  AnimatedSwitcher(
                                    duration: Motion.fast,
                                    child: Text(
                                      "LKR $total",
                                      key: ValueKey(total),
                                      style: context.text.headlineSmall!
                                          .copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    "LKR ${pkg["basePrice"]} × $_groupSize",
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _VerticalStepper(
                              value: _groupSize,
                              max: _maxPeople,
                              onChanged: (v) => setState(() => _groupSize = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: p.background,
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.xl,
                      Space.lg,
                      Space.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((pkg["description"] ?? "")
                            .toString()
                            .isNotEmpty) ...[
                          Text(
                            pkg["description"],
                            style: context.text.bodyLarge!.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: Space.xl),
                        ],
                        AppCard(
                          onTap: _pickStartDate,
                          child: Row(
                            children: [
                              const IconTile(
                                Icons.calendar_month_rounded,
                                size: 44,
                              ),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Tour start date",
                                      style: context.text.titleSmall,
                                    ),
                                    Text(
                                      _startDate == null
                                          ? "Select a date"
                                          : _dateLabel(_startDate!),
                                      style: context.text.bodyMedium!.copyWith(
                                        color: _startDate == null
                                            ? p.textTertiary
                                            : context.scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: p.textTertiary,
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: Space.md),
                          InlineAlert(_error!),
                        ],
                        if (destinations.isNotEmpty) ...[
                          const SizedBox(height: Space.xxl),
                          SectionHeader(
                            "Route",
                            actionLabel: "Open in Maps",
                            onAction: _viewRouteOnMap,
                          ),
                          const SizedBox(height: Space.sm),
                          AppCard(
                            child: Column(
                              children: [
                                for (var i = 0; i < destinations.length; i++)
                                  _RouteStop(
                                    day: "${destinations[i]["dayNumber"]}",
                                    title: "${destinations[i]["name"]}",
                                    subtitle: "${destinations[i]["region"]}",
                                    last: i == destinations.length - 1,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (hotels.isNotEmpty) ...[
                          const SizedBox(height: Space.xxl),
                          const SectionHeader("Where you'll stay"),
                          const SizedBox(height: Space.sm),
                          for (final h in hotels)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    const IconTile(
                                      Icons.hotel_rounded,
                                      tone: Tone.success,
                                    ),
                                    const SizedBox(width: Space.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${h["name"]}",
                                            style: context.text.titleSmall,
                                          ),
                                          Text(
                                            "${h["region"]} · LKR ${h["pricePerNight"]}/night",
                                            style: context.text.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (suggestedGuideName != null ||
                            suggestedVehicleName != null) ...[
                          const SizedBox(height: Space.xxl),
                          const SectionHeader("Suggested guide & vehicle"),
                          const SizedBox(height: Space.sm),
                          AppCard(
                            child: Column(
                              children: [
                                if (suggestedGuideName != null)
                                  InfoRow(
                                    "Guide",
                                    "$suggestedGuideName",
                                    icon: Icons.person_rounded,
                                  ),
                                if (suggestedVehicleName != null)
                                  InfoRow(
                                    "Vehicle",
                                    "$suggestedVehicleName",
                                    icon: Icons.directions_car_rounded,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: p.background,
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.md,
          ),
          child: SlideToConfirm(
            label: "Slide to book",
            loading: _isBooking,
            onConfirmed: _confirmBooking,
          ),
        ),
      ),
    );
  }
}

/// Black vertical + / count / − pill, as in the reference's quantity control.
class _VerticalStepper extends StatelessWidget {
  const _VerticalStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, bool on, VoidCallback f) => Semantics(
      button: true,
      enabled: on,
      label: tip,
      excludeSemantics: true,
      child: PressScale(
        enabled: on,
        onTap: on
            ? () {
                HapticFeedback.selectionClick();
                f();
              }
            : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: on ? AppColors.ink : context.palette.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: on ? Colors.white : context.palette.textTertiary,
          ),
        ),
      ),
    );
    return Semantics(
      label: "Group size: $value",
      child: Column(
        children: [
          btn(
            Icons.add_rounded,
            "Increase group size",
            value < max,
            () => onChanged(value + 1),
          ),
          SizedBox(
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: a,
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: Text(
                  "$value",
                  key: ValueKey(value),
                  style: context.text.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          btn(
            Icons.remove_rounded,
            "Decrease group size",
            value > 1,
            () => onChanged(value - 1),
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.last,
  });
  final String day;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    day,
                    style: context.text.labelMedium!.copyWith(
                      color: context.scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: context.palette.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Day $day · $title", style: context.text.titleSmall),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
