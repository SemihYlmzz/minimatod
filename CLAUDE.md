# Minimatod

A minimalist notes + tasks app built as an infinitely-nestable tree. Flutter, offline-first, multi-platform. Bundle id `com.minimatod.app`.

**North-star:** one polished app per form factor — phone, tablet, web, desktop (macOS/Windows/Linux), and (eventually) smartwatch — all syncing through an upcoming first-party server. Every architectural decision should be judged against "does this still hold when the dataset is large, the UI is on 7 form factors, and edits arrive from another device?"

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
    database/     # sqflite factory, platform-conditional (io vs web)
    navigation/   # RouteStackObserver (multi-level jumps)
    notifications/# NotificationService (native + web fallback)
    responsive/   # breakpoints
    settings/     # AppSettingsController (theme + language, SharedPreferences)
    theme/ brand/ format/ widgets/
  features/
    notes/
      data/        # Item model + NotesRepository (the storage seam)
      presentation/
        notes_view.dart          # narrow/phone shell (push navigation)
        wide/                    # tablet/desktop 3-pane shell
        widgets/ search/ archive/
    onboarding/ settings/
  l10n/           # ARB files (en, tr) -> generated AppLocalizations
```

## Core conventions (follow these)

- **Immutability.** `Item` is immutable; derive copies with `copyWith` (uses a `_sentinel` to distinguish "leave unchanged" from "set null"). Never mutate model instances.
- **Repository pattern.** All storage goes through `NotesRepository` (abstract). UI/business code must depend on the interface, never on sqflite directly. This is the seam the sync layer will plug into — keep it clean.
- **Soft deletes / tombstones.** Rows are never physically removed. `deletedAt` (delete) and `archivedAt` (archive) are nullable timestamps; queries filter `... IS NULL`. This is deliberate sync groundwork — keep new state additive and reversible.
- **Schema migrations are additive.** Bump `_schemaVersion` in `notes_repository.dart` and add an `if (oldVersion < N)` block in `_migrate`. Never destructive, never reorder. (Currently v5.)
- **UUID ids.** Items use client-generated `uuid` v4 — offline-first friendly (no server round-trip to create).
- **Localize all user-facing strings.** Add to `lib/l10n/app_en.arb` + `app_tr.arb`, run `flutter gen-l10n`, use `AppLocalizations.of(context)`. (Known stragglers to fix: `'Start'`, `'Control your chaos.'`, the `'Reminder'` notification fallback.)
- **Platform-conditional imports** for anything touching `dart:io`/`dart:ffi`/`dart:html` (see `core/database/db_init.dart` `export ... if (dart.library.html) ...`). Keep web and native code paths separate this way.
- **Width-based responsive, not device-based.** `isWide(context)` keys off `MediaQuery.width` so it reacts to web/desktop window resizing. `AppShell` switches layouts on it.
- **Never let startup hang.** `main()` wraps prefs/notifications/initial-load in try/catch + an 8s timeout and always removes the splash. Preserve this resilience.

## Commands

- `flutter analyze lib` — must be clean before done.
- `flutter gen-l10n` — after editing ARB files (uses `l10n.yaml`; ignore its CLI-args note).
- `dart format <file>` — after structural edits.
- `make deploy-website` / `make deploy-webapp` (from repo root).
- Git: **main only, never auto-commit/push** (user preference).

## Known scalability debts (ranked) — read before large changes

The foundation is solid (clean seams, immutable model, sync-aware tombstones). But several things are cheap to fix now and exponentially expensive once the app is big and multi-platform. **Do not make these worse; prefer fixing the relevant one when you touch that area.**

### Tier 1 — structural, fix before the codebase grows

1. **`NotesController` reloads the entire tree on every mutation.** Every add/toggle/edit/archive/delete/reorder calls `await load()` → `getAll()` re-reads & re-parses the whole `items` table and rebuilds the full UI. O(n) per keystroke-level action; won't scale past a few hundred items.
   → Move to **granular in-memory updates**: keep `Map<String,Item>` + `Map<String?,List<Item>>` indexes, mutate the single changed item, notify. Reserve full reload for initial load / sync apply.
2. **O(n²) list rendering.** `descendantTaskCounts`, `pathTo`, `isDescendant` each rebuild a parent-map from scratch, and `descendantTaskCounts` is called **per row**. Memoize these (build indexes once per data version).
3. **No sync layer (the headline goal).** `NotesRepository` is local-only. Before the server lands, evolve it into: `LocalDataSource` (sqflite) + `RemoteDataSource` (server API) + a **sync engine** that reconciles them. Needed schema additions: a monotonic `revision`/version, a `dirty`/pending-push flag (or an outbox of ops), and `lastSyncedAt`. Policy: **offline-first, local is source of truth, last-write-wins on `updatedAt`** as the v1 conflict rule. The tombstones already support delete/archive propagation.
4. **No tests at all.** For a 7-platform + sync app this is the biggest practical risk. Add unit tests for the tree/domain logic (reparent cycle detection, reorder, descendant counts) and — once it exists — the **sync reconciliation** (offline edits, concurrent edits, delete-vs-edit races). Pure domain logic should be testable without Flutter.

### Tier 2 — needed as platforms/features expand

5. **State management ceiling.** One `ChangeNotifier` drives everything via `ListenableBuilder`, so any change rebuilds large subtrees with no selective scoping. As sync status, account/auth, and collaboration arrive, adopt **Riverpod** (fine-grained rebuilds, DI, async/family providers, easy mocking). The current controller is a god-object — split domain logic out of it.
6. **Platform-adaptive UI.** Everything is hardcoded Material (`AlertDialog`, `showModalBottomSheet`, Material buttons). "Perfect per platform" needs an adaptive layer (Cupertino feel on iOS/macOS, desktop density). Only two layouts exist behind a single 720px breakpoint — desktop and watch need their own shells, not just a wider phone.
7. **Desktop/keyboard support is absent.** No `Shortcuts`/`Actions`/`Focus` (Cmd+N, Cmd+F, arrow nav, Delete). Required for a credible macOS/Windows/Linux app.
8. **Notification id collision.** `NotificationService._idFor` = `itemId.hashCode & 0x7fffffff`. Hash collisions become real as item count grows (two items → one reminder clobbers the other). Use a dedicated stable int id (or persist a uuid→int map).

### Tier 3 — production hardening

9. **Config & flavors.** No env/config abstraction. Before wiring a server, add build flavors (dev/staging/prod) and an `AppConfig` (server URL, feature flags) instead of static constants in `AppInfo`.
10. **Error reporting seam.** Only `debugPrint`. Add a centralized reporter (Sentry/Crashlytics) — especially around sync.
11. **Reorder writes N rows in a loop** (`reorderGroup`) with no transaction, then full reload. Batch into one transaction.
12. **Smartwatch is realistically a separate thin client** (watchOS = native SwiftUI; Wear OS partial in Flutter) talking to the **same server API**. This reinforces Tier-1 #3: a clean, well-specified server contract + shared data model matters more than shared Flutter UI for the watch.

## Platform status

Live: Android, iOS, web. Configured but unshipped: desktop (notification init for macOS/Linux/Windows is present). Not started: smartwatch. See memory (`minimatod-store-status`) for store state.
