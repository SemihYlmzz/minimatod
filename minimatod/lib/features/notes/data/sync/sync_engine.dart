import 'remote_data_source.dart';
import 'sync_store.dart';

/// Outcome of one [SyncEngine.sync] pass.
class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});

  /// Number of local rows pushed to the server.
  final int pushed;

  /// Number of remote rows applied locally (after last-write-wins).
  final int pulled;

  bool get changedAnything => pushed > 0 || pulled > 0;
}

/// Orchestrates one offline-first sync between the [SyncLocalStore] and a
/// [RemoteDataSource]. Local is always the source of truth; conflicts resolve
/// last-write-wins on `updatedAt` (inside [SyncLocalStore.applyRemote]).
///
/// Pure orchestration — no Flutter, no storage details — so it is unit-tested
/// against fakes and works the same whatever the eventual transport is.
class SyncEngine {
  SyncEngine(this._local, this._remote);

  final SyncLocalStore _local;
  final RemoteDataSource _remote;

  /// Runs push-then-pull once.
  ///
  /// 1. Push every dirty local row, then mark those rows synced.
  /// 2. Pull remote rows changed since [since] and merge them last-write-wins.
  ///
  /// Push happens before pull so our own pending edits reach the server before
  /// we fold in others' — minimizing the window where a stale remote row could
  /// shadow a local change of equal age.
  Future<SyncResult> sync({DateTime? since}) async {
    final pending = await _local.getPendingPush();
    if (pending.isNotEmpty) {
      await _remote.push(pending);
      await _local.markPushed(pending);
    }

    final incoming = await _remote.pull(since);
    var applied = 0;
    for (final item in incoming) {
      if (await _local.applyRemote(item)) applied++;
    }

    return SyncResult(pushed: pending.length, pulled: applied);
  }
}
