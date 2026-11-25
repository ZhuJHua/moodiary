# moodiary_data: repository and state boundary conventions

## Three rules

1. **Riverpod owns the database and repositories.** In `lib/src/database_provider.dart`, the keepAlive FutureProvider `moodiaryDatabaseAsyncProvider` opens and owns the database; `moodiaryDatabaseProvider` exposes its synchronous `requireValue` after startup. In `lib/src/data_providers.dart`, `@Riverpod(keepAlive: true)` repository providers such as `diaryRepositoryProvider` watch the database and inject it through constructors. Define narrow ports on the consumer side when a second implementation is needed.
2. **Give cross-page state the right lifetime.** `openDiaryRegistryProvider`, `syncPendingStateProvider` and `syncDirtyDiaryIdsProvider` are keepAlive providers/notifiers in the app scope. Widgets watch providers or receive values from the host; do not read global KV imperatively in a shared widget.
3. **Place providers with their responsibility.** Infrastructure, database, repository, service and cross-feature domain providers belong in `data/`, `application/` or directly under `src/`. Page controllers and view-local state belong in `presentation/` or `application/`.

## Schema and migrations

   - The schema source of truth is split by domain in `src/db/*_tables.drift`; named queries exist only for SQL the DSL cannot express (`diary.drift` — the FTS5 search itself is Dart, via `package:drift/extensions/fts5.dart`). Changes need build_runner.
   - **Migrations are drift's step-by-step kind**: every released schema is a snapshot in `drift_schemas/moodiary/drift_schema_vN.json` (committed, never edited by hand), `database.steps.dart` is generated from them, and `onUpgrade` is one `transaction()` around `m.runMigrationSteps(steps: migrationSteps(fromNToN+1: ...))`. Steps are written against `schema.*`, the frozen table shapes of that version, never the live tables.
   - To change the schema: edit the `.drift`, bump `schemaVersion` only if the latest release tag already ships the current one (otherwise fold the change into the unreleased step and regenerate its snapshot), run `fvm dart tool/task.dart migrations`, write the new step, then `fvm dart tool/task.dart build-runner`. Remove the generated `test/drift/moodiary/migration_test.dart` scaffold; `test/db_migration_test.dart` verifies every version path lands exactly on the next snapshot and seeds real rows through the generated `DatabaseAtVN` classes to check the data survived.
   - Triggers are in neither the versioned schema nor the generated test schemas: the verifier never compares them and a snapshot-built test database has none. So only the latest step may `m.create` the live `diaryFtsXx` triggers; an older step creates its own version's triggers from frozen SQL, and a step that replaces triggers drops them with `IF EXISTS`.

## Hard facts

- Generated providers auto-dispose by default. Use keepAlive for app-lifetime resources; register cleanup with `ref.onDispose`.
- Capture `final operationRef = ref;` before an `await`. Check `operationRef.mounted` before using the result; in `LoadMoreMixin`, check again after reading `state`, since that read can flush a rebuild.
- Test repositories directly with `XxxRepository(MoodiaryDatabase.forTesting(NativeDatabase.memory(...)))`; enable `PRAGMA foreign_keys = ON` for cascades. Above repositories, use `ProviderContainer.test(retry: (_, _) => null, overrides: [...])` with provider overrides.
- The `key` column must be written `"key"`. The memories body column is `content`.
- Automatic provider retry is off in `mobile/lib/main.dart` (`retry: (_, _) => null`); surface failures rather than relying on a provider rebuild to repeat an operation.
- **Error convention: repositories throw, callers catch as needed and at least `logger.e`**, so a library failure never masquerades as an empty list. No TaskEither, because no consumer ever read a Left.

## Three shapes of change notification (pick by table, do not mix)

