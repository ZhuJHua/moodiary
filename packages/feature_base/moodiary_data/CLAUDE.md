# moodiary_data: repository and state boundary conventions

This package holds both the repositories and the cross-feature controllers, so it is the physical meeting point of the get_it and riverpod channels. Three rules plus hard facts. Write new code this way, do not reinvent.

## Three rules

1. **get_it = the whole object graph**. `MoodiaryDatabase` is opened and registered by the composition root's `AppModule.database` (preResolve; the path comes from the composition root because this package does not know the file layout), and repositories are `@lazySingleton` with the **DB injected through the constructor** (`DiaryRepository(this._db)`); this package is a micro-package (`lib/injectable.dart`). The schema source of truth is split by domain in `src/db/*_tables.drift`, named queries exist only for SQL the DSL cannot express (FTS5, `diary.drift`), and changes need build_runner. Always take dependencies with `getIt<XxxRepository>()`: classes inside the container (AutoSyncWatcher and the like) use constructor injection, while Riverpod Notifiers and widgets write `late final _repository = getIt<XxxRepository>()`, the `late` keeping a stubbed controller off the container. A consumer that really needs a second implementation defines a narrow port **on the consumer side** (`sync_stores.dart` in moodiary_sync), instead of port-ifying the whole repo. Tests: repositories use `XxxRepository(MoodiaryDatabase.forTesting(NativeDatabase.memory(...)))` with `PRAGMA foreign_keys = ON` in setup, which cascade delete depends on; higher layers use `getIt.registerSingleton<XxxRepository>(double)` + `tearDown(getIt.reset)`, and the double may be mocktail's `Mock implements XxxRepository`.
2. **riverpod = read models tied to the UI lifecycle**, UI state only. Providers do not new up services, do not hold service instances, and there are no repository providers.
3. **Process-wide, cross-page mutable holders that outlive any screen** (OpenDiaryRegistry / SyncPendingTracker / SyncDirtyTracker / SyncCancellation) are `@singleton` and are also taken with `getIt<X>()`. Widgets exported across packages must not read global KV imperatively, because that hangs correctness on how the host wraps them (swapping a KeyedSubtree key), a contract no type can hold; use a provider, or lift the value into a constructor parameter supplied by the host. A widget's reactive channel is `ref.watch`.

## Hard facts (get one wrong and you get a class of bugs)

- **codegen providers are autoDispose by default**; keepAlive is the exception, currently `AppSettingsController` (holds the global theme settings) and `SyncController` (must keep sync progress across pages), whose reasons are recorded here, not in code comments. **A hand-written `NotifierProvider` defaults the other way** (keepAlive), so always use codegen.
- **A SQL keyword collision makes drift swallow the column silently**: the `key` column must be written `"key"`. A column name colliding with a `Table` base member (such as `text`) is an outright compile error, which is why the memories body column is `content`.
- **riverpod 3 retries non-`Error` exceptions 10 times with backoff (about 38 seconds) by default**, and this repo turns it **off entirely** in `mobile/lib/main.dart` with `ProviderScope(retry: (_, _) => null)`. Expected business failures throw an `Error` subclass (such as `StateError`), not an `Exception`.
- Provider definitions go in each package's `application/` (or the top of this package's src/), never in presentation.
- **Error convention: repositories throw, callers catch as needed and at least `logger.e`**, so a library failure never masquerades as an empty list. No TaskEither, because no consumer ever read a Left.

## Three shapes of change notification (pick by table, do not mix)

- **Large lists / paging / offsets that must track the DB** (Diary/Category/MediaInfo): typed domain events plus in-memory `applyXxxEvent` increments, no re-query. A subscription that receives an event while state is still loading must set a missed flag and re-query once after the first query (`LoadMoreMixin.markMissedEvent`), or writes from the startup pull are silently lost. The 200ms debounce on aggregate consumers stays, now only to save recomputing the aggregates since re-query is an index query. **Paging alignment contract**: the SQL `ORDER BY ..., id DESC` must match `diarySortComparator`'s field order field for field (id = uuid v7, ordered by creation time).
- **Small tables** (ChatSession/LlmProvider scale): a `Stream<void>` signal plus a full re-query is the right fit, do not build event types and in-memory increments for them.
- **Following a single object**: subscribe to `diaryEvents` filtered by id (getDiary provider), because SQLite has no row-level watch and domain events are semantically stronger anyway.

## Write-path discipline

- `updateADiary`'s `IndexMode`: content/title touched → `inline` (tokenize first, then row + FTS + backlinks land **atomically in one transaction**; the SQLite era has no two-phase write and no reindex queue); **metadata-only changes to show / mood / category → `skip`**, because the index only takes content/title and show is filtered at query time.
- Bulk entry points (cloud pull / import) use `insertDiaries`: one tokenization pass for the batch (parallel across entries in Rust) plus a single transaction.
- User edits must bump `lastModified`; derived writes such as sync landing, migration and repair **must not** bump it and must carry `fromSync` on the event, or LWW drops the edit or uploads everything out of nowhere.
