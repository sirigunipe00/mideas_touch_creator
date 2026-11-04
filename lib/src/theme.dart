import 'package:flutter/material.dart';

class AppColors {
  const AppColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primaryText,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryLight2,
    required this.line,
    required this.backdrop,
    required this.shadow,
  });

  final Color bg;
  final Color card;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primaryText;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryLight2;
  final Color line;
  final Color backdrop;
  final BoxShadow shadow;

  static const primaryGold = Color(0xFFEFBF05);
  static const ink = Color(0xFF1D1700);

  static const light = AppColors(
    bg: Color(0xFFFFFDF6),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF2A2410),
    muted: Color(0xFF7A7255),
    primary: primaryGold,
    primaryText: ink,
    primaryDark: Color(0xFF8A6A00),
    primaryLight: Color(0xFFFCF4D3),
    primaryLight2: Color(0xFFFAEAAC),
    line: Color(0xFFF1E6B8),
    backdrop: Color(0xFFE9E2C8),
    shadow: BoxShadow(
      color: Color(0x248A6A00),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  );

  static const dark = AppColors(
    bg: Color(0xFF15130B),
    card: Color(0xFF211E11),
    text: Color(0xFFF7F1D6),
    muted: Color(0xFFB3AA84),
    primary: primaryGold,
    primaryText: ink,
    primaryDark: Color(0xFFF6DA6F),
    primaryLight: Color(0xFF33290A),
    primaryLight2: Color(0xFF4A3C0C),
    line: Color(0xFF3A3413),
    backdrop: Color(0xFF0C0A04),
    shadow: BoxShadow(
      color: Color(0x73000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  );
}

class AppPalette extends InheritedWidget {
  const AppPalette({
    required this.colors,
    required this.isDark,
    required super.child,
    super.key,
  });

  final AppColors colors;
  final bool isDark;

  static AppColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppPalette>();
    assert(scope != null, 'AppPalette is missing above this widget');
    return scope!.colors;
  }

  static bool darkOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppPalette>();
    return scope?.isDark ?? false;
  }

  @override
  bool updateShouldNotify(AppPalette oldWidget) {
    return isDark != oldWidget.isDark || colors != oldWidget.colors;
  }
}

extension PaletteContext on BuildContext {
  AppColors get colors => AppPalette.of(this);
  bool get isDark => AppPalette.darkOf(this);
}

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryText,
      secondary: colors.primaryDark,
      onSecondary: colors.primaryText,
      error: const Color(0xFFED0707),
      onError: Colors.white,
      surface: colors.card,
      onSurface: colors.text,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.primaryLight2,
      thumbColor: colors.primary,
      overlayColor: colors.primary.withOpacity(0.16),
      trackHeight: 4,
    ),
  );
}
