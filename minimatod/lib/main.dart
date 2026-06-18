import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:minimatod/app.dart';
import 'package:minimatod/core/database/db_init.dart';
import 'package:minimatod/features/notes/data/notes_repository.dart';
import 'package:minimatod/features/notes/presentation/notes_controller.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the native splash on screen until the first data load completes,
  // so there's no white flash before the list appears.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Configure the SQLite backend for this platform (native/desktop/web).
  initDatabaseFactory();

  final repository = SqfliteNotesRepository();
  final controller = NotesController(repository);
  await controller.load();

  runApp(MinimatodApp(controller: controller));

  FlutterNativeSplash.remove();
}
