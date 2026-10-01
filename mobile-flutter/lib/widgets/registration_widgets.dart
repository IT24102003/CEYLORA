import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'ui/ui.dart';

/// Labelled international phone field (flag + dial code) in the app's input style.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.onChanged,
    required this.onCountryChanged,
    this.errorText,
    this.label = "Mobile number",
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCountryChanged;
  final String? errorText;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: context.text.labelMedium!.copyWith(
              fontSize: 13.5,
              color: context.scheme.onSurface,
            ),
          ),
        ),
        IntlPhoneField(
          initialCountryCode: 'LK',
          disableLengthCheck: true,
          decoration: InputDecoration(errorText: errorText, counterText: ""),
          flagsButtonPadding: const EdgeInsets.only(left: Space.sm),
          dropdownIconPosition: IconPosition.trailing,
          dropdownIcon: const Icon(Icons.arrow_drop_down, size: 20),
          onChanged: (phone) => onChanged(phone.completeNumber),
          onCountryChanged: (country) => onCountryChanged(country.name),
        ),
      ],
    );
  }
}

/// Document / photo upload block: preview thumbnail(s), a button, and an inline error.
class PhotoUploadTile extends StatelessWidget {
  const PhotoUploadTile({
    super.key,
    required this.title,
    required this.hint,
    required this.buttonLabel,
    required this.onPick,
    this.photos = const [],
    this.error,
    this.icon = Icons.upload_file_rounded,
  });

  final String title;
  final String hint;
  final String buttonLabel;
  final VoidCallback onPick;
  final List<Uint8List> photos;
  final String? error;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      color: error != null ? p.dangerSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                photos.isEmpty ? icon : Icons.check_rounded,
                tone: photos.isEmpty ? Tone.info : Tone.success,
                size: 40,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    Text(hint, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Image.memory(
                    photos[i],
                    width: photos.length == 1 ? 160 : 92,
                    height: 92,
                    fit: BoxFit.cover,
                    semanticLabel: "$title ${i + 1}",
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.md),
          AppButton(
            label: buttonLabel,
            icon: Icons.add_photo_alternate_rounded,
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: onPick,
          ),
          if (error != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              error!,
              style: context.text.bodySmall!.copyWith(color: p.danger),
            ),
          ],
        ],
      ),
    );
  }
}

String? requiredField(String? v, String message) =>
    (v == null || v.trim().isEmpty) ? message : null;
