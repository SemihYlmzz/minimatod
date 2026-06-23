import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:minimatod/app.dart';
import 'package:minimatod/core/database/app_database.dart';
import 'package:minimatod/core/database/db_init.dart';
import 'package:minimatod/core/notifications/notification_service.dart';
import 'package:minimatod/core/settings/app_settings_controller.dart';
import 'package:minimatod/features/attachments/data/attachments_repository.dart';
import 'package:minimatod/features/attachments/data/sqlite_blob_store.dart';
import 'package:minimatod/features/attachments/presentation/audio_controller.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';
import 'package:minimatod/features/reminders/presentation/reminder_controller.dart';
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

  // On web, stop the browser's long-press/right-click context menu from
  // interrupting the app's long-press drag (Samsung Internet, Safari, etc.).
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }

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

  // Reminder notifications. Init must not block/fail startup. Reuse the same
  // prefs so notification ids persist across launches.
  final notifications = NotificationService(prefs: prefs);
  try {
    await notifications.init();
  } catch (e, st) {
    debugPrint('Minimatod: notifications unavailable: $e\n$st');
  }
  // One shared database for every repository (items, attachments, …).
  final appDatabase = AppDatabase();
  final reminders = ReminderController(notifications: notifications);
  final audio = AudioController(
    attachments: SqfliteAttachmentsRepository(appDatabase),
    blobs: SqliteBlobStore(appDatabase),
  );
  final controller = NotesController(
    SqfliteNotesRepository(appDatabase),
    reminders: reminders,
    audio: audio,
  );

  // Load existing data, but NEVER let a slow/failed load trap the splash
  // forever (a real risk on web release builds). On error/timeout we still
  // start the app — the user sees an empty list, not a frozen splash.
  try {
    await controller.load().timeout(const Duration(seconds: 8));
    await audio.load();
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

  // Re-arm reminders once the UI is up (restores web timers after a reload and
  // is a harmless no-op for already-scheduled native notifications), then learn
  // the current notification permission so blocked-reminder warnings can show.
  unawaited(controller.rescheduleReminders().then((_) => reminders.refresh()));
}
