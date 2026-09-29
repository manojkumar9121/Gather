import 'package:flutter/material.dart';

/// Gather's palette. Deep ultramarine carries the app, warm gold is the single
/// accent, and off-white is the default text colour.
class GatherColors {
  const GatherColors._();

  static const ultramarine = Color(0xFF3A2FE0);
  static const ultramarineDeep = Color(0xFF241B9E);
  static const ultramarineInk = Color(0xFF171043);
  static const gold = Color(0xFFFFC83D);
  static const goldDeep = Color(0xFFE0A800);
  static const offWhite = Color(0xFFF4F2FF);
  static const muted = Color(0xFFB7B0E8);
  static const success = Color(0xFF3DD68C);
  static const danger = Color(0xFFFF6B6B);
}

/// Spacing scale. Everything is a multiple of 4.
class Gap {
  const Gap._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Minimum tappable edge. Large on purpose: the audience spans a wide age
/// range and attendees are often using this one-handed in a crowd.
const double kTapTarget = 56.0;

ThemeData buildGatherTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: GatherColors.ultramarine,
    brightness: Brightness.light,
  ).copyWith(
    primary: GatherColors.ultramarine,
    secondary: GatherColors.gold,
    onSecondary: GatherColors.ultramarineInk,
    surface: GatherColors.offWhite,
    error: GatherColors.danger,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: GatherColors.offWhite,
    textTheme: base.textTheme.apply(
      bodyColor: GatherColors.ultramarineInk,
      displayColor: GatherColors.ultramarineInk,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kTapTarget),
        side: const BorderSide(color: GatherColors.ultramarine, width: 2),
        foregroundColor: GatherColors.ultramarine,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GatherColors.muted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: GatherColors.muted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: GatherColors.ultramarine,
          width: 2,
        ),
      ),
    ),
  );
}

/// The dark stage used for voting and the reveal, so the countdown is the
/// loudest thing on screen when it matters.
const Color kStageBackground = GatherColors.ultramarineInk;