- **Large lists / paging / offsets that must track the DB** (Diary/Category): typed domain events plus in-memory `applyXxxEvent` increments, no re-query. A subscription that receives an event while state is still loading must set a missed flag and re-query once after the first query (`LoadMoreMixin.markMissedEvent`). The 200ms debounce on aggregate consumers stays, only to save recomputing the aggregates — re-query is an index query. **Paging alignment contract**: the SQL `ORDER BY ..., id DESC` must match `diarySortComparator`'s field order field for field (id = uuid v7, ordered by creation time).
- **Small tables** (ChatSession/LlmProvider scale): a `Stream<void>` signal plus a full re-query; do not build event types and in-memory increments for them.
- **Following a single object**: subscribe to `diaryEvents` filtered by id (EditController), because SQLite has no row-level watch and domain events are semantically stronger anyway.

## Write-path discipline

- **The FTS5 index is not written from Dart.** `diary_fts` is external content over `diaries` and three triggers (`diary_fts_ai/ad/au`) keep it in sync, so any write that touches the row indexes itself, inside whatever transaction it ran in. `diary_fts_au` carries a `WHEN old.title IS NOT new.title OR ...` guard because `_upsertRow` is a whole-row upsert: without it every `show` toggle would re-tokenize. Full rebuild is one statement, `INSERT INTO diary_fts(diary_fts) VALUES('rebuild')`.
- The tokenizer is **not in this repo**: [`sqlite3_simple`](https://github.com/ZhuJHua/sqlite3_simple), our fork of [wangfenjin/simple](https://github.com/wangfenjin/simple) rebuilt as a pure Dart package that compiles the C++ sources through a build hook, pinned by commit sha, not published to pub. An FTS5 tokenizer has to be a C-ABI loadable extension (`fts5_api` is only reachable through `SELECT fts5(?1)` + `sqlite3_bind_pointer` from inside one).
- `loadSimpleExtension(jiebaDictDir: ...)` runs in `MoodiaryDatabase.open` (and `installJiebaDict()` in `.forTesting`) before any connection is created; the `sqlite3_auto_extension` registration and the dictionary path are process-level native state, so one call covers the background isolate and every connection in `readPool`. **The dictionary install is not optional.**
- Han text is indexed per character with pinyin variants as colocated tokens, which lets full pinyin and initials match Chinese words. Queries go through `jieba_query(text)`, which returns a finished MATCH expression — word phrases for Han, pinyin candidate groups for latin, **AND between terms**.
- `updateADiary`'s `IndexMode` only governs **derived** data: `inline` rewrites backlinks and enqueues the embedding, `skip` (metadata-only changes to show / mood / category) leaves both alone.
- Bulk entry points (cloud pull / import) use `insertDiaries`: one transaction, and the triggers tokenize row by row inside it.
- `insertDiaries` / `updateADiary` are the schema funnel: tiptap content is normalized to v2 (`TiptapContent.normalize`) and, when that changed it, the four media lists are recomputed. `contentText` is always re-derived from the content there, never taken from the caller (sync and import included). `upgradeContentSchema` is the one-time backfill behind the `contentSchemaV2` KV flag.
- Media names sit inside `contentText` as `opener + name + U+FDD0` (openers from U+FDD1 in `MediaKind` order; the whole U+FDD0–U+FDEF range is stripped from user text), so they are searchable. `TiptapContent.countCharacters` skips them, `MediaMarkedText` renders them as icon + name, `MediaMarkup.forModel` turns them into `[image: name]` for the assistant.
- Media names live only on the content nodes; durations are never stored (the editor and media library probe and cache them in memory). `diary_media.name` is derived from the nodes (first non-empty name per file) so the media library lists names without parsing content. Renaming from outside the editor is `DiaryRepository.renameMedia`, which rewrites the node name in every referencing diary as a user edit.
- Release 2.8.1 kept audio names in a synced `media_infos` table. The v3 step moves them into the audio nodes and drops the table; 2.8.1-shaped diaries pulled or restored later (`TiptapContent.isLegacy`) take them from the legacy `m:` objects in `ArchiveApplier`, which HEAD keeps but never writes.
- User edits must bump `lastModified`; derived writes such as sync landing, migration and repair **must not** bump it and must carry `fromSync` on the event.
