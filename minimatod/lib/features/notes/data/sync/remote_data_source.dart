import '../note_model.dart';

/// The server side of sync — the *only* thing the upcoming backend has to
/// implement. Deliberately tiny and transport-agnostic (REST, gRPC, websocket…
/// all fit). The concrete client lands when the server API is specified.
abstract class RemoteDataSource {
  /// Server rows changed since [since] (null = full pull / first sync), each
  /// carrying its own state (active / archived / deleted tombstone) and
  /// `updatedAt` for last-write-wins merging.
  Future<List<Item>> pull(DateTime? since);

  /// Sends locally-changed [changes] to the server. Implementations should be
  /// idempotent (the same dirty row may be pushed again after a failure).
  Future<void> push(List<Item> changes);
}

/// A do-nothing remote used until the real server exists, so the app and the
/// [SyncEngine] can be wired up and tested without a backend. Pulls nothing,
/// drops pushes.
class NoopRemoteDataSource implements RemoteDataSource {
  const NoopRemoteDataSource();

  @override
  Future<List<Item>> pull(DateTime? since) async => const [];

  @override
  Future<void> push(List<Item> changes) async {}
}
