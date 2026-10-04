import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
import 'profile_edit_screen.dart';
import 'vehicle_edit_screen.dart';

/// Profile tab (all roles): who you are, your contact details and (for tourists) the reviews you've left.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ReviewItem {
  _ReviewItem(this.trip, this.review);
  final String trip;
  final Map<String, dynamic> review;
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  List<_ReviewItem> _reviews = [];
  List<dynamic> _vehicles = [];
  bool _loading = true;
  String? _error;

  bool get _isTourist {
    final r = context.read<AuthProvider>().role;
    return r != "Guide" && r != "VehicleOwner";
  }

  bool get _isVehicleOwner => context.read<AuthProvider>().role == "VehicleOwner";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getMyProfile();
      final reviews = <_ReviewItem>[];
      if (_isTourist) {
        // Reviews are stored per booking, so collect them from the trips that have ended.
        final bookings = await _api.getMyBookings();
        final ended = bookings.where((b) => bookingStatusLabel(b["status"]) == "Ended").toList();
        final lists = await Future.wait(ended.map((b) => _api.getReviewsForBooking(b["id"] as int)));
        for (var i = 0; i < ended.length; i++) {
          final b = ended[i];
          final name = (b["packageName"] ?? b["package"]?["name"] ?? "Custom tour").toString();
          for (final r in lists[i]) {
            reviews.add(_ReviewItem(name, Map<String, dynamic>.from(r)));
          }
        }
        reviews.sort((a, b) => (b.review["createdAt"] ?? "").toString().compareTo((a.review["createdAt"] ?? "").toString()));
      }
      final vehicles = _isVehicleOwner ? await _api.getMyVehicles() : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _reviews = reviews;
        _vehicles = vehicles;
      });
    } catch (_) {
      if (mounted) setState(() => _error = "We couldn't load your profile.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmSheet(
      context,
      title: "Sign out?",
      message: "You'll need to sign in again to see your tours and messages.",
      confirmLabel: "Sign out",
      destructive: true,
    );
    if (ok && mounted) context.read<AuthProvider>().logout();
  }

  String _roleLabel(String? role) => switch (role) {
        "VehicleOwner" => "Vehicle owner",
        null => "",
        _ => role,
      };

  String? _photoUrl() {
    final u = (_profile?["profilePictureUrl"] ?? "").toString();
    if (u.isEmpty) return null;
    return u.startsWith("http") ? u : "${ApiService.baseUrl.replaceAll('/api', '')}$u";
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.palette;
    final avg = _reviews.isEmpty ? 0.0 : _reviews.map((r) => ((r.review["rating"] ?? 0) as num).toDouble()).reduce((a, b) => a + b) / _reviews.length;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateView(
          loading: _loading && _profile == null,
          error: _profile == null ? _error : null,
          onRetry: _load,
          skeleton: const SkeletonList(count: 3, leading: false),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              FadeInUp(
                child: GlassCard(
                  child: Column(children: [
                    AppAvatar(auth.name, size: 92, imageUrl: _photoUrl()),
                    const SizedBox(height: Space.md),
                    Text(auth.name ?? "", style: context.text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: Space.xs),
                    StatusBadge(_roleLabel(auth.role), tone: Tone.info),
                    if ((_profile?["email"] ?? "").toString().isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      Text("${_profile!["email"]}", style: context.text.bodyMedium!.copyWith(color: p.textSecondary)),
                    ],
                    const SizedBox(height: Space.lg),
                    AppButton(
                      label: "Edit profile",
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                        _load();
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Space.lg),
              FadeInUp(
                index: 1,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
                  child: Column(children: [
                    _Detail(Icons.phone_rounded, "Mobile", _profile?["mobileNumber"]?.toString()),
                    _Detail(Icons.public_rounded, "Country", _profile?["country"]?.toString()),
                    _Detail(Icons.cake_rounded, "Age", _profile?["age"]?.toString()),
                    _Detail(Icons.badge_rounded, "Account", _roleLabel(auth.role)),
                  ]),
                ),
              ),
              if (_isVehicleOwner) ...[
                const SizedBox(height: Space.xxl),
                const SectionHeader("My vehicles"),
                const SizedBox(height: Space.sm),
                if (_vehicles.isEmpty)
                  const GlassCard(
                    child: EmptyState(
                      icon: Icons.directions_car_rounded,
                      title: "No vehicles on file",
                      message: "Vehicles you register will appear here.",
                    ),
                  )
                else
                  for (var i = 0; i < _vehicles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: FadeInUp(
                        index: i,
                        child: _VehicleCard(
                          vehicle: Map<String, dynamic>.from(_vehicles[i]),
                          onEdit: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VehicleEditScreen(
                                  vehicle: Map<String, dynamic>.from(_vehicles[i]),
                                ),
                              ),
                            );
                            if (changed == true) _load();
                          },
                        ),
                      ),
                    ),
              ],
              if (_isTourist) ...[
                const SizedBox(height: Space.xxl),
                Row(children: [
                  const Expanded(child: SectionHeader("Review history")),
                  if (_reviews.isNotEmpty) ...[
                    StatusBadge("${_reviews.length} ${_reviews.length == 1 ? "review" : "reviews"}"),
                    const SizedBox(width: Space.sm),
                    RatingStars(avg),
                  ],
                ]),
                const SizedBox(height: Space.sm),
                if (_reviews.isEmpty)
                  const GlassCard(
                    child: EmptyState(
                      icon: Icons.rate_review_outlined,
                      title: "No reviews yet",
                      message: "After a tour ends you can rate your guide, hotel and vehicle — your reviews will show up here.",
                    ),
                  )
                else
                  for (var i = 0; i < _reviews.length; i++)
                    Padding(padding: const EdgeInsets.only(bottom: Space.md), child: FadeInUp(index: i, child: _ReviewCard(_reviews[i]))),
              ],
              const SizedBox(height: Space.xl),
              AppButton(label: "Sign out", icon: Icons.logout_rounded, variant: AppButtonVariant.danger, onPressed: _logout),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(children: [
        IconTile(icon, size: 38),
        const SizedBox(width: Space.md),
        Text(label, style: context.text.bodyMedium!.copyWith(color: context.palette.textSecondary)),
        const Spacer(),
        Flexible(child: Text(has ? value! : "—", style: context.text.titleSmall, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onEdit});
  final Map<String, dynamic> vehicle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final type = (vehicle["type"] ?? "").toString();
    final name = (vehicle["name"] ?? "").toString();
    final year = vehicle["manufacturerYear"];
    final capacity = vehicle["capacity"];
    final region = (vehicle["region"] ?? "").toString();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
      child: Row(
        children: [
          const IconTile(Icons.directions_car_rounded, size: 46),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? type : "$name ($type)",
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (capacity != null) "$capacity seats",
                    if (year != null) "$year",
                    if (region.isNotEmpty) region,
                  ].join(" · "),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          AppButton(
            label: "Edit",
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            expand: false,
            compact: true,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.item);
  final _ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final r = item.review;
    final rating = ((r["rating"] ?? 0) as num).toInt();
    final date = (r["createdAt"] ?? "").toString();
    final comment = (r["comment"] ?? "").toString();
    return GlassCard(
      radius: Radii.lg,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.trip, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (date.length >= 10) Text(date.substring(0, 10), style: context.text.bodySmall),
        ]),
        const SizedBox(height: Space.xs),
        Semantics(
          label: "$rating out of 5 stars",
          child: Row(children: [
            for (var i = 1; i <= 5; i++) Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: const Color(0xFFF59E0B)),
          ]),
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(comment, style: context.text.bodyMedium),
        ],
        if (r["hotelRating"] != null || r["vehicleRating"] != null) ...[
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.sm, children: [
            if (r["hotelRating"] != null) StatusBadge("Hotel ${r["hotelRating"]}★", icon: Icons.hotel_rounded),
            if (r["vehicleRating"] != null) StatusBadge("Vehicle ${r["vehicleRating"]}★", icon: Icons.directions_car_rounded),
          ]),
        ],
      ]),
    );
  }
}
