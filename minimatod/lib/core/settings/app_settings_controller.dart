import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_themes.dart';

/// Language preference. [system] follows the device locale; the rest force a
/// specific app locale.
enum LanguageChoice { system, en, tr }

/// Holds the user's appearance + language preferences and persists them with
/// [SharedPreferences]. UI listens via [ChangeNotifier].
///
/// [_prefs] is nullable on purpose: if the platform plugin is unavailable
/// (e.g. a misbuilt web bundle), the controller still works with in-memory
/// defaults instead of bricking startup — persistence simply no-ops.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._prefs);

  static const _kTheme = 'settings.theme';
  static const _kLanguage = 'settings.language';

  final SharedPreferences? _prefs;

  ThemeChoice _theme = ThemeChoice.dark;
  LanguageChoice _language = LanguageChoice.system;

  ThemeChoice get theme => _theme;
  LanguageChoice get language => _language;

  /// The forced app locale, or null to follow the system.
  Locale? get locale => switch (_language) {
        LanguageChoice.system => null,
        LanguageChoice.en => const Locale('en'),
        LanguageChoice.tr => const Locale('tr'),
      };

  /// Reads persisted values. Defaults: dark theme, system language.
  void load() {
    final prefs = _prefs;
    if (prefs == null) return;
    final themeName = prefs.getString(_kTheme);
    if (themeName != null) {
      _theme = ThemeChoice.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => ThemeChoice.dark,
      );
    }
    final langName = prefs.getString(_kLanguage);
    if (langName != null) {
      _language = LanguageChoice.values.firstWhere(
        (l) => l.name == langName,
        orElse: () => LanguageChoice.system,
      );
    }
  }

  Future<void> setTheme(ThemeChoice choice) async {
    if (choice == _theme) return;
    _theme = choice;
    notifyListeners();
    await _prefs?.setString(_kTheme, choice.name);
  }

  Future<void> setLanguage(LanguageChoice choice) async {
    if (choice == _language) return;
    _language = choice;
    notifyListeners();
    await _prefs?.setString(_kLanguage, choice.name);
  }
}
