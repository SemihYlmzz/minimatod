/// Platform helpers for turning a finished recording into bytes.
///
/// `record` writes to a file on native (a path) and to an in-memory blob on web
/// (a `blob:` URL). These two functions normalize that to raw bytes so the rest
/// of the audio code is platform-agnostic. Resolved at compile time, like
/// `core/database/db_init.dart`.
library;

export 'recording_io.dart' if (dart.library.html) 'recording_web.dart';
