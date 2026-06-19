import 'package:flutter/material.dart';

import '../brand/brand.dart';

/// The user-selectable theme options. [auto] follows the system light/dark.
enum ThemeChoice { auto, light, dark, darkBlue }

/// Resolved theme configuration handed straight to [MaterialApp].
class ResolvedTheme {
  const ResolvedTheme({
    required this.theme,
    required this.darkTheme,
    required this.themeMode,
  });

  final ThemeData theme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;
}

/// Central theme factory. Keeps the monochrome look (light/dark) and adds a
/// navy "Dark Blue" variant. [resolve] maps a [ThemeChoice] onto the
/// `theme` / `darkTheme` / `themeMode` triple MaterialApp expects.
class AppThemes {
  const AppThemes._();

  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: Brand.ink,
      brightness: Brightness.light,
    ).copyWith(primary: Brand.ink, onPrimary: Brand.paper),
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: Brand.ink,
      brightness: Brightness.dark,
    ).copyWith(primary: Brand.paper, onPrimary: Brand.ink),
  );

  static final ThemeData darkBlue = _build(
    ColorScheme.fromSeed(
      seedColor: Brand.skyAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: Brand.skyAccent,
      onPrimary: Brand.navy,
      surface: Brand.navy,
      surfaceContainerHighest: Brand.navySurface,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }

  /// Maps the chosen option to the MaterialApp theme triple. For the explicit
  /// choices we force a single ThemeData via [ThemeMode]; [ThemeChoice.auto]
  /// follows the system between [light] and [dark].
  static ResolvedTheme resolve(ThemeChoice choice) {
    switch (choice) {
      case ThemeChoice.auto:
        return ResolvedTheme(
          theme: light,
          darkTheme: dark,
          themeMode: ThemeMode.system,
        );
      case ThemeChoice.light:
        return ResolvedTheme(
          theme: light,
          darkTheme: light,
          themeMode: ThemeMode.light,
        );
      case ThemeChoice.dark:
        return ResolvedTheme(
          theme: dark,
          darkTheme: dark,
          themeMode: ThemeMode.dark,
        );
      case ThemeChoice.darkBlue:
        return ResolvedTheme(
          theme: darkBlue,
          darkTheme: darkBlue,
          themeMode: ThemeMode.light,
        );
    }
  }
}
