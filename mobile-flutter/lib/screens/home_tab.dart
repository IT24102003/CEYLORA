import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/scenic/scenic.dart';
import '../widgets/ui/ui.dart';
import 'booking_screen.dart';
import 'destinations_screen.dart';
import 'favorites_screen.dart';
import 'guides_screen.dart';
import 'hotels_screen.dart';
import 'notifications_screen.dart';
import 'packages_screen.dart';
import 'trip_planner_screen.dart';
import 'vehicles_screen.dart';

enum _Cat { destinations, packages, hotels }

/// Home tab: immersive sunset header, search, category pills, a "Popular" carousel and the AI planner.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.unreadNotifications,
    required this.onNotificationsClosed,
  });

  final int unreadNotifications;
  final VoidCallback onNotificationsClosed;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ApiService _apiService = ApiService();
  _Cat _cat = _Cat.destinations;
  final PageController _carousel = PageController();
  Timer? _autoSwipe;
  DateTime _pausedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<_Cat, List<dynamic>> _cache = {};
  bool _loading = true;
  String? _photoUrl; // the user's profile picture
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPhoto();
    // Gently advance the carousel every 3s; any touch pauses it for a few seconds.
    _autoSwipe = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
  }

  @override
  void dispose() {
    _autoSwipe?.cancel();
    _carousel.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || !_carousel.hasClients || _loading) return;
    if (MediaQuery.of(context).disableAnimations) return;
    if (DateTime.now().isBefore(_pausedUntil) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    // Two cards per page: slide the current pair out to the left and bring the next pair in from the right.
    final pages = ((_cache[_cat]?.length ?? 0) / 2).ceil();
    if (pages <= 1) return;
    final next = ((_carousel.page ?? 0).round() + 1) % pages;
    _carousel.animateToPage(
      next,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _loadPhoto() async {
    try {
      final profile = await _apiService.getMyProfile();
      if (mounted)
        setState(() => _photoUrl = profile["profilePictureUrl"]?.toString());
    } catch (_) {
      // keep initials
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    if (!force && _cache.containsKey(_cat)) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final cat = _cat;
    try {
      final list = switch (cat) {
        _Cat.packages =>
          (await _apiService.getPackages())
              .where((p) => p["isPublished"] == true)
              .toList(),
        _Cat.destinations => await _apiService.getDestinations(),
        _Cat.hotels => await _apiService.getHotels(),
      };
      if (!mounted) return;
      _cache[cat] = list.toList();
      // Kick off the image downloads for the whole list right now, instead of waiting for
      // each card to actually scroll into view — this is what was causing the visible
      // "blank then pop in" delay when the carousel auto-swiped or the user swiped.
      _precacheImages(list);
    } catch (_) {
      if (mounted && cat == _cat) _error = "We couldn't load this right now.";
    } finally {
      if (mounted && cat == _cat) setState(() => _loading = false);
    }
  }

  /// Warms Flutter's image cache for every item in [list] as soon as the data arrives,
  /// so by the time a card actually scrolls into view its image is already loaded (or
  /// well on its way) instead of starting the network fetch right as it appears.
  void _precacheImages(List<dynamic> list) {
    for (final item in list) {
      final url = resolveImageUrl(item["imageUrl"] as String?);
      if (url == null) continue;
      precacheImage(NetworkImage(url), context).catchError((_) {});
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget get _seeAllScreen => switch (_cat) {
    _Cat.packages => const PackagesScreen(),
    _Cat.destinations => const DestinationsScreen(),
    _Cat.hotels => const HotelsScreen(),
  };

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? "Good morning"
        : (h < 18 ? "Good afternoon" : "Good evening");
  }

  void _select(_Cat c) {
    if (c == _cat) return;
    setState(() => _cat = c);
    if (_carousel.hasClients) _carousel.jumpToPage(0);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isGated = auth.role == "Guide" || auth.role == "VehicleOwner";
    final firstName = (auth.name ?? "").trim().split(RegExp(r'\s+')).first;
    final items = _cache[_cat] ?? const [];

    return Scaffold(
      body: Stack(
        children: [
          const ScenicBackground(reach: 0.8, opacity: 0.9),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                _loadPhoto();
                await _load(force: true);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.xxl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xl,
                      Space.sm,
                      Space.xl,
                      0,
                    ),
                    child: FadeInUp(
                      child: Row(
                        children: [
                          AppAvatar(auth.name, size: 48, imageUrl: _photoUrl),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: context.text.bodySmall!.copyWith(
                                    color: context.scheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                Text(
                                  firstName.isEmpty ? "Traveller" : firstName,
                                  style: context.text.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          GlassCircleButton(
                            icon: Icons.favorite_rounded,
                            color: context.palette.danger,
                            tooltip: "Favorites",
                            onPressed: () => _push(const FavoritesScreen()),
                          ),
                          const SizedBox(width: Space.sm),
                          GlassCircleButton(
                            icon: Icons.notifications_rounded,
                            color: AppColors.ink,
                            tooltip: widget.unreadNotifications > 0
                                ? "Notifications, ${widget.unreadNotifications} unread"
                                : "Notifications",
                            badge: widget.unreadNotifications,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                              widget.onNotificationsClosed();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xl,
                      Space.xl,
                      Space.xl,
                      Space.lg,
                    ),
                    child: FadeInUp(
                      index: 1,
                      child: Text(
                        "Welcome Back",
                        style: context.text.headlineMedium!.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                  if (isGated && !auth.isVerified)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.xl,
                        0,
                        Space.xl,
                        Space.lg,
                      ),
                      child: InlineAlert(
                        "Your account is under review. You can use the app normally — you'll be shown to tourists once an admin verifies you.",
                        tone: Tone.warning,
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: FadeInUp(
                      index: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: "Search destinations",
                              excludeSemantics: true,
                              child: PressScale(
                                onTap: () => _push(const DestinationsScreen()),
                                child: GlassCard(
                                  radius: Radii.full,
                                  blur: 18,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.lg,
                                    vertical: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        color: context.palette.textTertiary,
                                      ),
                                      const SizedBox(width: Space.md),
                                      Text(
                                        "Search places, tours…",
                                        style: context.text.bodyLarge!.copyWith(
                                          color: context.palette.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Semantics(
                            button: true,
                            label: "Browse all packages",
                            excludeSemantics: true,
                            child: PressScale(
                              onTap: () => _push(const PackagesScreen()),
                              child: GlassCard(
                                tint: const Color(0xFF3FA3DE),
                                radius: 18,
                                blur: 14,
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  FadeInUp(
                    index: 3,
                    child: SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xl,
                        ),
                        children: [
                          _CategoryPill(
                            icon: Icons.landscape_rounded,
                            label: "Destinations",
                            selected: _cat == _Cat.destinations,
                            onTap: () => _select(_Cat.destinations),
                          ),
                          _CategoryPill(
                            icon: Icons.luggage_rounded,
                            label: "Packages",
                            selected: _cat == _Cat.packages,
                            onTap: () => _select(_Cat.packages),
                          ),
                          _CategoryPill(
                            icon: Icons.hotel_rounded,
                            label: "Hotels",
                            selected: _cat == _Cat.hotels,
                            onTap: () => _select(_Cat.hotels),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: SectionHeader(
                      switch (_cat) {
                        _Cat.packages => "Popular packages",
                        _Cat.destinations => "Popular places",
                        _Cat.hotels => "Top stays",
                      },
                      actionLabel: "See all",
                      onAction: () => _push(_seeAllScreen),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Listener(
                    onPointerDown: (_) => _pausedUntil = DateTime.now().add(
                      const Duration(seconds: 6),
                    ),
                    child: SizedBox(
                      height: 290,
                      child: AnimatedSwitcher(
                        duration: Motion.base,
                        child: _loading
                            ? const Padding(
                                key: ValueKey('sk'),
                                padding: EdgeInsets.symmetric(
                                  horizontal: Space.xl,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Skeleton(
                                        height: 290,
                                        radius: Radii.lg,
                                      ),
                                    ),
                                    SizedBox(width: Space.md),
                                    Expanded(
                                      child: Skeleton(
                                        height: 290,
                                        radius: Radii.lg,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _error != null
                            ? Center(
                                key: const ValueKey('err'),
                                child: ErrorState(
                                  message: _error,
                                  onRetry: () => _load(force: true),
                                ),
                              )
                            : items.isEmpty
                            ? const Center(
                                key: ValueKey('empty'),
                                child: EmptyState(
                                  icon: Icons.inbox_rounded,
                                  title: "Nothing here yet",
                                ),
                              )
                            : PageView.builder(
                                key: ValueKey(_cat),
                                controller: _carousel,
                                // Pre-builds the previous/next page (and starts loading their
                                // images) ahead of time, instead of only once the swipe lands.
                                allowImplicitScrolling: true,
                                itemCount: (items.length / 2).ceil(),
                                itemBuilder: (context, page) {
                                  final i = page * 2;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Space.xl,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _popularCard(items[i], i),
                                        ),
                                        const SizedBox(width: Space.md),
                                        Expanded(
                                          child: i + 1 < items.length
                                              ? _popularCard(
                                                  items[i + 1],
                                                  i + 1,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: FadeInUp(
                      index: 2,
                      child: _PlannerCard(
                        onTap: () => _push(const TripPlannerScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniTile(
                            icon: Icons.directions_car_rounded,
                            label: "Vehicles",
                            onTap: () => _push(const VehiclesScreen()),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: _MiniTile(
                            icon: Icons.person_search_rounded,
                            label: "Guides",
                            onTap: () => _push(const GuidesScreen()),
                          ),
                        ),
                      ],
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

  Widget _popularCard(dynamic item, int i) {
    final (
      String title,
      String subtitle,
      String price,
      String? image,
      IconData icon,
    ) = switch (_cat) {
      _Cat.packages => (
        "${item["name"]}",
        ((item["maxPeople"] as num?) ?? 0) > 0
            ? "${item["durationDays"]} days · up to ${item["maxPeople"]}"
            : "${item["durationDays"]} days",
        "LKR ${item["basePrice"]}",
        item["imageUrl"] as String?,
        Icons.luggage_rounded,
      ),
      _Cat.destinations => (
        "${item["name"]}",
        "${item["region"] ?? ""}",
        "${item["category"] ?? "Explore"}",
        item["imageUrl"] as String?,
        Icons.landscape_rounded,
      ),
      _Cat.hotels => (
        "${item["name"]}",
        "${item["region"] ?? ""} · ${item["starRating"] ?? 0}★",
        "LKR ${item["pricePerNight"]}",
        item["imageUrl"] as String?,
        Icons.hotel_rounded,
      ),
    };
    const gradients = [
      [Color(0xFF55B4EA), Color(0xFF2A7AB8)],
      [Color(0xFF2BAE95), Color(0xFF1F6B52)],
      [Color(0xFFFFC04D), Color(0xFFE8860C)],
      [Color(0xFF6CC3F2), Color(0xFF2F6AA8)],
    ];
    final g = gradients[i % gradients.length];
    return Semantics(
      button: true,
      label: "$title, $subtitle, $price",
      excludeSemantics: true,
      child: PressScale(
        onTap: () => switch (_cat) {
          _Cat.packages => _push(
            BookingScreen(package: Map<String, dynamic>.from(item)),
          ),
          _Cat.destinations => _push(const DestinationsScreen()),
          _Cat.hotels => _push(const HotelsScreen()),
        },
        child: SizedBox(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.lg),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: g,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -24,
                        bottom: -24,
                        child: Icon(
                          icon,
                          size: 150,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      Center(child: Icon(icon, size: 64, color: Colors.white)),
                      if (image != null && image.isNotEmpty)
                        NetImage(
                          image,
                          radius: 0,
                          fallbackIcon: icon,
                          overlay: true,
                        ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Radii.lg),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.md,
                      Space.lg,
                      Space.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? [
                                const Color(0xFF244E7B).withValues(alpha: 0.78),
                                const Color(0xFF244E7B).withValues(alpha: 0.6),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.86),
                                Colors.white.withValues(alpha: 0.62),
                              ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: context.text.bodySmall!.copyWith(
                            color: context.palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selBg = dark ? context.scheme.primary : AppColors.ink;
    final selFg = dark ? context.scheme.onPrimary : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: Space.md),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.out,
                padding: const EdgeInsets.fromLTRB(8, 8, Space.xl, 8),
                decoration: BoxDecoration(
                  color: selected
                      ? selBg
                      : Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : context.palette.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: selected
                            ? AppColors.ink
                            : context.palette.accent,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Text(
                      label,
                      style: context.text.labelLarge!.copyWith(
                        color: selected ? selFg : context.scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Plan my tour with AI",
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.985,
        child: GlassCard(
          tint: const Color(0xFF2B6CA8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Tour planner",
                          style: context.text.labelMedium!.copyWith(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(Radii.full),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            "AI",
                            style: context.text.labelSmall!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      "Plan a tour",
                      style: context.text.titleLarge!.copyWith(
                        color: Colors.white,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      "Tell us what you want and we suggest places, a hotel, a guide and a vehicle.",
                      style: context.text.bodyMedium!.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: Radii.lg,
      blur: 16,
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      child: Column(
        children: [
          Icon(icon, color: context.palette.accent),
          const SizedBox(height: Space.xs),
          Text(label, style: context.text.labelMedium),
        ],
      ),
    );
  }
}
