import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ui/ui.dart';

/// Bottom sheet asking where a photo should come from. Returns null if dismissed.
Future<ImageSource?> pickPhotoSource(
  BuildContext context, {
  String title = 'Add a photo',
}) {
  return showAppSheet<ImageSource>(
    context,
    title: title,
    builder: (ctx) => Column(
      children: [
        _SourceTile(
          icon: Icons.photo_camera_rounded,
          label: 'Take a photo',
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        const SizedBox(height: Space.sm),
        _SourceTile(
          icon: Icons.photo_library_rounded,
          label: 'Choose from gallery',
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ],
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTile(icon),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: context.text.titleSmall)),
          Icon(
            Icons.chevron_right_rounded,
            color: context.palette.textTertiary,
          ),
        ],
      ),
    );
  }
}
