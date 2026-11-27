import 'package:flutter/material.dart';
import 'app_theme.dart';

typedef LabTone = ({Color ink, Color surface});

class LabPalette extends ThemeExtension<LabPalette> {
  const LabPalette(this.dark);
  final bool dark;

  Color get mint => dark ? const Color(0xFF214B3A) : const Color(0xFFD6EEE3);
  Color get sunken => dark ? const Color(0xFF1B362B) : const Color(0xFFEFF8F4);
  Color get line => dark ? const Color(0xFF34483F) : const Color(0xFFDCE7E1);
  Color get heroEnd => dark ? const Color(0xFF203E30) : const Color(0xFFE3F2EA);

  LabTone status(String value) => switch (value) {
    'APPROVED' || 'VERIFIED' || 'VERIFIED_RECORD' =>
      dark
          ? (ink: const Color(0xFFFFE1A1), surface: const Color(0xFF473617))
          : (ink: const Color(0xFF7A5413), surface: const Color(0xFFFBF1DA)),
    'IN_REVIEW' || 'SUBMITTED' =>
      dark
          ? (ink: const Color(0xFFFFDD9B), surface: const Color(0xFF45331B))
          : (ink: const Color(0xFF92400E), surface: const Color(0xFFFEF3C7)),
    'RETEST' || 'NEED_REVISION' || 'RETURNED' =>
      dark
          ? (ink: const Color(0xFFFFC6D1), surface: const Color(0xFF4B2330))
          : (ink: const Color(0xFFBE123C), surface: const Color(0xFFFFE4E8)),
    'TESTING' || 'IN_PROGRESS' || 'RECEIVED' =>
      dark
          ? (ink: const Color(0xFFA4EDF8), surface: const Color(0xFF183B41))
          : (ink: const Color(0xFF0E7490), surface: const Color(0xFFE0F4F7)),
    'CANCELLED' || 'CLOSED' || 'REJECTED' =>
      dark
          ? (ink: const Color(0xFFE1D8CE), surface: const Color(0xFF37312C))
          : (ink: const Color(0xFF57534E), surface: const Color(0xFFEFEDEA)),
    _ =>
      dark
          ? (ink: const Color(0xFFD3E0EC), surface: const Color(0xFF28363E))
          : (ink: const Color(0xFF475569), surface: const Color(0xFFF1F5F9)),
  };

  @override
  LabPalette copyWith({bool? dark}) => LabPalette(dark ?? this.dark);
  @override
  LabPalette lerp(covariant LabPalette? other, double t) =>
      t < .5 ? this : other ?? this;
}

class LabTheme {
  static ThemeData get light => _build(false);
  static ThemeData get dark => _build(true);

  static ThemeData _build(bool dark) {
    final base = dark ? AppTheme.dark : AppTheme.light;
    final palette = LabPalette(dark);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF047857),
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: dark ? const Color(0xFF79E5B6) : const Color(0xFF047857),
          onPrimary: dark ? const Color(0xFF063924) : Colors.white,
          surface: dark ? const Color(0xFF17241E) : Colors.white,
          onSurface: dark ? const Color(0xFFEDF6F0) : const Color(0xFF0F1F1A),
          onSurfaceVariant: dark
              ? const Color(0xFFA9C1B5)
              : const Color(0xFF5B6B66),
          outline: palette.line,
          outlineVariant: palette.line,
          secondaryContainer: palette.mint,
          onSecondaryContainer: dark
              ? const Color(0xFFC9F6DE)
              : const Color(0xFF065F46),
          surfaceContainerLow: palette.sunken,
        );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      extensions: [palette],
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0E1713)
          : const Color(0xFFF7F9F8),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: scheme.surface),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.line),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surface,
        border: inputBorder(palette.line),
        enabledBorder: inputBorder(palette.line),
        focusedBorder: inputBorder(scheme.primary, 2),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: palette.mint,
        elevation: 0,
      ),
    );
  }

  static const codeFeatures = <FontFeature>[FontFeature.tabularFigures()];
}
