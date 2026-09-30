import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// A small heart icon that checks + toggles favorite status for one item.
/// Reused on the Destinations/Packages/Hotels/Guides/Vehicles browse screens.
class FavoriteButton extends StatefulWidget {
  final String itemType; // FavoriteItemType.* on the backend: "Destination" | "Package" | "Hotel" | "Guide" | "Vehicle"
  final int itemId;
  final double size;

  const FavoriteButton({
    super.key,
    required this.itemType,
    required this.itemId,
    this.size = 24,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final ApiService _apiService = ApiService();
  bool? _isFavorite; // null while loading
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final result = await _apiService.isFavorite(widget.itemType, widget.itemId);
      if (mounted) setState(() => _isFavorite = result);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy || _isFavorite == null) return;
    setState(() => _busy = true);
    final wasFavorite = _isFavorite!;
    try {
      if (wasFavorite) {
        await _apiService.removeFavorite(widget.itemType, widget.itemId);
      } else {
        await _apiService.addFavorite(widget.itemType, widget.itemId);
      }
      if (mounted) setState(() => _isFavorite = !wasFavorite);
    } catch (_) {
      // keep previous state on failure
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFavorite == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        _isFavorite! ? Icons.favorite : Icons.favorite_border,
        color: _isFavorite! ? Colors.red : Colors.grey,
        size: widget.size,
      ),
      onPressed: _toggle,
    );
  }
}
