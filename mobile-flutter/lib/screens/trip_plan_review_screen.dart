///trip planner review screen 
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/favorite_button.dart';
import '../widgets/ui/ui.dart';

class TripPlanReviewScreen extends StatefulWidget {
  final String objective;
  final Map<String, dynamic> aiResult;

  const TripPlanReviewScreen({
    super.key,
    required this.objective,
    required this.aiResult,
  });

  @override
  State<TripPlanReviewScreen> createState() => _TripPlanReviewScreenState();
}

/// One day of the trip. EACH day carries its own destinations and hotel,
/// so Day 1 and Day 2 can be completely different.
class _DayPlan {
  int dayNumber;
  final TextEditingController activitiesController;
  Set<int> destinationIds = {};
  int? hotelId;
  Map<String, dynamic>? weather;
  bool loadingWeather = false;

  _DayPlan(this.dayNumber, String initialActivities)
    : activitiesController = TextEditingController(text: initialActivities);
}

class _TripPlanReviewScreenState extends State<TripPlanReviewScreen> {
  final ApiService _apiService = ApiService();

  // A flat guide fee per day — the current schema doesn't store a guide price,
  // so this is shown to the tourist as an estimate only.
  static const double _guideFeePerDayLkr = 2500;

  List<dynamic> _allDestinations = [];
  List<dynamic> _allHotels = [];
  List<dynamic> _allGuides = [];
  List<dynamic> _allVehicles = [];

  int? _selectedGuideId;
  int? _selectedVehicleId;
  List<_DayPlan> _days = [];

  // The tourist's chosen trip start date. The AI's prompt/objective doesn't carry a date,
  // so this is always picked here on the review screen (calendar picker) before submitting.
  DateTime? _tripStartDate;

  bool _customizing = false;

  bool _isLoadingLists = true;
  bool _isRecalculating = false;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;

  double _hotelCost = 0;
  double _guideCost = 0;
  double _vehicleCost = 0;
  double get _totalCost => _hotelCost + _guideCost + _vehicleCost;

  @override
  void initState() {
    super.initState();
    _loadOptionsAndSeedFromAi();
  }

  @override
  void dispose() {
    for (final d in _days) {
      d.activitiesController.dispose();
    }
    super.dispose();
  }

  // ---------------- LOAD + SEED ----------------

