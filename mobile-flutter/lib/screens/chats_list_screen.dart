///chart screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
import 'chat_screen.dart';

// Chats tab. Tourist side: each row is identified by the trip/package name, with the
// guide's name shown inside the conversation itself. Guide side: each row is identified
// by the tourist's name.
class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _threads = [];
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
      final threads = await _apiService.getChatThreads();
      if (mounted) setState(() => _threads = threads);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load your chats.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuide = context.read<AuthProvider>().role == "Guide";

    return Scaffold(
      appBar: AppBar(title: const Text("Chats")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateView(
          loading: _isLoading,
          error: _error,
          onRetry: _load,
          isEmpty: _threads.isEmpty,
          emptyIcon: Icons.forum_outlined,
          emptyTitle: "No chats yet",
          emptyMessage: isGuide
              ? "Conversations with your tourists will appear here."
              : "Once a guide is assigned to your tour, you can chat with them here.",
          child: ListView.separated(
            padding: const EdgeInsets.all(Space.lg),
            itemCount: _threads.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, index) {
              final t = _threads[index];
              final title =
                  (isGuide
                          ? (t["otherPartyName"] ?? "Tourist")
                          : (t["tripName"] ?? "Tour"))
                      .toString();
              final unread = (t["unread"] as num?)?.toInt() ?? 0;
              return FadeInUp(
                index: index,
                child: GlassTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          bookingId: t["bookingId"],
                          title: isGuide
                              ? (t["otherPartyName"] ?? "Chat")
                              : (t["tripName"] ?? "Chat"),
                          subtitle: isGuide
                              ? null
                              : "Guide: ${t["otherPartyName"] ?? ''}",
                        ),
                      ),
                    ).then((_) => _load());
                  },
                  child: Row(
                    children: [
                      isGuide
                          ? AppAvatar(title, size: 48)
                          : const IconTile(Icons.luggage_rounded, size: 48),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: context.text.titleSmall!.copyWith(
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t["lastMessage"] ?? "No messages yet",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium!.copyWith(
                                color: unread > 0
                                    ? context.scheme.onSurface
                                    : context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(t["lastMessageAt"]),
                            style: context.text.bodySmall,
                          ),
                          if (unread > 0)
                            Semantics(
                              label: "$unread unread",
                              child: Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.scheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    Radii.full,
                                  ),
                                ),
                                child: Text(
                                  "$unread",
                                  style: context.text.labelMedium!.copyWith(
                                    color: context.scheme.onPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
