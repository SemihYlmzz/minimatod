import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Native platforms. Mobile (Android/iOS) uses the default factory; desktop
/// needs the FFI factory initialized.
void initDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
