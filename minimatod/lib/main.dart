import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:minimatod/app.dart';
import 'package:minimatod/core/database/db_init.dart';
import 'package:minimatod/core/settings/app_settings_controller.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dev flag: set true to replay the onboarding on every launch. When false,
/// onboarding shows once (until the user taps Start) then is remembered.
const bool kShowOnboarding = false;

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the native splash on screen until the first data load completes,
  // so there's no white flash before the list appears.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await initializeDateFormatting(); // locale-aware "created at" dates

  // Load persisted appearance / language preferences. Never let a plugin
  // failure (e.g. a misbuilt web bundle) brick startup — fall back to
  // in-memory defaults so the app still renders.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e, st) {
    debugPrint('Minimatod: SharedPreferences unavailable: $e\n$st');
  }
  final settings = AppSettingsController(prefs)..load();

  // Configure the SQLite backend for this platform (native/desktop/web).
  initDatabaseFactory();
  final controller = NotesController(SqfliteNotesRepository());

  // Load existing data, but NEVER let a slow/failed load trap the splash
  // forever (a real risk on web release builds). On error/timeout we still
  // start the app — the user sees an empty list, not a frozen splash.
  try {
    await controller.load().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('Minimatod: initial load failed: $e\n$st');
  }

  runApp(
    MinimatodApp(
      controller: controller,
      settings: settings,
      showOnboarding: kShowOnboarding,
    ),
  );

  // Always remove the splash, even if the load above failed.
  FlutterNativeSplash.remove();
}
