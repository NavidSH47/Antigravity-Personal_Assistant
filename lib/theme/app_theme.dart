import 'package:flutter/material.dart';

enum ThemeVibe {
  deepAmethyst,
  imperialGold,
  purpleOrange,
  cyberViolet,
  solarTangerine,
  sunsetAmber,
  arcticFrost,
  emeraldCyan,
  minimalNordic,
}

enum AppFontStyle {
  defaultSans,
  comicSans,
  roundedBold,
  techMono,
  editorialSerif,
}

class VibePalette {
  final String label;
  final Color bgCanvas;
  final Color bgSurface;
  final Color bgElevated;
  final Color borderSubtle;
  final Color borderFocus;
  final Color textMain;
  final Color textMuted;
  final Color textDim;
  final Color accentPrimary;
  final LinearGradient accentGradient;
  final Color accentGlow;
  final LinearGradient sampleGradient;

  const VibePalette({
    required this.label,
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgElevated,
    required this.borderSubtle,
    required this.borderFocus,
    required this.textMain,
    required this.textMuted,
    required this.textDim,
    required this.accentPrimary,
    required this.accentGradient,
    required this.accentGlow,
    required this.sampleGradient,
  });
}

class AppTheme {
  static const Map<ThemeVibe, VibePalette> vibes = {
    ThemeVibe.deepAmethyst: VibePalette(
      label: 'Deep Amethyst',
      bgCanvas: Color(0xFF05020A),
      bgSurface: Color(0xFF0F0419),
      bgElevated: Color(0xFF1B072D),
      borderSubtle: Color(0x30B026FF),
      borderFocus: Color(0x73B026FF),
      textMain: Color(0xFFFAF5FF),
      textMuted: Color(0xFFE9D5FF),
      textDim: Color(0xFFA855F7),
      accentPrimary: Color(0xFFB026FF),
      accentGradient: LinearGradient(
        colors: [Color(0xFF7E22CE), Color(0xFFB026FF), Color(0xFFD946EF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59B026FF),
      sampleGradient: LinearGradient(
        colors: [Color(0xFF7E22CE), Color(0xFFB026FF), Color(0xFFD946EF)],
      ),
    ),
    ThemeVibe.imperialGold: VibePalette(
      label: 'Purple & Gold',
      bgCanvas: Color(0xFF08040C),
      bgSurface: Color(0xFF140A1E),
      bgElevated: Color(0xFF211030),
      borderSubtle: Color(0x30F59E0B),
      borderFocus: Color(0x73F59E0B),
      textMain: Color(0xFFFEFCE8),
      textMuted: Color(0xFFFDE68A),
      textDim: Color(0xFFD97706),
      accentPrimary: Color(0xFFF59E0B),
      accentGradient: LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFDE047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59F59E0B),
      sampleGradient: LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFDE047)],
      ),
    ),
    ThemeVibe.purpleOrange: VibePalette(
      label: 'Purple & Orange',
      bgCanvas: Color(0xFF12061A),
      bgSurface: Color(0xFF1F0A2C),
      bgElevated: Color(0xFF2F1042),
      borderSubtle: Color(0x30FF6B00),
      borderFocus: Color(0x73FF6B00),
      textMain: Color(0xFFFFF7ED),
      textMuted: Color(0xFFFED7AA),
      textDim: Color(0xFFEA580C),
      accentPrimary: Color(0xFFFF6B00),
      accentGradient: LinearGradient(
        colors: [Color(0xFF9333EA), Color(0xFFFF6B00), Color(0xFFFFAA00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59FF6B00),
      sampleGradient: LinearGradient(
        colors: [Color(0xFF9333EA), Color(0xFFFF6B00), Color(0xFFFFAA00)],
      ),
    ),
    ThemeVibe.cyberViolet: VibePalette(
      label: 'Cyber Violet',
      bgCanvas: Color(0xFF0D071E),
      bgSurface: Color(0xFF170D31),
      bgElevated: Color(0xFF231448),
      borderSubtle: Color(0x30D946EF),
      borderFocus: Color(0x73D946EF),
      textMain: Color(0xFFFAF5FF),
      textMuted: Color(0xFFF0ABFC),
      textDim: Color(0xFFA21CAF),
      accentPrimary: Color(0xFFD946EF),
      accentGradient: LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59D946EF),
      sampleGradient: LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFF06B6D4)],
      ),
    ),
    ThemeVibe.solarTangerine: VibePalette(
      label: 'Solar Tangerine',
      bgCanvas: Color(0xFF170B03),
      bgSurface: Color(0xFF261307),
      bgElevated: Color(0xFF381C0C),
      borderSubtle: Color(0x26FB923C),
      borderFocus: Color(0x59FB923C),
      textMain: Color(0xFFF0F6FC),
      textMuted: Color(0xFFFDBA74),
      textDim: Color(0xFFEA580C),
      accentPrimary: Color(0xFFFB923C),
      accentGradient: LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59FB923C),
      sampleGradient: LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
      ),
    ),
    ThemeVibe.sunsetAmber: VibePalette(
      label: 'Sunset Amber',
      bgCanvas: Color(0xFF180D0B),
      bgSurface: Color(0xFF251512),
      bgElevated: Color(0xFF351E1A),
      borderSubtle: Color(0x30F97316),
      borderFocus: Color(0x73F97316),
      textMain: Color(0xFFFFF7ED),
      textMuted: Color(0xFFFDBA74),
      textDim: Color(0xFFC2410C),
      accentPrimary: Color(0xFFF97316),
      accentGradient: LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB7185)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x59F97316),
      sampleGradient: LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB7185)],
      ),
    ),
    ThemeVibe.arcticFrost: VibePalette(
      label: 'Arctic Frost',
      bgCanvas: Color(0xFF070F1E),
      bgSurface: Color(0xFF0D192E),
      bgElevated: Color(0xFF152542),
      borderSubtle: Color(0x307DD3FC),
      borderFocus: Color(0x737DD3FC),
      textMain: Color(0xFFF8FAFC),
      textMuted: Color(0xFFBAE6FD),
      textDim: Color(0xFF0284C7),
      accentPrimary: Color(0xFF7DD3FC),
      accentGradient: LinearGradient(
        colors: [Color(0xFFE0F2FE), Color(0xFF7DD3FC), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x597DD3FC),
      sampleGradient: LinearGradient(
        colors: [Color(0xFFE0F2FE), Color(0xFF7DD3FC), Color(0xFF38BDF8)],
      ),
    ),
    ThemeVibe.emeraldCyan: VibePalette(
      label: 'Emerald Cyan',
      bgCanvas: Color(0xFF051311),
      bgSurface: Color(0xFF0B201D),
      bgElevated: Color(0xFF13302C),
      borderSubtle: Color(0x3010B981),
      borderFocus: Color(0x7310B981),
      textMain: Color(0xFFF0FDF4),
      textMuted: Color(0xFF6EE7B7),
      textDim: Color(0xFF059669),
      accentPrimary: Color(0xFF10B981),
      accentGradient: LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x5910B981),
      sampleGradient: LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF06B6D4)],
      ),
    ),
    ThemeVibe.minimalNordic: VibePalette(
      label: 'Nordic Slate',
      bgCanvas: Color(0xFF091319),
      bgSurface: Color(0xFF0F1F28),
      bgElevated: Color(0xFF162D3A),
      borderSubtle: Color(0x3038BDF8),
      borderFocus: Color(0x7338BDF8),
      textMain: Color(0xFFF0F9FF),
      textMuted: Color(0xFF7DD3FC),
      textDim: Color(0xFF0284C7),
      accentPrimary: Color(0xFF38BDF8),
      accentGradient: LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGlow: Color(0x5938BDF8),
      sampleGradient: LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
      ),
    ),
  };

  static String getFontFamilyName(AppFontStyle font) {
    switch (font) {
      case AppFontStyle.defaultSans:
        return 'sans-serif';
      case AppFontStyle.comicSans:
        return 'Comic Neue';
      case AppFontStyle.roundedBold:
        return 'Quicksand';
      case AppFontStyle.techMono:
        return 'Fira Code';
      case AppFontStyle.editorialSerif:
        return 'Lora';
    }
  }

  static String getFontLabel(AppFontStyle font) {
    switch (font) {
      case AppFontStyle.defaultSans:
        return 'Default Sans';
      case AppFontStyle.comicSans:
        return 'Comic Sans';
      case AppFontStyle.roundedBold:
        return 'Rounded Bold';
      case AppFontStyle.techMono:
        return 'Tech Mono';
      case AppFontStyle.editorialSerif:
        return 'Editorial Serif';
    }
  }

  static List<String> getFontFallbackList(AppFontStyle font) {
    switch (font) {
      case AppFontStyle.comicSans:
        return ['Comic Neue', 'Comic Sans MS', 'Comic Sans', 'sans-serif'];
      case AppFontStyle.roundedBold:
        return ['Quicksand', 'Arial Rounded MT Bold', 'sans-serif'];
      case AppFontStyle.techMono:
        return ['Fira Code', 'Cascadia Code', 'Consolas', 'monospace'];
      case AppFontStyle.editorialSerif:
        return ['Lora', 'Georgia', 'Cambria', 'serif'];
      case AppFontStyle.defaultSans:
        return ['sans-serif', 'Roboto', 'Noto Sans Arabic', 'Segoe UI'];
    }
  }

  static TextTheme createTextTheme(String fontFamily, List<String> fallback) {
    TextStyle applyFont(TextStyle? base) {
      return (base ?? const TextStyle()).copyWith(
        fontFamily: fontFamily,
        fontFamilyFallback: fallback,
      );
    }

    final base = ThemeData.dark().textTheme;
    return base.copyWith(
      displayLarge: applyFont(base.displayLarge),
      displayMedium: applyFont(base.displayMedium),
      displaySmall: applyFont(base.displaySmall),
      headlineLarge: applyFont(base.headlineLarge),
      headlineMedium: applyFont(base.headlineMedium),
      headlineSmall: applyFont(base.headlineSmall),
      titleLarge: applyFont(base.titleLarge),
      titleMedium: applyFont(base.titleMedium),
      titleSmall: applyFont(base.titleSmall),
      bodyLarge: applyFont(base.bodyLarge),
      bodyMedium: applyFont(base.bodyMedium),
      bodySmall: applyFont(base.bodySmall),
      labelLarge: applyFont(base.labelLarge),
      labelMedium: applyFont(base.labelMedium),
      labelSmall: applyFont(base.labelSmall),
    );
  }

  static ThemeData createTheme(ThemeVibe vibe, AppFontStyle font) {
    final palette = vibes[vibe] ?? vibes[ThemeVibe.deepAmethyst]!;
    final fontFamily = getFontFamilyName(font);
    final fallback = getFontFallbackList(font);
    final textTheme = createTextTheme(fontFamily, fallback);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.bgCanvas,
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      textTheme: textTheme,
      colorScheme: ColorScheme.dark(
        surface: palette.bgSurface,
        primary: palette.accentPrimary,
        secondary: palette.accentPrimary,
        onSurface: palette.textMain,
      ),
      cardTheme: CardThemeData(
        color: palette.bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.borderFocus),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textMain),
        titleTextStyle: TextStyle(
          color: palette.textMain,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
        ),
      ),
      useMaterial3: true,
    );
  }
}
