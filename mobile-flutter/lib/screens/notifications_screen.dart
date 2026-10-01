import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = results);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load notifications.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(dynamic notification) async {
    if (notification["isRead"] == true) return;
    if (!mounted) return;
    setState(() => notification["isRead"] = true);
    try {
      await _apiService.markNotificationRead(notification["id"]);
    } catch (_) {
      // keep the optimistic update even if the request fails silently
    }
  }

  Future<void> _markAllRead() async {
    if (!mounted) return;
    setState(() {
      for (final n in _notifications) {
        n["isRead"] = true;
      }
    });
    try {
      await _apiService.markAllNotificationsRead();
    } catch (_) {}
  }

  (IconData, Tone) _styleFor(String? type) {
    switch (type) {
      case "Welcome":
        return (Icons.celebration_rounded, Tone.accent);
      case "BookingApproved":
        return (Icons.check_circle_rounded, Tone.success);
      case "BookingCancelled":
        return (Icons.cancel_rounded, Tone.danger);
      case "PaymentConfirmed":
        return (Icons.payments_rounded, Tone.success);
      case "AIWorkflow":
        return (Icons.route_rounded, Tone.info);
      default:
        return (Icons.notifications_rounded, Tone.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => n["isRead"] != true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text("Mark all read"),
            ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateView(
          loading: _isLoading,
          error: _error,
          onRetry: _load,
          isEmpty: _notifications.isEmpty,
          emptyIcon: Icons.notifications_none_rounded,
          emptyTitle: "You're all caught up",
          emptyMessage: "Booking updates and trip news will show up here.",
          child: ListView.separated(
            padding: const EdgeInsets.all(Space.lg),
            itemCount: _notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, index) {
              final n = _notifications[index];
              final isRead = n["isRead"] == true;
              final (icon, tone) = _styleFor(n["type"]);
              return FadeInUp(
                index: index,
                child: GlassTile(
                  onTap: () => _markRead(n),
                  color: isRead ? null : context.palette.primarySoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                        icon,
                        tone: isRead ? Tone.neutral : tone,
                        size: 40,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n["title"] ?? "",
                              style: context.text.titleSmall!.copyWith(
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n["message"] ?? "",
                              style: context.text.bodyMedium!.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Semantics(
                          label: "Unread",
                          child: Container(
                            margin: const EdgeInsets.only(
                              left: Space.sm,
                              top: 6,
                            ),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: context.scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
