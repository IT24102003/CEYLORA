import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'destinations_screen.dart';
import 'packages_screen.dart';
import 'hotels_screen.dart';
import 'vehicles_screen.dart';
import 'guides_screen.dart';
import 'profile_screen.dart';
import 'guide_home_screen.dart';
import 'vehicle_owner_home_screen.dart';
import 'trip_planner_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'currency_converter_screen.dart';
import 'chats_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
    _refreshVerificationStatus();
    // Simple polling — good enough for a student project demo, no extra realtime tech needed.
    // Also re-checks Guide/VehicleOwner verification status, so the "pending review" banner
    // clears on its own soon after an Admin approves — no manual "check again" needed.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshUnreadCount();
      _refreshVerificationStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // ignore — badge just won't update this cycle
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

  void _openMyProfile(BuildContext context, AuthProvider auth) {
    Widget destination;
    if (auth.role == "Guide") {
      destination = const GuideHomeScreen();
    } else if (auth.role == "VehicleOwner") {
      destination = const VehicleOwnerHomeScreen();
    } else {
      destination = const ProfileScreen();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isGatedRole = auth.role == "Guide" || auth.role == "VehicleOwner";

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${auth.name ?? ''}"),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: "Notifications",
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                  _refreshUnreadCount();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? "9+" : "$_unreadCount",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: "My Favorites",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            tooltip: "Currency Converter",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Role: ${auth.role}", style: const TextStyle(color: Colors.grey)),
            if (isGatedRole && !auth.isVerified) ...[
              const SizedBox(height: 12),
              Container(
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
                        "Your account is under review. You can use the app normally in the "
                        "meantime — you'll be shown to tourists once an Admin verifies your details.",
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Plan My Trip with AI"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripPlannerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.explore),
              label: const Text("Browse Destinations"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DestinationsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.card_travel),
              label: const Text("Browse Packages"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PackagesScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.hotel),
              label: const Text("Browse Hotels"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HotelsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.directions_car),
              label: const Text("Browse Vehicles"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehiclesScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.person_search),
              label: const Text("Browse Guides"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuidesScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              icon: Icon(isGatedRole ? Icons.dashboard : Icons.account_circle),
              label: Text(isGatedRole ? "My Dashboard" : "My Profile"),
              onPressed: () => _openMyProfile(context, auth),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "home_chat_fab",
        tooltip: "Chats",
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsListScreen()));
        },
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