  Future<void> _loadOptionsAndSeedFromAi() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLists = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.getDestinations(),
        _apiService.getHotels(),
        // Only offer guides/vehicles that are actually available — otherwise the tourist
        // could pick one that's already on another (Confirmed/OnGoing) trip.
        _apiService.getGuides(available: true),
        _apiService.getVehicles(available: true),
      ]);
      if (!mounted) return;
      _allDestinations = results[0];
      _allHotels = results[1];
      _allGuides = results[2];
      _allVehicles = results[3];

      final proposedItinerary =
          widget.aiResult["proposed_itinerary"] as List<dynamic>?;
      if (proposedItinerary != null && proposedItinerary.isNotEmpty) {
        _days = proposedItinerary.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          final dayNum = (d is Map && d["day"] is int)
              ? d["day"] as int
              : idx + 1;
          final activity = (d is Map) ? (d["activity"]?.toString() ?? "") : "";
          final day = _DayPlan(dayNum, activity);
          _seedDayDefaults(day, idx);
          return day;
        }).toList();
      } else {
        _days = List.generate(3, (idx) {
          final day = _DayPlan(idx + 1, "");
          _seedDayDefaults(day, idx);
          return day;
        });
      }

      // Trip-level guide/vehicle: try to honour what the AI matched, else fall back to first
      // available. Only honour the AI's match if that guide/vehicle is still in _allGuides/
      // _allVehicles (i.e. still available) — an AI suggestion made earlier could since have
      // been assigned to another trip.
      final matchedGuide = widget.aiResult["matched_guide"];
      final matchedGuideId = (matchedGuide is Map && matchedGuide["id"] != null)
          ? matchedGuide["id"] as int
          : null;
      if (matchedGuideId != null &&
          _allGuides.any((g) => g["id"] == matchedGuideId)) {
        _selectedGuideId = matchedGuideId;
      } else if (_allGuides.isNotEmpty) {
        _selectedGuideId = _allGuides.first["id"];
      } else {
        _selectedGuideId = null;
      }

      final matchedVehicle = widget.aiResult["matched_vehicle"];
      final matchedVehicleId =
          (matchedVehicle is Map && matchedVehicle["id"] != null)
          ? matchedVehicle["id"] as int
          : null;
      if (matchedVehicleId != null &&
          _allVehicles.any((v) => v["id"] == matchedVehicleId)) {
        _selectedVehicleId = matchedVehicleId;
      } else if (_allVehicles.isNotEmpty) {
        _selectedVehicleId = _allVehicles.first["id"];
      } else {
        _selectedVehicleId = null;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "We couldn't load the trip options.");
      }
    } finally {
      if (mounted) setState(() => _isLoadingLists = false);
    }
    if (_error == null) await _recalculateAll();
  }

  void _seedDayDefaults(_DayPlan day, int idx) {
    if (_allDestinations.isNotEmpty) {
      day.destinationIds.add(
        _allDestinations[idx % _allDestinations.length]["id"],
      );
    }
    if (_allHotels.isNotEmpty) {
      day.hotelId = _allHotels[idx % _allHotels.length]["id"];
    }
  }

  void _addDay() {
    setState(() {
      final day = _DayPlan(_days.length + 1, "");
      _seedDayDefaults(day, _days.length);
      _days.add(day);
    });
    _recalculateAll();
  }

  void _removeDay(int index) {
    setState(() => _days.removeAt(index).activitiesController.dispose());
    _recalculateAll();
  }

  // ---------------- WEATHER + COST ----------------

  Future<void> _recalculateAll() async {
    if (_days.isEmpty) return;
    setState(() => _isRecalculating = true);
    await Future.wait(
      List.generate(_days.length, (i) => _checkWeatherForDay(i)),
    );
    await _computeTotalCost();
    if (mounted) setState(() => _isRecalculating = false);
  }

  Future<void> _checkWeatherForDay(int dayIndex) async {
    if (dayIndex >= _days.length) return;
    final day = _days[dayIndex];
    if (day.destinationIds.isEmpty) return;

    final dest = _allDestinations.firstWhere(
      (d) =>
          day.destinationIds.contains(d["id"]) &&
          d["latitude"] != null &&
          d["longitude"] != null,
      orElse: () => null,
    );
    if (dest == null) return;

    setState(() => day.loadingWeather = true);
    try {
      final weather = await _apiService.getWeatherForDay(
        (dest["latitude"] as num).toDouble(),
        (dest["longitude"] as num).toDouble(),
        dayIndex, // day 0 = today, day 1 = tomorrow, etc.
      );
      if (mounted) setState(() => day.weather = weather);
    } finally {
      if (mounted) setState(() => day.loadingWeather = false);
    }
  }

  Future<void> _computeTotalCost() async {
    // Hotel: one night's charge for each day that has a hotel selected (estimate).
    double hotelTotal = 0;
    for (final day in _days) {
      if (day.hotelId == null) continue;
      final hotel = _allHotels.firstWhere(
        (h) => h["id"] == day.hotelId,
        orElse: () => null,
      );
      if (hotel != null && hotel["pricePerNight"] != null) {
        hotelTotal += (hotel["pricePerNight"] as num).toDouble();
      }
    }

    // Guide: flat estimated fee per day the trip runs.
    final guideTotal = _selectedGuideId != null
        ? _guideFeePerDayLkr * _days.length
        : 0.0;

    // Vehicle: distance-based charge along the whole route (day 1's stops, then day 2's, ...).
    double vehicleTotal = 0;
    if (_selectedVehicleId != null) {
      final points = <Map<String, double>>[];
      for (final day in _days) {
        for (final destId in day.destinationIds) {
          final dest = _allDestinations.firstWhere(
            (d) => d["id"] == destId,
            orElse: () => null,
          );
          if (dest != null &&
              dest["latitude"] != null &&
              dest["longitude"] != null) {
            points.add({
              "lat": (dest["latitude"] as num).toDouble(),
              "lon": (dest["longitude"] as num).toDouble(),
            });
          }
        }
      }
      for (int i = 0; i < points.length - 1; i++) {
        final quote = await _apiService.getDistanceQuote(
          vehicleId: _selectedVehicleId!,
          startLat: points[i]["lat"]!,
          startLon: points[i]["lon"]!,
          endLat: points[i + 1]["lat"]!,
          endLon: points[i + 1]["lon"]!,
        );
        if (quote != null && quote["totalVehicleCharge"] != null) {
          vehicleTotal += (quote["totalVehicleCharge"] as num).toDouble();
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _hotelCost = hotelTotal;
      _guideCost = guideTotal;
      _vehicleCost = vehicleTotal;
    });
  }

  bool get _anyBadWeather =>
      _days.any((d) => d.weather != null && d.weather!["isRainy"] == true);

  // ---------------- MAP ----------------

  Future<void> _viewRouteOnMap() async {
    final points = <dynamic>[];
    for (final day in _days) {
      for (final destId in day.destinationIds) {
        final dest = _allDestinations.firstWhere(
          (d) => d["id"] == destId,
          orElse: () => null,
        );
        if (dest != null &&
            dest["latitude"] != null &&
            dest["longitude"] != null) {
          points.add(dest);
        }
      }
    }

    if (points.isEmpty) {
      showToast(context, "Select at least one destination to view the route.");
      return;
    }

    final origin = "${points.first["latitude"]},${points.first["longitude"]}";
    final destination =
        "${points.last["latitude"]},${points.last["longitude"]}";
    final waypoints = points.length > 2
        ? points
              .sublist(1, points.length - 1)
              .map((d) => "${d["latitude"]},${d["longitude"]}")
              .join("|")
        : "";

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&origin=$origin"
      "&destination=$destination"
      "${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}"
      "&travelmode=driving",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showToast(context, "Could not open the map.", tone: Tone.danger);
    }
  }

  // ---------------- START DATE ----------------

  Future<void> _pickTripStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripStartDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _tripStartDate = picked;
        _error = null;
      });
    }
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submitToAdmin() async {
    final anyDestinations = _days.any((d) => d.destinationIds.isNotEmpty);
    if (!anyDestinations) {
      setState(
        () => _error =
            "Please select at least one destination for at least one day.",
      );
      return;
    }
    if (_tripStartDate == null) {
      setState(() => _error = "Please select a trip start date.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final allDestinationIds = _days
          .expand((d) => d.destinationIds)
          .toSet()
          .toList();
      final result = await _apiService.submitTripPlan(
        objective: widget.objective,
        destinationIds: allDestinationIds,
        hotelId: _days.isNotEmpty ? _days.first.hotelId : null,
        guideId: _selectedGuideId,
        vehicleId: _selectedVehicleId,
        estimatedTotalCost: _totalCost,
        plannedStartDate: _tripStartDate,
        days: _days
            .map(
              (d) => {
                "dayNumber": d.dayNumber,
                "activities": d.activitiesController.text,
                "notes": null,
                "destinationIds": d.destinationIds.toList(),
                "hotelId": d.hotelId,
              },
            )
            .toList(),
      );
      if (mounted) {
        setState(
          () => _successMessage =
              result["message"] ?? "Submitted for admin approval.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = "We couldn't submit your trip plan. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------- HELPERS ----------------

  String _dateLabel(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _guideLabel(int? id) {
    if (id == null) return "Not selected";
    final g = _allGuides.firstWhere((g) => g["id"] == id, orElse: () => null);
    if (g == null) return "Guide #$id";
    final name = g["name"] as String?;
    return "${(name != null && name.isNotEmpty) ? name : 'Guide #${g["id"]}'} — ${g["region"] ?? ''}";
  }

  String _vehicleLabel(int? id) {
    if (id == null) return "Not selected";
    final v = _allVehicles.firstWhere((v) => v["id"] == id, orElse: () => null);
    if (v == null) return "Vehicle #$id";
    final name = v["name"] as String?;
    final type = v["type"] ?? 'Vehicle';
    return "${(name != null && name.isNotEmpty) ? name : type} ($type, ${v["region"] ?? ''})";
  }

  String _hotelLabel(int? id) {
    if (id == null) return "Not selected";
    final h = _allHotels.firstWhere((h) => h["id"] == id, orElse: () => null);
    return h == null
        ? "Hotel #$id"
        : "${h["name"]} — LKR ${h["pricePerNight"]}/night";
  }

  // Resolves a relative "/uploads/..." path from the API into an absolute URL for Image.network.
  String? _absoluteUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith("http")) return relativePath;
    return "${ApiService.baseUrl.replaceAll('/api', '')}$relativePath";
  }

  String? _guidePhotoUrl(dynamic g) =>
      _absoluteUrl(g?["profilePictureUrl"] as String?);

  String? _vehicleCoverPhotoUrl(dynamic v) {
    final images = v?["images"] as List?;
    if (images == null || images.isEmpty) return null;
    final cover = images.firstWhere(
      (i) => i["isCover"] == true,
      orElse: () => images.first,
    );
    return _absoluteUrl(cover["imageUrl"] as String?);
  }

  String? _hotelPhotoUrl(dynamic h) => _absoluteUrl(h?["imageUrl"] as String?);

  // A reusable searchable picker sheet with photo + name + favorite heart, used for
  // choosing the Guide, Vehicle, and each day's Hotel while customizing the trip.
  Future<void> _openPicker({
    required String title,
    required List<dynamic> items,
    required String favoriteType,
    required IconData fallbackIcon,
    required String Function(dynamic) nameOf,
    required String Function(dynamic) subtitleOf,
    required String? Function(dynamic) photoOf,
    required void Function(dynamic) onSelect,
    int? selectedId,
  }) async {
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? items
                : items
                      .where(
                        (it) =>
                            nameOf(it).toLowerCase().contains(query) ||
                            subtitleOf(it).toLowerCase().contains(query),
                      )
                      .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetCtx).size.height * 0.8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.xl,
                        0,
                        Space.sm,
                        Space.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title, style: sheetCtx.text.titleLarge),
                          ),
                          IconButton(
                            tooltip: "Close",
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          hintText: "Search by name or region",
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Expanded(
                      child: visible.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: "No results",
                              message: "Try a different search.",
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(Space.lg),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: Space.sm),
                              itemBuilder: (ctx, i) {
                                final item = visible[i];
                                final selected = item["id"] == selectedId;
                                return AppCard(
                                  color: selected
                                      ? ctx.palette.primarySoft
                                      : null,
                                  padding: const EdgeInsets.all(Space.md),
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.pop(sheetCtx);
                                  },
                                  child: Row(
                                    children: [
                                      NetImage(
                                        photoOf(item),
                                        width: 56,
                                        height: 56,
                                        fallbackIcon: fallbackIcon,
                                      ),
                                      const SizedBox(width: Space.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nameOf(item),
                                              style: ctx.text.titleSmall,
                                            ),
                                            Text(
                                              subtitleOf(item),
                                              style: ctx.text.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: ctx.scheme.primary,
                                        ),
                                      FavoriteButton(
                                        itemType: favoriteType,
                                        itemId: item["id"],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_successMessage != null) return _buildSuccess();

    return Scaffold(
      appBar: AppBar(title: const Text("Review your plan")),
      body: StateView(
        loading: _isLoadingLists,
        error: _isLoadingLists
            ? null
            : (_allDestinations.isEmpty && _error != null ? _error : null),
        onRetry: _loadOptionsAndSeedFromAi,
        skeleton: const SkeletonList(count: 4, leading: false),
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            _buildAiSummaryCard(),
            const SizedBox(height: Space.lg),
            _buildTripStartDateCard(),
            const SizedBox(height: Space.lg),
            _buildWeatherCard(),
            const SizedBox(height: Space.lg),
            _buildCostCard(),
            const SizedBox(height: Space.lg),
            AppButton(
              label: "View route on map",
              icon: Icons.map_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _viewRouteOnMap,
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: _customizing
                  ? "Hide customisation"
                  : "Customise trip plan",
              icon: _customizing
                  ? Icons.expand_less_rounded
                  : Icons.tune_rounded,
              variant: AppButtonVariant.ghost,
              onPressed: () => setState(() => _customizing = !_customizing),
            ),
            AnimatedSize(
              duration: Motion.slow,
              curve: Motion.out,
              alignment: Alignment.topCenter,
              child: _customizing
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.md),
                      child: _buildCustomizeSection(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
      bottomNavigationBar: _isLoadingLists || _allDestinations.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  Space.md,
                ),
                decoration: BoxDecoration(
                  color: context.scheme.surface,
                  border: Border(
                    top: BorderSide(color: context.palette.border),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      InlineAlert(_error!),
                      const SizedBox(height: Space.md),
                    ],
                    Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Estimated total",
                              style: context.text.bodySmall,
                            ),
                            _isRecalculating
                                ? const Skeleton(width: 100, height: 22)
                                : Text(
                                    "LKR ${_totalCost.toStringAsFixed(0)}",
                                    style: context.text.titleLarge,
                                  ),
                          ],
                        ),
                        const SizedBox(width: Space.xl),
                        Expanded(
                          child: AppButton(
                            label: "Submit for approval",
                            icon: Icons.send_rounded,
                            loading: _isSubmitting,
                            onPressed: _submitToAdmin,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan submitted"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: Motion.slow,
                curve: Motion.spring,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: const IconTile(
                  Icons.check_rounded,
                  tone: Tone.success,
                  size: 96,
                ),
              ),
              const SizedBox(height: Space.xl),
              Text("Sent for approval", style: context.text.headlineSmall),
              const SizedBox(height: Space.sm),
              Text(
                _successMessage!,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: Space.xxl),
              AppButton(
                label: "Back to home",
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    final validationPassed = widget.aiResult["validation_passed"];
    final validationErrors = widget.aiResult["validation_errors"];

    // Just the trip plan itself, start to end — no AI working/reasoning steps shown here.
    return AppCard(
      color: context.palette.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 18,
                color: context.scheme.primary,
              ),
              const SizedBox(width: Space.sm),
              Text(
                "Suggested plan",
                style: context.text.labelMedium!.copyWith(
                  color: context.scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text('"${widget.objective}"', style: context.text.titleMedium),
          const SizedBox(height: Space.lg),
          for (var i = 0; i < _days.length; i++)
            _dayRow(_days[i], last: i == _days.length - 1),
          if (_selectedGuideId != null || _selectedVehicleId != null) ...[
            const Divider(height: Space.xxl),
            if (_selectedGuideId != null)
              InfoRow(
                "Guide",
                _guideLabel(_selectedGuideId),
                icon: Icons.person_rounded,
              ),
            if (_selectedVehicleId != null)
              InfoRow(
                "Vehicle",
                _vehicleLabel(_selectedVehicleId),
                icon: Icons.directions_car_rounded,
              ),
          ],
          if (validationPassed == false) ...[
            const SizedBox(height: Space.md),
            InlineAlert(
              "The AI flagged some issues with this plan"
              "${validationErrors is List && validationErrors.isNotEmpty ? ':\n${validationErrors.join('\n')}' : '.'}",
              tone: Tone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(_DayPlan d, {required bool last}) {
    final names = _allDestinations
        .where((dest) => d.destinationIds.contains(dest["id"]))
        .map((dest) => dest["name"])
        .join(", ");
    final hotelName = _allHotels.firstWhere(
      (h) => h["id"] == d.hotelId,
      orElse: () => null,
    )?["name"];
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
                    color: context.scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${d.dayNumber}",
                    style: context.text.labelMedium!.copyWith(
                      color: context.scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: context.scheme.primary.withValues(alpha: 0.25),
                    ),
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
                  Text(
                    names.isEmpty ? "No destination selected" : names,
                    style: context.text.titleSmall,
                  ),
                  if (hotelName != null)
                    Text("Stay: $hotelName", style: context.text.bodySmall),
                  if (d.activitiesController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        d.activitiesController.text,
                        style: context.text.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lets the tourist pick when the trip should start. Required before submitting, since
  // the AI's objective/prompt text never carries an actual date.
  Widget _buildTripStartDateCard() {
    final hasDate = _tripStartDate != null;
    return AppCard(
      onTap: _pickTripStartDate,
      child: Row(
        children: [
          IconTile(
            Icons.calendar_month_rounded,
            tone: hasDate ? Tone.success : Tone.warning,
            size: 44,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Trip start date", style: context.text.titleSmall),
                Text(
                  hasDate
                      ? _dateLabel(_tripStartDate!)
                      : "Required — tap to choose",
                  style: context.text.bodyMedium!.copyWith(
                    color: hasDate
                        ? context.scheme.onSurface
                        : context.palette.warning,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.palette.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Weather forecast", style: context.text.titleMedium),
          const SizedBox(height: Space.md),
          if (_anyBadWeather) ...[
            const InlineAlert(
              "Rain is expected on one or more days. Consider indoor alternatives or a schedule change.",
              tone: Tone.warning,
              icon: Icons.water_drop_rounded,
            ),
            const SizedBox(height: Space.md),
          ],
          for (final day in _days)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      "Day ${day.dayNumber}",
                      style: context.text.bodyMedium!.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: day.loadingWeather
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Skeleton(width: 120, height: 14),
                          )
                        : (day.weather != null &&
                              day.weather!["available"] == true)
                        ? Row(
                            children: [
                              Icon(
                                day.weather!["isRainy"] == true
                                    ? Icons.water_drop_rounded
                                    : Icons.wb_sunny_rounded,
                                size: 18,
                                color: day.weather!["isRainy"] == true
                                    ? context.palette.info
                                    : context.palette.warning,
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(
                                  "${(day.weather!["temperature"] as num).toStringAsFixed(0)}°C · ${day.weather!["description"]}",
                                  style: context.text.bodyMedium!.copyWith(
                                    fontWeight: day.weather!["isRainy"] == true
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            day.weather?["message"] ??
                                "Weather unavailable for this day.",
                            style: context.text.bodySmall,
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCostCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Estimated trip cost", style: context.text.titleMedium),
          const SizedBox(height: Space.md),
          if (_isRecalculating)
            const Column(
              children: [
                Skeleton(height: 16),
                SizedBox(height: Space.sm),
                Skeleton(height: 16),
                SizedBox(height: Space.sm),
                Skeleton(height: 16),
              ],
            )
          else ...[
            _costRow("Hotel(s)", _hotelCost),
            _costRow("Guide (estimated)", _guideCost),
            _costRow("Vehicle (distance-based)", _vehicleCost),
            const Divider(height: Space.xl),
            _costRow("Total", _totalCost, bold: true),
          ],
        ],
      ),
    );
  }

  Widget _costRow(String label, double value, {bool bold = false}) {
    final style = bold ? context.text.titleMedium : context.text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? style
                : style!.copyWith(color: context.palette.textSecondary),
          ),
          Text("LKR ${value.toStringAsFixed(2)}", style: style),
        ],
      ),
    );
  }

  // A tappable "current selection" row (photo + label) that opens the picker sheet —
  // used in place of a plain dropdown so the guide/vehicle/hotel's photo is visible.
  Widget _buildPickerTile({
    required String title,
    required String? photoUrl,
    required IconData fallbackIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          NetImage(photoUrl, width: 52, height: 52, fallbackIcon: fallbackIcon),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.bodySmall),
                Text(
                  label,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.unfold_more_rounded, color: context.palette.textTertiary),
        ],
      ),
    );
  }

  Widget _buildCustomizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader("Vehicle & guide"),
        const SizedBox(height: Space.sm),
        _buildPickerTile(
          title: "Vehicle",
          photoUrl: _selectedVehicleId != null
              ? _vehicleCoverPhotoUrl(
                  _allVehicles.firstWhere(
                    (v) => v["id"] == _selectedVehicleId,
                    orElse: () => null,
                  ),
                )
              : null,
          fallbackIcon: Icons.directions_car_rounded,
          label: _vehicleLabel(_selectedVehicleId),
          onTap: () => _openPicker(
            title: "Select a vehicle",
            items: _allVehicles,
            favoriteType: "Vehicle",
            fallbackIcon: Icons.directions_car_rounded,
            selectedId: _selectedVehicleId,
            nameOf: (v) => (v["name"] as String?)?.isNotEmpty == true
                ? v["name"]
                : v["type"] ?? "Vehicle",
            subtitleOf: (v) =>
                "${v["type"]} · ${v["region"] ?? ''} · LKR ${v["pricePerKm"] ?? 0}/km",
            photoOf: _vehicleCoverPhotoUrl,
            onSelect: (v) {
              setState(() => _selectedVehicleId = v["id"]);
              _recalculateAll();
            },
          ),
        ),
        const SizedBox(height: Space.sm),
        _buildPickerTile(
          title: "Guide",
          photoUrl: _selectedGuideId != null
              ? _guidePhotoUrl(
                  _allGuides.firstWhere(
                    (g) => g["id"] == _selectedGuideId,
                    orElse: () => null,
                  ),
                )
              : null,
          fallbackIcon: Icons.person_rounded,
          label: _guideLabel(_selectedGuideId),
          onTap: () => _openPicker(
            title: "Select a guide",
            items: _allGuides,
            favoriteType: "Guide",
            fallbackIcon: Icons.person_rounded,
            selectedId: _selectedGuideId,
            nameOf: (g) => (g["name"] as String?)?.isNotEmpty == true
                ? g["name"]
                : "Guide #${g["id"]}",
            subtitleOf: (g) =>
                "${g["region"] ?? ''} · ${g["languages"] ?? ''} · ★ ${((g["rating"] as num?) ?? 0).toStringAsFixed(1)}",
            photoOf: _guidePhotoUrl,
            onSelect: (g) {
              setState(() => _selectedGuideId = g["id"]);
              _recalculateAll();
            },
          ),
        ),
        const SizedBox(height: Space.xl),
        SectionHeader("Day by day", actionLabel: "Add day", onAction: _addDay),
        const SizedBox(height: Space.sm),
        for (var index = 0; index < _days.length; index++)
          _buildDayEditor(index),
      ],
    );
  }

  Widget _buildDayEditor(int index) {
    final day = _days[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Day ${index + 1}",
                    style: context.text.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: "Remove day ${index + 1}",
                  icon: const Icon(Icons.delete_outline_rounded, size: 22),
                  onPressed: _days.length > 1 ? () => _removeDay(index) : null,
                ),
              ],
            ),
            AppTextField(
              label: "Activities",
              controller: day.activitiesController,
              hint: "What would you like to do this day?",
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.lg),
            Text(
              "Destinations",
              style: context.text.labelMedium!.copyWith(
                fontSize: 13.5,
                color: context.scheme.onSurface,
              ),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final d in _allDestinations)
                  FilterChip(
                    label: Text(d["name"] ?? ""),
                    selected: day.destinationIds.contains(d["id"]),
                    showCheckmark: false,
                    avatar: day.destinationIds.contains(d["id"])
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: context.scheme.primary,
                          )
                        : null,
                    selectedColor: context.palette.primarySoft,
                    side: BorderSide(
                      color: day.destinationIds.contains(d["id"])
                          ? context.scheme.primary
                          : context.palette.border,
                    ),
                    onSelected: (checked) {
                      setState(() {
                        if (checked) {
                          day.destinationIds.add(d["id"]);
                        } else {
                          day.destinationIds.remove(d["id"]);
                        }
                      });
                      _recalculateAll();
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            _buildPickerTile(
              title: "Hotel",
              photoUrl: day.hotelId != null
                  ? _hotelPhotoUrl(
                      _allHotels.firstWhere(
                        (h) => h["id"] == day.hotelId,
                        orElse: () => null,
                      ),
                    )
                  : null,
              fallbackIcon: Icons.hotel_rounded,
              label: _hotelLabel(day.hotelId),
              onTap: () => _openPicker(
                title: "Select a hotel",
                items: _allHotels,
                favoriteType: "Hotel",
                fallbackIcon: Icons.hotel_rounded,
                selectedId: day.hotelId,
                nameOf: (h) => h["name"] ?? "Hotel",
                subtitleOf: (h) =>
                    "${h["region"] ?? ''} · LKR ${h["pricePerNight"] ?? 0}/night · ${((h["starRating"] as num?)?.toInt() ?? 0)}★",
                photoOf: _hotelPhotoUrl,
                onSelect: (h) {
                  setState(() => day.hotelId = h["id"]);
                  _recalculateAll();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
