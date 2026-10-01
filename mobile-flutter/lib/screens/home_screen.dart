import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
import 'chats_list_screen.dart';
import 'currency_converter_screen.dart';
import 'guide_home_screen.dart';
import 'home_tab.dart';
import 'profile_screen.dart';
import 'trips_screen.dart';
import 'vehicle_owner_home_screen.dart';

/// App shell: bottom navigation + one screen per tab.
///   Tourist:               Home · Trips · Chats · Profile
///   Guide / Vehicle owner: Home · Dashboard · Chats · Profile
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int _index = 0;
  final Set<int> _visited = {
    0,
  }; // tabs are built lazily, the first time they're opened
  int _unreadNotifications = 0;
  int _unreadChats = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
    _refreshVerificationStatus();
    // Simple polling — good enough for a student project demo, no extra realtime tech needed.
    // Also re-checks Guide/VehicleOwner verification status, so the "pending review" banner
    // clears on its own soon after an Admin approves — no manual "check again" needed.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshBadges();
      _refreshVerificationStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadges() async {
    try {
      final results = await Future.wait([
        _apiService.getUnreadNotificationCount(),
        _apiService.getChatUnreadCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _unreadNotifications = results[0] as int;
        _unreadChats = (results[1] as Map<int, int>).values.fold(
          0,
          (a, b) => a + b,
        );
      });
    } catch (_) {
      // ignore — badges just won't update this cycle
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != "Guide" && auth.role != "VehicleOwner") return;
    if (auth.isVerified) return; // already verified, nothing to poll for
    try {
      await auth.refreshVerificationStatus();
    } catch (_) {
      // ignore — banner just won't update this cycle
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final isGated = role == "Guide" || role == "VehicleOwner";

    final tabs = <_Tab>[
      _Tab(
        "Home",
        Icons.home_outlined,
        Icons.home_rounded,
        () => HomeTab(
          unreadNotifications: _unreadNotifications,
          onNotificationsClosed: _refreshBadges,
        ),
      ),
      if (isGated)
        _Tab(
          "Dashboard",
          Icons.dashboard_outlined,
          Icons.dashboard_rounded,
          () => role == "Guide"
              ? const GuideHomeScreen()
              : const VehicleOwnerHomeScreen(),
        )
      else
        _Tab(
          "Trips",
          Icons.luggage_outlined,
          Icons.luggage_rounded,
          () => const TripsScreen(),
        ),
      _Tab(
        "Chats",
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        () => const ChatsListScreen(),
        badge: _unreadChats,
      ),
      _Tab(
        "Currency",
        Icons.currency_exchange_rounded,
        Icons.currency_exchange_rounded,
        () => const CurrencyConverterScreen(),
      ),
      _Tab(
        "Profile",
        Icons.person_outline_rounded,
        Icons.person_rounded,
        () => const ProfileScreen(),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _visited.contains(i) ? tabs[i].build() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        index: _index,
        items: [
          for (final t in tabs)
            NavItemData(t.icon, t.selectedIcon, t.label, badge: t.badge),
        ],
        onChanged: (i) {
          if (i == _index) return;
          setState(() {
            _index = i;
            _visited.add(i);
          });
        },
      ),
    );
  }
}

class _Tab {
  _Tab(this.label, this.icon, this.selectedIcon, this.build, {this.badge = 0});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
  final int badge;
}
