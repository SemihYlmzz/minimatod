# Minimatod

A minimalist notes + tasks app built as an infinitely-nestable tree. Flutter, offline-first, multi-platform. Bundle id `com.minimatod.app`.

**North-star:** one polished app per form factor — phone, tablet, web, desktop (macOS/Windows/Linux), and (eventually) smartwatch — all syncing through an upcoming first-party server. Every architectural decision should be judged against "does this still hold when the dataset is large, the UI is on 7 form factors, and edits arrive from another device?"

## Roadmap & release strategy (directional — versions will slip, the order won't)

The owner's plan, with my sequencing. **Treat the *order* and the *principles* as fixed; the version numbers as approximate.** The owner vibecodes (AI writes most code) and tests by hand, so the prime directive is: **never let the codebase become the thing that blocks the next feature.**

- **Pre-v2 — the feature wave (offline, single-device).** Land most of the product surface while it's cheap: password/locked notes, free-form canvas (paint-style), audio-recorded notes, richer archive, etc. Build each one **sync-ready** (Decision 3) even though sync ships at v2 — the data *shape* is the expensive thing to change later; the server is not.
- **v2.0.0 — server + authentication.** Implement the already-scaffolded sync against a real HTTP `RemoteDataSource`; accounts/auth; persist the pull watermark; paginate; tombstone GC. If the contract was frozen during the feature wave, this is "fill in the implementation," not "redesign."
- **v3.0.0 — desktop (macOS/Windows/Linux).** Scaffold runners, window management, the keyboard/shortcut/focus layer, real size-classes, adaptive (Cupertino/desktop) controls, web URL routing.
- **v4.0.0 — smartwatch.** A *native* thin client (watchOS SwiftUI / Wear OS) over the proven v2 server API — not shared Flutter UI.

**My one timing call:** do a small **foundation-hardening pass *before* the feature wave**, not after. Three cheap things make the wave safe to vibecode at any scale: (1) split the god-controller so feature #50 never touches feature #1; (2) add the out-of-row **attachments seam** (Decision 4) so canvas/audio have a home that won't blow up memory or sync; (3) the cheap data wins (composite index, drop `body` from list reads, batch reorder). Everything else waits for its version.

## Architectural decisions (the "never get stuck" charter)

The owner is dependency-averse, vibecodes solo, and values clean seams highly even though they hand-code little. Every decision below optimizes for **staying unblocked as the app grows to 100s of features × 4 platforms** — not purity. Bias: fewest dependencies; cleanest seams; make a decision *early* only when it's expensive to change later, otherwise defer it.

