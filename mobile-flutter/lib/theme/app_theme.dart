import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/scenic/scenic.dart' show ScenicTransitions;

/// Spacing scale (4pt grid) — use these instead of raw numbers.
class Space {
  Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Brand colours taken from the Ceylora logo.
class AppColors {
  AppColors._();
  static const ink = Color(0xFF2F6AA3); // logo navy, softened for UI fills
  static const ocean = Color(0xFF1B8FD1);
  static const sun = Color(0xFFF8A31C);
  static const palm = Color(0xFF1F6B52);
}

class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 22;
  static const double xl = 32;
  static const double full = 999;
}

class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Curve out = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// Semantic colours that Material's ColorScheme has no slot for (status tones,
/// borders, tertiary text). Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface2,
    required this.border,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.accent,
    required this.accentSoft,
    required this.primarySoft,
    required this.hero,
  });

  final Color background;
  final Color surface2;
  final Color border;
  final Color textSecondary;
  final Color textTertiary;
  final Color success, successSoft;
  final Color warning, warningSoft;
  final Color danger, dangerSoft;
  final Color info, infoSoft;
  final Color accent, accentSoft;
  final Color primarySoft;
  final Color hero;

  static const light = AppPalette(
    background: Color(0xFF5F8BB8),
    surface2: Color(0xFF4F7DAE),
    border: Color(0xFF3F6C9E),
    textSecondary: Color(0xFF1C3149),
    textTertiary: Color(0xFF26405C),
    success: Color(0xFF1F6B52),
    successSoft: Color(0xFFD7EFE6),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEE2E2),
    info: Color(0xFF0F6FB3),
    infoSoft: Color(0xFFDCEEFA),
    accent: Color(0xFFD97706),
    accentSoft: Color(0xFFFDECCB),
    primarySoft: Color(0xFFD6EAF8),
    hero: Color(0xFF0B2A52),
  );

  static const dark = AppPalette(
    background: Color(0xFF0F2A4A),
    surface2: Color(0xFF244B78),
    border: Color(0xFF33618F),
    textSecondary: Color(0xFFC3D5E8),
    textTertiary: Color(0xFF8399B0),
    success: Color(0xFF4ADE80),
    successSoft: Color(0x244ADE80),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x24FBBF24),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0x26F87171),
    info: Color(0xFF4FB3F0),
    infoSoft: Color(0x244FB3F0),
    accent: Color(0xFFF9B23C),
    accentSoft: Color(0x26F9B23C),
    primarySoft: Color(0x334FB3F0),
    hero: Color(0xFF0B2A52),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 ? this : (other as AppPalette? ?? this);
}

extension AppThemeX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = isDark
        ? ColorScheme.dark(
            primary: const Color(0xFF4FB3F0),
            onPrimary: const Color(0xFF04223A),
            primaryContainer: const Color(0xFF245485),
            onPrimaryContainer: const Color(0xFFD6EAF8),
            secondary: p.accent,
            onSecondary: const Color(0xFF2A1004),
            surface: const Color(0xFF1A3B61),
            onSurface: const Color(0xFFE8EEF6),
            onSurfaceVariant: p.textSecondary,
            outline: p.border,
            outlineVariant: p.border,
            error: p.danger,
            onError: const Color(0xFF2A0707),
          )
        : ColorScheme.light(
            primary: AppColors.ink,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFD6EAF8),
            onPrimaryContainer: const Color(0xFF0B2A52),
            secondary: p.accent,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF06172B),
            onSurfaceVariant: p.textSecondary,
            outline: p.border,
            outlineVariant: p.border,
            error: p.danger,
            onError: Colors.white,
          );

    final baseText = GoogleFonts.bricolageGrotesqueTextTheme(
      ThemeData(brightness: b).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12.5,
        color: p.textTertiary,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: c, width: w),
    );

    const buttonShape = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: Space.xl,
      vertical: Space.md,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ScenicTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.iOS: ScenicTransitions(CupertinoPageTransitionsBuilder()),
          TargetPlatform.windows: ScenicTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.macOS: ScenicTransitions(CupertinoPageTransitionsBuilder()),
          TargetPlatform.linux: ScenicTransitions(FadeForwardsPageTransitionsBuilder()),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: 15,
        ),
        hintStyle: TextStyle(color: p.textTertiary),
        border: border(p.border),
        enabledBorder: border(isDark ? p.border : const Color(0xFFCBD5E1)),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger, 2),
        errorStyle: TextStyle(color: p.danger, fontSize: 12.5),
        prefixIconColor: p.textTertiary,
        suffixIconColor: p.textTertiary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: buttonPadding,
          shape: buttonShape,
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: isDark ? p.border : const Color(0xFFCBD5E1)),
          foregroundColor: scheme.onSurface,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: p.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : p.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : p.textTertiary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        modalBackgroundColor: scheme.surface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFE8EEF6)
            : const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        insetPadding: const EdgeInsets.all(Space.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: p.surface2,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.success
              : (isDark ? const Color(0xFF2C4363) : const Color(0xFFCBD5E1)),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: p.textTertiary,
        indicatorColor: scheme.primary,
        dividerColor: p.border,
        labelStyle: textTheme.labelLarge,
      ),
    );
  }
}
