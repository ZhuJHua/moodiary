# moodiary_data: repository and state boundary conventions

Repositories and cross-feature controllers both live here, so this is where the get_it and riverpod channels meet. Write new code to these rules.

## Three rules

1. **get_it = the whole object graph.**
   - `MoodiaryDatabase` is opened and registered by the composition root's `AppModule.database` (preResolve); the path comes from there because this package does not know the file layout. Repositories are `@lazySingleton` with the **DB injected through the constructor** (`DiaryRepository(this._db)`); this package is a micro-package (`lib/injectable.dart`).
   - The schema source of truth is split by domain in `src/db/*_tables.drift`; named queries exist only for SQL the DSL cannot express (`diary.drift` — the FTS5 search itself is Dart, via `package:drift/extensions/fts5.dart`). Changes need build_runner.
   - **Migrations are drift's step-by-step kind**: every released schema is a snapshot in `drift_schemas/moodiary/drift_schema_vN.json` (committed, never edited by hand), `database.steps.dart` is generated from them, and `onUpgrade` is one `transaction()` around `m.runMigrationSteps(steps: migrationSteps(fromNToN+1: ...))`. Steps are written against `schema.*`, the frozen table shapes of that version, never the live tables.
   - To change the schema: edit the `.drift`, bump `schemaVersion`, run `dart tool/task.dart migrations`, write the new step, then `dart tool/task.dart build-runner`. `test/db_migration_test.dart` verifies every version path lands exactly on the next snapshot (the `逐档迁移` group) and seeds real rows through the generated `DatabaseAtVN` classes to check the data survived.
   - Always take dependencies with `getIt<XxxRepository>()`: classes inside the container (AutoSyncWatcher and the like) use constructor injection, while Riverpod Notifiers and widgets write `late final _repository = getIt<XxxRepository>()`, the `late` keeping a stubbed controller off the container. A consumer that really needs a second implementation defines a narrow port **on the consumer side** (`sync_stores.dart` in moodiary_sync) instead of port-ifying the whole repo.
   - Tests: repositories use `XxxRepository(MoodiaryDatabase.forTesting(NativeDatabase.memory(...)))` with `PRAGMA foreign_keys = ON` in setup, which cascade delete depends on; higher layers use `getIt.registerSingleton<XxxRepository>(double)` + `tearDown(getIt.reset)`, and the double may be mocktail's `Mock implements XxxRepository`.
2. **riverpod = read models tied to the UI lifecycle**, UI state only. Providers do not new up services, do not hold service instances, and there are no repository providers.
3. **Process-wide, cross-page mutable holders that outlive any screen** (OpenDiaryRegistry / SyncPendingTracker / SyncDirtyTracker / SyncCancellation) are `@singleton` and are also taken with `getIt<X>()`. Widgets exported across packages must not read global KV imperatively; use a provider, or lift the value into a constructor parameter supplied by the host. A widget's reactive channel is `ref.watch`.

## Hard facts

- **codegen providers are autoDispose by default**; keepAlive is the exception, currently `AppSettingsController` (holds the global theme settings) and `SyncController` (must keep sync progress across pages), whose reasons are recorded here, not in code comments. Always use codegen.
- The `key` column must be written `"key"`. The memories body column is `content`.
- Provider retry is turned **off entirely** in `mobile/lib/main.dart` with `ProviderScope(retry: (_, _) => null)`. Expected business failures throw an `Error` subclass (such as `StateError`), not an `Exception`.
- Provider definitions go in each package's `application/` (or the top of this package's src/), never in presentation.
- **Error convention: repositories throw, callers catch as needed and at least `logger.e`**, so a library failure never masquerades as an empty list. No TaskEither, because no consumer ever read a Left.

## Three shapes of change notification (pick by table, do not mix)

- **Large lists / paging / offsets that must track the DB** (Diary/Category/MediaInfo): typed domain events plus in-memory `applyXxxEvent` increments, no re-query. A subscription that receives an event while state is still loading must set a missed flag and re-query once after the first query (`LoadMoreMixin.markMissedEvent`). The 200ms debounce on aggregate consumers stays, only to save recomputing the aggregates — re-query is an index query. **Paging alignment contract**: the SQL `ORDER BY ..., id DESC` must match `diarySortComparator`'s field order field for field (id = uuid v7, ordered by creation time).
- **Small tables** (ChatSession/LlmProvider scale): a `Stream<void>` signal plus a full re-query; do not build event types and in-memory increments for them.
- **Following a single object**: subscribe to `diaryEvents` filtered by id (getDiary provider), because SQLite has no row-level watch and domain events are semantically stronger anyway.

## Write-path discipline

- **The FTS5 index is not written from Dart.** `diary_fts` is external content over `diaries` and three triggers (`diary_fts_ai/ad/au`) keep it in sync, so any write that touches the row indexes itself, inside whatever transaction it ran in. `diary_fts_au` carries a `WHEN old.title IS NOT new.title OR ...` guard because `_upsertRow` is a whole-row upsert: without it every `show` toggle would re-tokenize. Full rebuild is one statement, `INSERT INTO diary_fts(diary_fts) VALUES('rebuild')`.
- `updateADiary`'s `IndexMode` only governs **derived** data: `inline` rewrites backlinks and enqueues the embedding, `skip` (metadata-only changes to show / mood / category) leaves both alone.
- Bulk entry points (cloud pull / import) use `insertDiaries`: one transaction, and the triggers tokenize row by row inside it.
- User edits must bump `lastModified`; derived writes such as sync landing, migration and repair **must not** bump it and must carry `fromSync` on the event.
