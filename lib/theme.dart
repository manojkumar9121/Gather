import 'package:flutter/material.dart';

/// Aurora Glass theme for Gather — Direction B from the design reference.
/// Near-black base with soft purple / blue aurora blooms, frosted glass cards,
/// gradient gold primary buttons with glow, and large rounded targets.
class GatherColors {
  const GatherColors._();

  // Aurora Glass palette (Theme B)
  static const auroraPurple = Color(0xFF8040FF);
  static const auroraBlue = Color(0xFF3A2FE0);
  static const auroraGold = Color(0xFFFFC83D);
  static const auroraGoldDeep = Color(0xFFF0A81E);
  static const blackBase = Color(0xFF06051A);
  static const blackSurface = Color(0xFF0A0830);
  static const frost = Color(0xFF0B0B1A);
  static const frostLight = Color(0xFF14132E);
  static const goldText = Color(0xFFFFF2D0);
  static const whiteText = Color(0xFFF4F2FF);
  static const mutedText = Color(0xFF9A97C0);
  static const goldBorder = Color(0xFFB88A1E);
  static const success = Color(0xFF3DD68C);
  static const danger = Color(0xFFFF6B6B);

  // Legacy aliases for Aurora Glass backward compatibility
  static const ultramarine = auroraBlue;
  static const ultramarineDeep = Color(0xFF241B9E);
  static const ultramarineInk = blackBase;
  static const gold = auroraGold;
  static const goldDeep = auroraGoldDeep;
  static const offWhite = whiteText;
  static const muted = mutedText;
}

/// Spacing scale — slightly larger for Aurora Glass.
class Gap {
  const Gap._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 18.0;
  static const lg = 28.0;
  static const xl = 36.0;
  static const xxl = 52.0;
}

const double kTapTarget = 58.0;

ThemeData buildGatherTheme() {
  // Aurora Glass color scheme: near-black with gold primary
  final scheme =
      ColorScheme.fromSeed(
        seedColor: GatherColors.auroraBlue,
        brightness: Brightness.dark,
      ).copyWith(
        primary: GatherColors.auroraBlue,
        secondary: GatherColors.auroraGold,
        onSecondary: GatherColors.blackBase,
        surface: GatherColors.blackSurface,
        error: GatherColors.danger,
        onSurface: GatherColors.whiteText,
      );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
  );

  return base.copyWith(
    scaffoldBackgroundColor: GatherColors.blackBase,
    // Frosted glass card surfaces for Aurora Glass
    cardTheme: CardThemeData(
      color: GatherColors.blackSurface.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: GatherColors.blackBase.withValues(alpha: 0.8),
      elevation: 8,
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: GatherColors.whiteText,
          displayColor: GatherColors.whiteText,
          fontFamily: 'Plus Jakarta Sans',
        )
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: GatherColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
    // Gradient gold primary buttons with glow shadow (Aurora Glass)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kTapTarget),
        backgroundColor: GatherColors.auroraGold,
        foregroundColor: GatherColors.blackBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        shadowColor: GatherColors.auroraGold.withValues(alpha: 0.6),
        elevation: 4,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    ),
    // Frosted glass outlined buttons for Aurora Glass
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kTapTarget),
        side: const BorderSide(color: Color(0x33FFFFFF), width: 1.5),
        foregroundColor: GatherColors.whiteText,
        backgroundColor: GatherColors.blackSurface.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    // Input styling — frosted glass fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GatherColors.blackSurface.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: const Color(0x22FFFFFF), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: const Color(0x22FFFFFF), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: GatherColors.auroraGold, width: 2),
      ),
    ),
    // App bar — transparent with frosted feel
    appBarTheme: AppBarTheme(
      backgroundColor: GatherColors.blackBase.withValues(alpha: 0.7),
      elevation: 0,
      foregroundColor: GatherColors.whiteText,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    // Bottom sheet background for organizer panel
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: GatherColors.blackBase.withValues(alpha: 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
  );
}

/// The dark aurora stage used for reveal moments (same dark theme).
const Color kStageBackground = GatherColors.blackBase;
