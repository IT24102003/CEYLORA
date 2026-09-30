import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

// Reached from the chat icon on the home screen (Tourist) / guide dashboard (Guide).
// Tourist side: each row is identified by the trip/package name, with the guide's name
// shown inside the conversation itself. Guide side: each row is identified by the
// tourist's name.
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final threads = await _apiService.getChatThreads();
      if (mounted) setState(() => _threads = threads);
    } catch (e) {
      if (mounted) setState(() => _error = "Failed to load chats.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _threads.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Text(
                              "No chats yet.\nOnce a guide is assigned to your trip, you can chat here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _threads.length,
                        itemBuilder: (context, index) {
                          final t = _threads[index];
                          final title = isGuide ? (t["otherPartyName"] ?? "Tourist") : (t["tripName"] ?? "Trip");
                          final unread = (t["unread"] as num?)?.toInt() ?? 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Icon(isGuide ? Icons.person : Icons.card_travel, color: Colors.teal),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              t["lastMessage"] ?? "No messages yet",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatTime(t["lastMessageAt"]), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text("$unread", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    bookingId: t["bookingId"],
                                    title: isGuide ? (t["otherPartyName"] ?? "Chat") : (t["tripName"] ?? "Chat"),
                                    subtitle: isGuide ? null : "Guide: ${t["otherPartyName"] ?? ''}",
                                  ),
                                ),
                              ).then((_) => _load());
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