1. **State management — stay packageless (no Riverpod, for now).** The god-`ChangeNotifier` *will* be split — but into several small `ChangeNotifier`/`ValueNotifier`s by concern (notes, selection, sync-status, auth, reminder-permission), exposed via `InheritedNotifier`, rebuilds scoped with `ValueListenableBuilder`. 100% `flutter/widgets`, zero new deps. Riverpod's real wins (DI, scoping, `family`) are reproducible this way; its cost (boilerplate) is the cheap part when AI writes it; dependency-churn is the exact pain we're avoiding. Keep the split **Riverpod-shaped** so migration is mechanical *if* real-time collaboration ever forces it — reassess only then.
2. **No Clean-Architecture ceremony.** Keep the lightweight stack: feature-first folders + a pure domain core (`NoteTree`, `Item`) + the `NotesRepository` seam. Do **not** add use-case/entity/DTO-mapping layers — for a solo vibecoded app that's navigation overhead with no payoff. The only domain work that matters: keep logic **out of the god-controller**, in small pure/testable classes.
3. **Every pre-v2 feature is built "sync-ready."** The server is deferred; the *data shape* is not. Before building a feature, answer: how does its row/blob **sync and merge** under last-write-wins? Bake the answer in now (free); don't retrofit it onto 100 features at v2 (the classic "stuck" moment).
4. **Large binary data lives out-of-row.** ✅ **Built + shipped (audio notes, v1.4.0).** `Attachment` model + `attachments` metadata table + `AttachmentsRepository`; a content-addressed `BlobStore` (sha-256). The wired blob store is **`SqliteBlobStore`** — bytes in a dedicated `blobs` table (schema v9), the **same on native and web** (no filesystem/OPFS interop), fetched by hash on demand so the board never loads them. `AudioController` (`features/attachments/presentation/`) records via `record`, plays via `just_audio` (bytes → `StreamAudioSource`), exposed to the note detail as `controller.audio`. `FileBlobStore` (filesystem) + the conditional factory remain for native large-file use later. ⚠️ Web trade-off: `sqflite_common_ffi_web` holds the DB in memory, so this fits voice memos; move bytes to **OPFS** if web audio ever gets large. ◐ Remaining: the blob half of **sync** (hash-keyed upload/download; metadata rows already carry `syncedAt`/`deletedAt`).
5. **Locked/password notes encrypt client-side; the server only ever sees ciphertext.** Decide the shape when you build it (pre-v2): the row carries ciphertext + nonce; the key derives from a user passphrase and is **never synced**. Auth is v2, but the encrypted shape must be right when the feature lands so it syncs unchanged.
6. **`AppConfig` + dev/staging/prod flavors before any server wiring.** Server URL and feature flags come from config, never hardcoded. Cheap; required before v2.
7. **Definition of done for every new feature (the anti-stuck checklist).** Immutable model + `copyWith`; all storage via `NotesRepository` (never sqflite in UI); additive migration only (bump `_schemaVersion` + `if (oldVersion < N)` block); **sync-shape decided** (#3); binaries out-of-row (#4); user-facing strings localized (en+tr → `flutter gen-l10n`); pure logic in a testable class with a unit test; UI through the adaptive layer once it exists; **no new package** without a one-line "this removes real, recurring pain" justification.

## Repo layout

```
minimatod/        # the Flutter app (all Dart code lives here)
website/          # marketing site (separate deploy)
store_play/       # Play Store assets
store_screenshots/
Makefile          # make deploy-website / deploy-webapp
```

App code structure (feature-first):

```
lib/
  core/           # cross-feature infrastructure
    database/     # AppDatabase (shared opener + schema/migrations) + sqflite factory, platform-conditional (io vs web)
    navigation/   # RouteStackObserver (multi-level jumps)
    notifications/# NotificationService (native + web fallback)
    responsive/   # breakpoints
    settings/     # AppSettingsController (theme + language, SharedPreferences)
    theme/ brand/ format/ widgets/
  features/
    notes/                       # the item tree itself (notes + tasks) — the core feature
      data/        # Item model, NoteTree (pure), NotesRepository; sync/ (offline-first engine)
      presentation/
        app_shell.dart           # entry — picks narrow vs wide by width
        notes_controller.dart    # the feature's state (ChangeNotifier)
        narrow/                  # phone push-nav shell (notes_view)
        wide/                    # tablet/desktop 3-pane shell
        composer/                # the create/edit sheet
        widgets/ search/ archive/
    reminders/                   # scheduling + permission badges — knows NOTHING about notes
      presentation/              # ReminderController (generic id/title/when scheduler) + reminder_help (badges)
    attachments/                 # out-of-row blobs for canvas/audio/images (no code dep on notes; FK only)
      data/                      # Attachment model, AttachmentsRepository, content-addressed BlobStore
    onboarding/ settings/
  l10n/           # ARB files (en, tr) -> generated AppLocalizations
```

## Core conventions (follow these)

- **Immutability.** `Item` is immutable; derive copies with `copyWith` (uses a `_sentinel` to distinguish "leave unchanged" from "set null"). Never mutate model instances.
- **Repository pattern.** All storage goes through `NotesRepository` (abstract). UI/business code must depend on the interface, never on sqflite directly. This is the seam the sync layer will plug into — keep it clean.
- **Soft deletes / tombstones.** Rows are never physically removed. `deletedAt` (delete) and `archivedAt` (archive) are nullable timestamps; queries filter `... IS NULL`. This is deliberate sync groundwork — keep new state additive and reversible.
- **Schema migrations are additive.** All tables live in one DB owned by `core/database/app_database.dart` (`AppDatabase`); repositories never open their own connection — they take the shared `AppDatabase`. Bump `schemaVersion` there and add an `if (oldVersion < N)` block in `_migrate`. Never destructive, never reorder. (Currently **v9**: v1–v7 shaped `items`, v8 added `attachments` metadata, v9 added the `blobs` byte store.)
- **UUID ids.** Items use client-generated `uuid` v4 — offline-first friendly (no server round-trip to create).
- **Localize all user-facing strings.** Add to `lib/l10n/app_en.arb` + `app_tr.arb`, run `flutter gen-l10n`, use `AppLocalizations.of(context)`. (Known stragglers to fix: `'Start'`, `'Control your chaos.'`, the `'Reminder'` notification fallback.)
- **Platform-conditional imports** for anything touching `dart:io`/`dart:ffi`/`dart:html` (see `core/database/db_init.dart` `export ... if (dart.library.html) ...`). Keep web and native code paths separate this way.
- **Width-based responsive, not device-based.** `isWide(context)` keys off `MediaQuery.width` so it reacts to web/desktop window resizing. `AppShell` switches layouts on it.
- **Never let startup hang.** `main()` wraps prefs/notifications/initial-load in try/catch + an 8s timeout and always removes the splash. Preserve this resilience.

## Commands

- `flutter analyze lib` — must be clean before done.
- `flutter test` — unit tests (pure domain + controller). Keep green.
- `flutter gen-l10n` — after editing ARB files (uses `l10n.yaml`; ignore its CLI-args note).
- `dart format <file>` — after structural edits.
- `make deploy-website` / `make deploy-webapp` (from repo root).
- Git: **main only, never auto-commit/push** (user preference).

## Known scalability debts (ranked) — read before large changes

The foundation is solid (clean seams, immutable model, sync-aware tombstones). But several things are cheap to fix now and exponentially expensive once the app is big and multi-platform. **Do not make these worse; prefer fixing the relevant one when you touch that area.**

### Tier 1 — structural, fix before the codebase grows

1. ✅ **DONE — granular in-memory updates.** `NotesController` no longer reloads the whole tree per mutation: `_byId` is the in-memory source of truth, mutations persist the one changed row and update `_byId` locally + notify. `load()` is reserved for startup / archive-restore / (future) sync apply. _(Per-mutation cost is now O(1), but the **whole active board is still fully resident in RAM** — incl. every note `body`, and double-indexed by `NoteTree`. That's the next data-scale ceiling: see the **2026-06-22 audit → "Data scale at rest"** below.)_
2. ✅ **DONE — memoized index.** Read algorithms are delegated to the pure `NoteTree` (`features/notes/data/note_tree.dart`), rebuilt lazily once per `_generation` (no per-row index rebuilds).
3. ◐ **SCAFFOLDED — sync layer (the headline goal).** The offline-first, last-write-wins machinery exists and is tested against fakes, with the runtime unchanged (nothing calls `sync()` yet):
   - `Item.syncedAt` + `Item.isDirty` (dirty = `syncedAt == null || syncedAt < updatedAt`). Every mutation already bumps `updatedAt`, so edits self-mark dirty — no per-mutation plumbing. Schema v6 added `synced_at`.
   - Seams in `features/notes/data/sync/`: `RemoteDataSource` (pull/push — the only thing the server implements) + `NoopRemoteDataSource`; `SyncLocalStore` (getPendingPush / markPushed / applyRemote), implemented by `SqfliteNotesRepository`; `SyncEngine.sync()` = push dirty → markPushed → pull → LWW merge. Tombstones (`deletedAt`/`archivedAt`) propagate because pending-push spans all states. `NoteTree` is pure, so server/watch can reuse the tree logic.
   - **Deferred until the server API is specified:** the concrete HTTP `RemoteDataSource`; persisting the pull high-water-mark (`lastSyncedAt`, e.g. in prefs) to pass as `since`; a sync trigger (on launch / interval / post-mutation); and auth/account. LWW-on-`updatedAt` is the assumed v1 conflict policy — revisit if you need per-field merge or an op-log.
4. ◐ **STARTED — tests.** `test/note_tree_test.dart` (pure tree logic), `test/notes_controller_test.dart` (mutations via an in-memory `FakeNotesRepository`), and `test/notes_repository_test.dart` (the **real** `SqfliteNotesRepository` against an in-memory SQLite db via the already-present `sqflite_common_ffi` — schema, visibility filters, subtree cascade, batch writes, sync LWW) exist and are green (39 tests). Still to add when built: **sync reconciliation** tests (offline edits, concurrent edits, delete-vs-edit races).

### Tier 2 — needed as platforms/features expand

5. ◐ **STARTED — splitting the god-controller (packageless; see charter Decision 1 — *not* Riverpod).** First split landed as its **own feature** `features/reminders/`: `ReminderController` owns scheduling + notification-permission state and is **note-independent** (a generic `(id, title, when)` scheduler); the Item→reminder rule stays in `NotesController`, which holds the controller, exposes it as `controller.reminders`, and re-emits its changes (`reminders?.addListener(notifyListeners)`) so badges stay live. This is the **template** — each future concern (canvas, audio, sync status, auth) gets its own small `ChangeNotifier`, in its own feature, wired the same way (via `InheritedNotifier` once prop-drilling bites). Still to do: pull more domain logic out of `NotesController`. (The high-frequency **rebuild scoping** — note autosave — is already fixed; see the audit.)
6. **Platform-adaptive UI.** Everything is hardcoded Material (`AlertDialog`, `showModalBottomSheet`, Material buttons). "Perfect per platform" needs an adaptive layer (Cupertino feel on iOS/macOS, desktop density). Only two layouts exist behind a single 720px breakpoint — desktop and watch need their own shells, not just a wider phone.
7. **Desktop/keyboard support is absent.** No `Shortcuts`/`Actions`/`Focus` (Cmd+N, Cmd+F, arrow nav, Delete). Required for a credible macOS/Windows/Linux app.
8. ✅ **DONE — notification id collision.** Replaced `itemId.hashCode` with `NotificationIdStore` (`core/notifications/`): a persisted (SharedPreferences) uuid→sequential-int map, collision-free and stable across launches. Tested in `test/notification_id_store_test.dart`. (One-time upgrade note: native reminders scheduled under the old hashCode ids aren't cancellable by the new ids, so a pre-existing pending reminder could double-fire once after upgrade. Negligible at current closed-test scale; if it matters, gate a one-time `_plugin.cancelAll()` behind a migration flag before `rescheduleAll`.)

### Tier 3 — production hardening

9. **Config & flavors.** No env/config abstraction. Before wiring a server, add build flavors (dev/staging/prod) and an `AppConfig` (server URL, feature flags) instead of static constants in `AppInfo`.
10. **Error reporting seam.** Only `debugPrint`. Add a centralized reporter (Sentry/Crashlytics) — especially around sync.
11. ✅ **DONE — reorder batched.** `reorderGroup` collects the changed rows and persists them via `NotesRepository.updateMany` in **one transaction** (no more N awaited writes, no reload, one rebuild). Fractional ranking (see the audit) is the remaining, larger improvement.
12. **Smartwatch is realistically a separate thin client** (watchOS = native SwiftUI; Wear OS partial in Flutter) talking to the **same server API**. This reinforces Tier-1 #3: a clean, well-specified server contract + shared data model matters more than shared Flutter UI for the watch.

## 2026-06-22 audit — additional scalability findings (slot into the tiers above)

A fresh multi-platform audit (parallel data/sync + UI agents, claims verified against the tree) surfaced these on top of the ranked list. `[T1/T2/T3]` tags map each into the tiers; fix the relevant one when you touch that area. These are **additive to** items 1–12, not replacements.

### Data scale at rest — the biggest unlogged gap
- **[T1] The whole active board is resident in RAM, incl. every `body`, and double-indexed.** `load()`→`getAll()` (`notes_repository.dart:148`) pulls all active rows into `_byId` (`notes_controller.dart:128`), then `_tree` builds a *second* `_byId` + `_childrenSorted` (`note_tree.dart:16`). Long-form `body` is loaded for every row though it's only shown on an open note. Memory + startup-parse cost is O(total active items), independent of what's on screen → **breaks watch first, then web**. Fixes cheap→deep: (a) **drop `body` from list-path projections** (`getAll`/`getChildren` select all *except* body; load it lazily via `getById` when the note opens) — biggest cheap win; (b) move to **demand-paged reads** via the already-indexed `getChildren(parentId)` + an LRU of visited levels, retiring the "everything in `_byId`" invariant; (c) compute `descendantTaskCounts` in SQL (**recursive CTE**) so paging doesn't need the whole tree resident.
- **[T1] SQLite read scaling.** ✅ **Composite covering index landed** — `idx_items_children (parent_id, archived_at, deleted_at, sort_order, created_at)`, schema **v7** (replaced the standalone `parent_id`/`deleted_at` indexes), so the hot child read is one index range scan with no temp sort. ◐ Still pending: `delete`/`_setArchived` walk the subtree with **one query per node + per-row updates in a loop** — replace with a recursive CTE + single `UPDATE … WHERE id IN (cte)`.
- **[T1] Search is an O(n) in-memory scan per keystroke** (`item_search_delegate.dart:9` `searchItems`: `.where(content/body.toLowerCase().contains)` over all of `_byId`). Two `toLowerCase()` allocations per item per keystroke on the UI thread, and it can only ever find *resident* items (incompatible with paging). Move to **SQLite FTS5** (virtual table mirroring `content`+`body`, kept in sync on add/update; query `MATCH … LIMIT`).

### Sync contract — decide these before the server ships (extends Tier-1 #3)
- **Bake pagination/batching into the `RemoteDataSource` contract now.** `getPendingPush` (`notes_repository.dart:305`) and `pull(since)` move the whole dataset in one shot; the first sync (all `synced_at` NULL by design) pushes the **entire table incl. bodies + tombstones** in one `push()`. Make `pull` return *page + opaque cursor* and `push` send **bounded batches** (mark each batch pushed before the next, so a failure resumes instead of restarting). Changing the wire contract after a server exists is the expensive part.
- **Tombstone retention/GC is a protocol decision, not later cleanup.** Soft-deletes are permanent today; over a long-lived account the table fills with dead rows that bloat reads, every index, and every full pull. Define a **purge horizon** (e.g. confirmed-synced AND older than 30–90d, longer than any device stays offline) the server can also broadcast so clients converge.
- **LWW is whole-row + wall-clock.** `applyRemote` (`notes_repository.dart:333`) compares raw `updatedAt` then `ConflictAlgorithm.replace`s the whole row → concurrent edits to *different fields* clobber, and clock skew can let a stale edit win. OK for v1, but **leave room**: add a server-assigned version field to `Item`'s wire shape (additive) rather than hard-baking raw client `updatedAt` as the only ordering authority.
- **`sort_order` is a dense integer reindex** (`reorderGroup` rewrites every sibling, dirtying them all for sync). Move to **fractional/lexical ranking** (LexoRank-style) so a move changes one row. Meanwhile batch the writes (Tier-3 #11).

### Multi-platform UI / input (sharpens #5–#7, + corrections)
- **CORRECTION: desktop is NOT scaffolded.** Only `android/ios/web` runner projects exist; the macOS/Windows/Linux branches in `db_init_io.dart` / `notification_service.dart` are currently **dead code**. No `window_manager`/`go_router`/`riverpod` deps. Shipping desktop = `flutter create --platforms=macos,windows,linux .`, then `window_manager` (**min window size ≥ `kWideBreakpoint`** so a narrow drag doesn't drop into the touch phone layout; restore bounds) + a `PlatformMenuBar` wiring the keyboard intents.
- **[T2] Responsive is a single `bool isWide` at 720px** plus one buried second threshold (`wide_home_shell.dart:169`, `width >= 900`). The wide layout is a *stretched tablet* — no desktop tier, **no `kPaneMaxWidth` clamp** (columns stretch unbounded on big monitors; contrast the phone path's `kContentMaxWidth`), and a watch (<410px) falls into the phone path. Replace the bool with a **`WindowSizeClass {watch,compact,medium,expanded,large}`** enum in `breakpoints.dart`; `AppShell` picks a shell *per class* (new `watch/`, `desktop/` shells beside `wide/`). Consider first-party `flutter_adaptive_scaffold`.
- **[T2] Rebuild scoping — high-frequency case ✅ fixed.** The note autosave (`setBody`) no longer notifies, so typing a note body no longer rebuilds the 3-pane wide layout or re-runs the list's task counts: the body isn't shown in any list, the editor owns its own text, and `NotePane` resolves its item via O(1) `itemById`. Locked by a test (`setBody … without notifying`). ◐ Remaining (low-priority): the single `ListenableBuilder` at `wide_home_shell.dart:158` still rebuilds all three panes on *discrete* changes (toggle/add/archive) — fine at their low frequency. True per-pane selective scoping needs the multi-notifier infrastructure (#5); add it only if a discrete action ever feels heavy. Packageless per Decision 1 — not Riverpod.
- **[T2] Web has no URL routing / deep-linking.** Whole tree lives at `/`; wide-layout selection isn't a route, so browser Back/Forward and bookmarking are dead and refresh always lands at root. Adopt `go_router` with `/i/:itemId` and make the wide shell's `_selectedId` a **route param**, so phone-push and wide-select converge on one source of truth (pairs with a Riverpod `selectedItemProvider`).
- **[T3] Per-platform polish:** Material-only, no Cupertino/`.adaptive` for iOS/macOS feel → thin `core/adaptive/` layer routing the existing `showDialog`/`showModalBottomSheet` sites. Fixed `fontSize` literals + fixed-height rows won't survive large text-scale → drive sizes from `Theme.textTheme`. RTL unexercised (directional `LTRB`/`centerLeft`/`Positioned(left:)` literals) → `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`. Right-click globally disabled on web (`main.dart`) with no replacement → `onSecondaryTapDown` context menus reusing `showItemActionsSheet`. Item levels use `ListView(children:)` (builds all rows up front) → `ListView.builder`/slivers.
- **Watch:** the cross-platform contract already exists in skeleton — `RemoteDataSource` pull/push + the flat `Item` JSON (`toMap`/`fromMap`) + the pure `NoteTree`. Keep the watch a **native thin client** (watchOS SwiftUI / Wear OS) speaking that protocol; **publish the `Item` schema + server API as a language-neutral spec** (OpenAPI/JSON Schema or protobuf) so native clients bind to a spec, not Dart classes. (Reinforces #12; no Flutter UI sharing needed.)

## Platform status

Live: Android, iOS, web (only these three runner projects exist). Desktop (macOS/Windows/Linux): **not scaffolded** — no runner projects yet; only the macOS/Linux/Windows branches in `notification_service`/`db_init_io` exist as currently-dead code paths. Enable with `flutter create --platforms=macos,windows,linux .`. Smartwatch: not started (planned as a native thin client over the server API). See memory (`minimatod-store-status`) for store state.
