import 'package:flutter/painting.dart';

/// Brand palette — single source of truth for the logo, splash, icons and the
/// app's monochrome accent. Near-black "ink" + white "paper".
class Brand {
  const Brand._();

  /// Near-black background / tile / accent.
  static const Color ink = Color(0xFF0E0F12);

  /// White mark / foreground.
  static const Color paper = Color(0xFFFFFFFF);

  /// Hex strings (used by icon/splash generator configs).
  static const String inkHex = '#0E0F12';
}
