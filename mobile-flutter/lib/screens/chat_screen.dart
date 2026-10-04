///chat screen 

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';

class ChatScreen extends StatefulWidget {
  final int bookingId;
  final String
  title; // e.g. trip/package name (tourist side) or tourist name (guide side)
  final String? subtitle; // e.g. "Guide: <name>" shown inside the conversation

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.title,
    this.subtitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages(showSpinner: true);
    // Simple polling every 5 seconds — no real-time server needed.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool showSpinner = false}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final messages = await _apiService.getChatMessages(widget.bookingId);
      if (!mounted) return;
      final wasAtBottom =
          !_scrollController.hasClients ||
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 40;
      setState(() {
        _messages = messages;
        _error = null;
      });
      if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (mounted && showSpinner) {
        setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted && showSpinner) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Motion.base,
      curve: Motion.out,
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _messageController.clear();
    try {
      final sent = await _apiService.sendChatMessage(widget.bookingId, text);
      if (!mounted) return;
      setState(() => _messages = [..._messages, sent]);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          "Message not sent. ${e.toString().replaceFirst("Exception: ", "")}",
          tone: Tone.danger,
        );
        _messageController.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: context.text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: context.text.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return StateView(
      loading: _isLoading,
      error: _error,
      onRetry: () => _loadMessages(showSpinner: true),
      isEmpty: _messages.isEmpty,
      emptyIcon: Icons.waving_hand_rounded,
      emptyTitle: "Say hello",
      emptyMessage:
          "Start the conversation — messages are delivered within seconds.",
      skeleton: const Center(child: CircularProgressIndicator()),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(Space.lg),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final m = _messages[index];
          final isMine = m["isMine"] == true;
          final p = context.palette;
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? context.scheme.primary : context.scheme.surface,
                border: isMine ? null : Border.all(color: p.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(Radii.lg),
                  topRight: const Radius.circular(Radii.lg),
                  bottomLeft: Radius.circular(isMine ? Radii.lg : 4),
                  bottomRight: Radius.circular(isMine ? 4 : Radii.lg),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        m["senderRole"] ?? "",
                        style: context.text.labelMedium!.copyWith(
                          color: context.scheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    m["message"] ?? "",
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 15,
                      color: isMine
                          ? context.scheme.onPrimary
                          : context.scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatTime(m["sentAt"]),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isMine
                            ? context.scheme.onPrimary.withValues(alpha: 0.75)
                            : p.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  Widget _buildComposer() {
    final canSend = _messageController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Type a message",
                    fillColor: context.palette.surface2,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide(
                        color: context.scheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: Space.sm),
              AnimatedContainer(
                duration: Motion.fast,
                decoration: BoxDecoration(
                  color: canSend
                      ? context.scheme.primary
                      : context.palette.surface2,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : IconButton(
                        tooltip: "Send message",
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: canSend
                              ? context.scheme.onPrimary
                              : context.palette.textTertiary,
                        ),
                        onPressed: canSend ? _send : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
