import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = results);
    } catch (e) {
      // ignore, empty state handles it
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

  IconData _iconFor(String? type) {
    switch (type) {
      case "Welcome":
        return Icons.celebration;
      case "BookingApproved":
        return Icons.check_circle;
      case "BookingCancelled":
        return Icons.cancel;
      case "PaymentConfirmed":
        return Icons.payment;
      case "AIWorkflow":
        return Icons.auto_awesome;
      default:
        return Icons.notifications;
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
              child: const Text("Mark all read", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.notifications_none, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Center(child: Text("No notifications yet.")),
                    ],
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n["isRead"] == true;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        color: isRead ? null : Colors.teal.shade50,
                        child: ListTile(
                          leading: Icon(_iconFor(n["type"]), color: isRead ? Colors.grey : Colors.teal),
                          title: Text(
                            n["title"] ?? "",
                            style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                          ),
                          subtitle: Text(n["message"] ?? ""),
                          trailing: !isRead ? const Icon(Icons.circle, size: 10, color: Colors.teal) : null,
                          onTap: () => _markRead(n),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
