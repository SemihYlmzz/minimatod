import '../note_model.dart';

/// The local-side contract the [SyncEngine] needs, kept separate from
/// [NotesRepository] (the app's CRUD surface) so the sync machinery is an
/// additive layer, not a burden every repository/mock must implement.
///
/// The concrete sqflite repository implements this alongside [NotesRepository];
/// tests provide a small fake.
abstract class SyncLocalStore {
  /// Every row with local changes not yet confirmed on the server — across
  /// *all* states, including archived and deleted tombstones (those must
  /// propagate too). See [Item.isDirty].
  Future<List<Item>> getPendingPush();

  /// Marks [items] as pushed by stamping each `syncedAt = updatedAt` for the
  /// exact `updatedAt` that was pushed. If a row changed again in the meantime
  /// its newer `updatedAt` leaves it dirty, so the next edit isn't lost.
  Future<void> markPushed(Iterable<Item> items);

  /// Applies one server row locally using last-write-wins: the incoming row is
  /// written (creating or overwriting the local one, including its tombstone
  /// state) only when the local copy is missing or older by `updatedAt`. The
  /// stored row is marked already-synced. Returns whether it was applied.
  Future<bool> applyRemote(Item incoming);
}
