import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'ui/ui.dart';

/// A heart that checks + toggles favorite status for one item, with an optimistic
/// "pop" animation. Reused on the Destinations/Packages/Hotels/Guides/Vehicles browse screens.
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
      final result = await _apiService.isFavorite(
        widget.itemType,
        widget.itemId,
      );
      if (mounted) setState(() => _isFavorite = result);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy || _isFavorite == null) return;
    final wasFavorite = _isFavorite!;
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _isFavorite = !wasFavorite; // optimistic
    });
    try {
      if (wasFavorite) {
        await _apiService.removeFavorite(widget.itemType, widget.itemId);
      } else {
        await _apiService.addFavorite(widget.itemType, widget.itemId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = wasFavorite); // roll back
        showToast(
          context,
          "Couldn't update favorites. Try again.",
          tone: Tone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fav = _isFavorite ?? false;
    return IconButton(
      tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
      onPressed: _isFavorite == null ? null : _toggle,
      icon: AnimatedSwitcher(
        duration: Motion.base,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Motion.spring),
          child: child,
        ),
        child: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(fav),
          color: fav ? context.palette.danger : context.palette.textTertiary,
          size: widget.size,
        ),
      ),
    );
  }
}
