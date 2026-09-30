import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/favorite_button.dart';

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

/// One day of the trip. Unlike the old version, EACH day now carries its own
/// destinations and hotel, so Day 1 and Day 2 can be completely different.
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

  // ---------------- LOAD + SEED ----------------

  Future<void> _loadOptionsAndSeedFromAi() async {
    if (!mounted) return;
    setState(() => _isLoadingLists = true);
    try {
      final results = await Future.wait([
        _apiService.getDestinations(),
        _apiService.getHotels(),
        // 🔥 Only offer guides/vehicles that are actually available — otherwise the tourist
        // could pick one that's already on another (Confirmed/OnGoing) trip.
        _apiService.getGuides(available: true),
        _apiService.getVehicles(available: true),
      ]);
      if (!mounted) return;
      _allDestinations = results[0];
      _allHotels = results[1];
      _allGuides = results[2];
      _allVehicles = results[3];

      final proposedItinerary = widget.aiResult["proposed_itinerary"] as List<dynamic>?;
      if (proposedItinerary != null && proposedItinerary.isNotEmpty) {
        _days = proposedItinerary.asMap().entries.map((entry) {
          final idx = entry.key;
          final d = entry.value;
          final dayNum = (d is Map && d["day"] is int) ? d["day"] as int : idx + 1;
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
      final matchedGuideId = (matchedGuide is Map && matchedGuide["id"] != null) ? matchedGuide["id"] as int : null;
      if (matchedGuideId != null && _allGuides.any((g) => g["id"] == matchedGuideId)) {
        _selectedGuideId = matchedGuideId;
      } else if (_allGuides.isNotEmpty) {
        _selectedGuideId = _allGuides.first["id"];
      } else {
        _selectedGuideId = null;
      }

      final matchedVehicle = widget.aiResult["matched_vehicle"];
      final matchedVehicleId = (matchedVehicle is Map && matchedVehicle["id"] != null) ? matchedVehicle["id"] as int : null;
      if (matchedVehicleId != null && _allVehicles.any((v) => v["id"] == matchedVehicleId)) {
        _selectedVehicleId = matchedVehicleId;
      } else if (_allVehicles.isNotEmpty) {
        _selectedVehicleId = _allVehicles.first["id"];
      } else {
        _selectedVehicleId = null;
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Failed to load options.");
    } finally {
      if (mounted) setState(() => _isLoadingLists = false);
    }
    await _recalculateAll();
  }

  void _seedDayDefaults(_DayPlan day, int idx) {
    if (_allDestinations.isNotEmpty) {
      day.destinationIds.add(_allDestinations[idx % _allDestinations.length]["id"]);
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
    setState(() => _days.removeAt(index));
    _recalculateAll();
  }

  // ---------------- WEATHER + COST ----------------

  Future<void> _recalculateAll() async {
    if (_days.isEmpty) return;
    setState(() => _isRecalculating = true);
    await Future.wait(List.generate(_days.length, (i) => _checkWeatherForDay(i)));
    await _computeTotalCost();
    if (mounted) setState(() => _isRecalculating = false);
  }

  Future<void> _checkWeatherForDay(int dayIndex) async {
    final day = _days[dayIndex];
    if (day.destinationIds.isEmpty) return;

    final dest = _allDestinations.firstWhere(
      (d) => day.destinationIds.contains(d["id"]) && d["latitude"] != null && d["longitude"] != null,
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
      final hotel = _allHotels.firstWhere((h) => h["id"] == day.hotelId, orElse: () => null);
      if (hotel != null && hotel["pricePerNight"] != null) {
        hotelTotal += (hotel["pricePerNight"] as num).toDouble();
      }
    }

    // Guide: flat estimated fee per day the trip runs.
    final guideTotal = _selectedGuideId != null ? _guideFeePerDayLkr * _days.length : 0.0;

    // Vehicle: distance-based charge along the whole route (day 1's stops, then day 2's, ...).
    double vehicleTotal = 0;
    if (_selectedVehicleId != null) {
      final points = <Map<String, double>>[];
      for (final day in _days) {
        for (final destId in day.destinationIds) {
          final dest = _allDestinations.firstWhere((d) => d["id"] == destId, orElse: () => null);
          if (dest != null && dest["latitude"] != null && dest["longitude"] != null) {
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

  bool get _anyBadWeather => _days.any((d) => d.weather != null && d.weather!["isRainy"] == true);

  // ---------------- MAP ----------------

  Future<void> _viewRouteOnMap() async {
    final points = <dynamic>[];
    for (final day in _days) {
      for (final destId in day.destinationIds) {
        final dest = _allDestinations.firstWhere((d) => d["id"] == destId, orElse: () => null);
        if (dest != null && dest["latitude"] != null && dest["longitude"] != null) {
          points.add(dest);
        }
      }
    }

    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one destination to view the route.")),
      );
      return;
    }

    final origin = "${points.first["latitude"]},${points.first["longitude"]}";
    final destination = "${points.last["latitude"]},${points.last["longitude"]}";
    final waypoints = points.length > 2
        ? points.sublist(1, points.length - 1).map((d) => "${d["latitude"]},${d["longitude"]}").join("|")
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the map.")),
        );
      }
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
      setState(() => _tripStartDate = picked);
    }
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submitToAdmin() async {
    final anyDestinations = _days.any((d) => d.destinationIds.isNotEmpty);
    if (!anyDestinations) {
      setState(() => _error = "Please select at least one destination for at least one day.");
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
      final allDestinationIds = _days.expand((d) => d.destinationIds).toSet().toList();
      final result = await _apiService.submitTripPlan(
        objective: widget.objective,
        destinationIds: allDestinationIds,
        hotelId: _days.isNotEmpty ? _days.first.hotelId : null,
        guideId: _selectedGuideId,
        vehicleId: _selectedVehicleId,
        estimatedTotalCost: _totalCost,
        plannedStartDate: _tripStartDate,
        days: _days
            .map((d) => {
                  "dayNumber": d.dayNumber,
                  "activities": d.activitiesController.text,
                  "notes": null,
                  "destinationIds": d.destinationIds.toList(),
                  "hotelId": d.hotelId,
                })
            .toList(),
      );
      setState(() => _successMessage = result["message"] ?? "Submitted for admin approval.");
    } catch (e) {
      setState(() => _error = "Failed to submit trip plan. Please try again.");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLists) {
      return Scaffold(
        appBar: AppBar(title: const Text("Review Your Trip Plan")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_successMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Review Your Trip Plan")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 72),
                const SizedBox(height: 16),
                Text(_successMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text("Back to Home"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Review Your Trip Plan")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAiSummaryCard(),
          const SizedBox(height: 16),
          _buildTripStartDateCard(),
          const SizedBox(height: 16),
          _buildWeatherAndCostCard(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text("View Route on Map"),
            onPressed: _viewRouteOnMap,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(_customizing ? Icons.expand_less : Icons.tune),
              label: Text(_customizing ? "Hide Customize Options" : "Customize Trip Plan"),
              onPressed: () => setState(() => _customizing = !_customizing),
            ),
          ),
          if (_customizing) ...[
            const SizedBox(height: 16),
            _buildCustomizeSection(),
          ],
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: Text(_isSubmitting ? "Submitting..." : "Submit to Admin for Approval"),
              onPressed: _isSubmitting ? null : _submitToAdmin,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    final validationPassed = widget.aiResult["validation_passed"];
    final validationErrors = widget.aiResult["validation_errors"];
    final matchedGuide = widget.aiResult["matched_guide"];
    final matchedVehicle = widget.aiResult["matched_vehicle"];

    // Just the trip plan itself, start to end — no AI working/reasoning steps shown here.
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Trip Plan for: "${widget.objective}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Text("Day-by-day:", style: TextStyle(fontWeight: FontWeight.w600)),
            ..._days.map((d) {
              final names = _allDestinations
                  .where((dest) => d.destinationIds.contains(dest["id"]))
                  .map((dest) => dest["name"])
                  .join(", ");
              final hotelName = _allHotels
                  .firstWhere((h) => h["id"] == d.hotelId, orElse: () => null)?["name"];
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  "Day ${d.dayNumber}: ${names.isEmpty ? 'No destination selected' : names}"
                  "${hotelName != null ? ' — staying at $hotelName' : ''}"
                  "${d.activitiesController.text.isNotEmpty ? '\n   ${d.activitiesController.text}' : ''}",
                ),
              );
            }),
            if (matchedGuide != null || _selectedGuideId != null) ...[
              const SizedBox(height: 8),
              Text("Guide: ${_guideLabel(_selectedGuideId)}"),
            ],
            if (matchedVehicle != null || _selectedVehicleId != null)
              Text("Vehicle: ${_vehicleLabel(_selectedVehicleId)}"),
            if (validationPassed == false) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "⚠️ The AI flagged some issues with this plan"
                  "${validationErrors is List && validationErrors.isNotEmpty ? ':\n${validationErrors.join('\n')}' : '.'}",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Lets the tourist pick when the trip should start. Required before submitting, since
  // the AI's objective/prompt text never carries an actual date.
  Widget _buildTripStartDateCard() {
    final label = _tripStartDate == null
        ? "Not selected"
        : "${_tripStartDate!.year}-${_tripStartDate!.month.toString().padLeft(2, '0')}-${_tripStartDate!.day.toString().padLeft(2, '0')}";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Trip Start Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildPickerTile(
              photoUrl: null,
              fallbackIcon: Icons.calendar_month,
              label: label,
              onTap: _pickTripStartDate,
            ),
          ],
        ),
      ),
    );
  }

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

  // Resolves a relative "/uploads/..." path from the API into an absolute URL for Image.network.
  String? _absoluteUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith("http")) return relativePath;
    return "${ApiService.baseUrl.replaceAll('/api', '')}$relativePath";
  }

  String? _guidePhotoUrl(dynamic g) => _absoluteUrl(g["profilePictureUrl"] as String?);

  String? _vehicleCoverPhotoUrl(dynamic v) {
    final images = v["images"] as List?;
    if (images == null || images.isEmpty) return null;
    final cover = images.firstWhere((i) => i["isCover"] == true, orElse: () => images.first);
    return _absoluteUrl(cover["imageUrl"] as String?);
  }

  String? _hotelPhotoUrl(dynamic h) => _absoluteUrl(h["imageUrl"] as String?);

  // A reusable searchable picker sheet with photo + name + favorite star, used for
  // choosing the Guide, Vehicle, and each day's Hotel while customizing the trip.
  Future<void> _openPicker({
    required String title,
    required List<dynamic> items,
    required String favoriteType,
    required String Function(dynamic) nameOf,
    required String Function(dynamic) subtitleOf,
    required String? Function(dynamic) photoOf,
    required void Function(dynamic) onSelect,
  }) async {
    final searchController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? items
                : items
                    .where((it) =>
                        nameOf(it).toLowerCase().contains(query) ||
                        subtitleOf(it).toLowerCase().contains(query))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(sheetCtx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search by name or region...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text("No results.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (ctx, i) {
                                final item = visible[i];
                                final photo = photoOf(item);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                                    child: photo == null ? const Icon(Icons.image_not_supported_outlined) : null,
                                  ),
                                  title: Text(nameOf(item)),
                                  subtitle: Text(subtitleOf(item)),
                                  trailing: FavoriteButton(itemType: favoriteType, itemId: item["id"]),
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.pop(sheetCtx);
                                  },
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
  }

  Widget _buildWeatherAndCostCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weather Forecast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_anyBadWeather)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "⚠️ Warning: rainy weather is expected on one or more days of this trip. "
                  "Consider indoor alternatives or a schedule change.",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ..._days.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 56, child: Text("Day ${day.dayNumber}")),
                    if (day.loadingWeather)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (day.weather != null && day.weather!["available"] == true)
                      Expanded(
                        child: Text(
                          "${(day.weather!["temperature"] as num).toStringAsFixed(0)}°C, "
                          "${day.weather!["description"]} "
                          "${day.weather!["isRainy"] == true ? '🌧️ Bad weather warning' : '☀️'}",
                          style: TextStyle(
                            color: day.weather!["isRainy"] == true ? Colors.red : null,
                            fontWeight: day.weather!["isRainy"] == true ? FontWeight.bold : null,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          day.weather?["message"] ?? "Weather unavailable for this day.",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            const Text("Estimated Trip Cost", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_isRecalculating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              )
            else ...[
              _costRow("Hotel(s)", _hotelCost),
              _costRow("Guide (estimated)", _guideCost),
              _costRow("Vehicle (distance-based)", _vehicleCost),
              const Divider(),
              _costRow("Total", _totalCost, bold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _costRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text("LKR ${value.toStringAsFixed(2)}", style: style),
        ],
      ),
    );
  }

  // A tappable "current selection" row (photo + label) that opens the picker sheet —
  // used in place of a plain dropdown so the guide/vehicle/hotel's photo is visible.
  Widget _buildPickerTile({
    required String? photoUrl,
    required IconData fallbackIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? Icon(fallbackIcon) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Vehicle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _buildPickerTile(
          photoUrl: _selectedVehicleId != null
              ? _vehicleCoverPhotoUrl(_allVehicles.firstWhere((v) => v["id"] == _selectedVehicleId, orElse: () => null))
              : null,
          fallbackIcon: Icons.directions_car,
          label: _vehicleLabel(_selectedVehicleId),
          onTap: () => _openPicker(
            title: "Select a Vehicle",
            items: _allVehicles,
            favoriteType: "Vehicle",
            nameOf: (v) => (v["name"] as String?)?.isNotEmpty == true ? v["name"] : v["type"] ?? "Vehicle",
            subtitleOf: (v) => "${v["type"]} • ${v["region"] ?? ''} • LKR ${v["pricePerKm"] ?? 0}/km",
            photoOf: _vehicleCoverPhotoUrl,
            onSelect: (v) {
              setState(() => _selectedVehicleId = v["id"]);
              _recalculateAll();
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text("Guide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _buildPickerTile(
          photoUrl: _selectedGuideId != null
              ? _guidePhotoUrl(_allGuides.firstWhere((g) => g["id"] == _selectedGuideId, orElse: () => null))
              : null,
          fallbackIcon: Icons.person,
          label: _guideLabel(_selectedGuideId),
          onTap: () => _openPicker(
            title: "Select a Guide",
            items: _allGuides,
            favoriteType: "Guide",
            nameOf: (g) => (g["name"] as String?)?.isNotEmpty == true ? g["name"] : "Guide #${g["id"]}",
            subtitleOf: (g) => "${g["region"] ?? ''} • ${g["languages"] ?? ''} • ⭐ ${((g["rating"] as num?) ?? 0).toStringAsFixed(1)}",
            photoOf: _guidePhotoUrl,
            onSelect: (g) {
              setState(() => _selectedGuideId = g["id"]);
              _recalculateAll();
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Per-Day Destinations & Hotel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Day"),
              onPressed: _addDay,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._days.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Day ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _removeDay(index),
                      ),
                    ],
                  ),
                  TextField(
                    controller: day.activitiesController,
                    decoration: const InputDecoration(hintText: "Activities for this day..."),
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  const Text("Destinations for this day", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ..._allDestinations.map((d) {
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d["name"] ?? ""),
                      subtitle: Text(d["region"] ?? ""),
                      value: day.destinationIds.contains(d["id"]),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            day.destinationIds.add(d["id"]);
                          } else {
                            day.destinationIds.remove(d["id"]);
                          }
                        });
                        _recalculateAll();
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text("Hotel for this day", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  _buildPickerTile(
                    photoUrl: day.hotelId != null
                        ? _hotelPhotoUrl(_allHotels.firstWhere((h) => h["id"] == day.hotelId, orElse: () => null))
                        : null,
                    fallbackIcon: Icons.hotel,
                    label: day.hotelId == null
                        ? "Not selected"
                        : (() {
                            final h = _allHotels.firstWhere((h) => h["id"] == day.hotelId, orElse: () => null);
                            return h == null ? "Hotel #${day.hotelId}" : "${h["name"]} — LKR ${h["pricePerNight"]}/night";
                          })(),
                    onTap: () => _openPicker(
                      title: "Select a Hotel",
                      items: _allHotels,
                      favoriteType: "Hotel",
                      nameOf: (h) => h["name"] ?? "Hotel",
                      subtitleOf: (h) => "${h["region"] ?? ''} • LKR ${h["pricePerNight"] ?? 0}/night • ${'⭐' * ((h["starRating"] as num?)?.toInt() ?? 0)}",
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
        }),
      ],
    );
  }
}
