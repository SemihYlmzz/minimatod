/// Configures the global sqflite `databaseFactory` for the current platform.
///
/// The real implementation is chosen at compile time:
/// - native (Android/iOS/desktop) → `db_init_io.dart`
/// - web → `db_init_web.dart`
///
/// This keeps `dart:io`/`dart:ffi` out of the web build and the web WASM
/// factory out of native builds, while the rest of the app uses one call.
library;

export 'db_init_io.dart' if (dart.library.html) 'db_init_web.dart';
