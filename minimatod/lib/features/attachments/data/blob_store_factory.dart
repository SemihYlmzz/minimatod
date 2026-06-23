/// Resolves the platform [BlobStore] at compile time — native filesystem vs the
/// web stub — mirroring `core/database/db_init.dart`. Import this for
/// `createBlobStore()`; import `blob_store.dart` for the [BlobStore] type.
library;

export 'blob_store_io.dart' if (dart.library.html) 'blob_store_web.dart';
