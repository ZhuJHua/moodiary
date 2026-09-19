# CLAUDE.md

## Project Overview

Moodiary is a Flutter + Rust diary app. **Layered pub-workspace monorepo**: 32 shared packages under `packages/` in four dependency layers, consumed by the single Flutter app **`mobile/`** (Android + iOS, pub name `moodiary`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code). A desktop app will be rebuilt later; the packages are layered for it, but no desktop target exists today.

## Tech Stack

- **Flutter 3.47.2 / Dart 3.13.0**. `.fvmrc` pins 3.47.2; `>=3.47.0` in `mobile/pubspec.yaml` is only the lower bound.
- **Rust 1.95.0 stable** (one `rust/rust-toolchain.toml` per native package, kept identical by `tool/check_generated.dart`), `flutter_rust_bridge` 2.13.0. Native libraries are built by Native Assets build hooks (needs `rustup`).
- **Android**: AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.0, built-in Kotlin (`android.builtInKotlin=true`); daemon JVM pinned to 21 in `gradle-daemon-jvm.properties`.
- **Riverpod** (dev) + codegen, **go_router**, **get_it**, **SQLite** (drift + FTS5 external content over the `simple` tokenizer from `sqlite3_simple`; schema source of truth is the `.drift` files in `moodiary_data`), **Freezed** + **json_serializable**.

## Commands

```bash
# Setup
fvm use
dart tool/task.dart setup          # flutter pub get (the editor bundle is built by moodiary_editor's build hook on run/build; needs corepack)

# Run & Build (mobile app)
dart tool/task.dart run            # flutter run
dart tool/task.dart build-apk / build-ios  # the only two targets
# Extra flutter flags go after --:  dart tool/task.dart run -- --release

# Code Gen
dart tool/task.dart build-runner   # whole workspace (running it in mobile/ alone misses package-side annotations)
dart tool/task.dart gen-rust       # regenerate Rust FFI bindings after touching rust/src/api
dart tool/task.dart i18n           # slang codegen after editing i18n/*.json
dart tool/task.dart migrations     # drift schema snapshot + step-by-step migration codegen, after bumping schemaVersion
dart tool/task.dart gen            # gen-rust + i18n

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # affected packages only: changed relative to --diff=<ref> (default HEAD, incl. uncommitted/untracked) plus transitive dependents, serial (melos exec would otherwise use every core and starve itself); root pubspec change or --all runs everything (CI). Only the legacy-database migration tests need ISAR_TEST_DYLIB
dart tool/task.dart test-mobile    # mobile/ only
for d in packages/foundation/*/rust; do (cd $d && cargo clippy --all-targets -- -D warnings && cargo test); done  # six packages; fast_* would miss moodiary_rust
cd packages/feature_base/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test

# Release (run on develop, clean tree, in sync with origin)
dart tool/release.dart --bump patch     # or an explicit X.Y.Z

# Sponsors
dart tool/sponsor.dart <@github | nickname> ...  # appends to both READMEs between the sponsors markers, opens a [skip ci] PR to merge by hand
```

Full-repo verification = the four Lint & Test commands above. `flutter test` at the repo root finds nothing.

**Melos**: `melos bootstrap` activates the workspace and regenerates IDE module files; it runs no codegen. `melos list` / `melos run <script> --category <layer>` filter by layer.

**Release**: `tool/release.dart` bumps `mobile/pubspec.yaml`, prepends a git-cliff section to `CHANGELOG.md` for review, opens the `chore(release): X.Y.Z` PR and dispatches `build.yml` from the release branch. The build reads the version from the pubspec and the notes from the changelog section, then leaves a **draft** release — no tag exists yet. Merging the PR fires `publish-release.yml`, which undrafts it, which is what creates the tag, at the squash commit. Changelog generation never runs in CI. To keep a PR out of the changelog, put `Changelog: skip` in the squashed commit body, or name it with one of the skipped scopes (`chore(deps|readme|pr|pull)`); the release commit itself is skipped by `chore(release)`.

**Versions** are exact-pinned everywhere; the root `melos` caret is the only exception.

## Architecture

### Directory Layout

```
moodiary/                    # root = workspace + Melos coordinator (no app code)
  tool/                      # task runner + layer check
  mobile/                    # Flutter app (pub: moodiary)
    lib/
      app/                   # composition layer: di, router, shell, lifecycle
        home/                # home tab
        settings/            # settings hub
      main.dart
  packages/
    foundation/              # leaf layer, no internal deps
      moodiary_lint/         #   shared analyzer options
      moodiary_di/           #   the single get_it instance
      moodiary_logging/      #   logging; on-disk path injected by the composition root
      moodiary_i18n/         #   slang strings and lookup entry points
      moodiary_router/       #   typed route primitives over go_router; every route class lives here
      fast_image/            #   image pipeline (derivatives / region decode / tiled viewer), native lib libfastimage
      fast_press/            #   export typesetting IR -> PDF (typst) / DOCX, libfastpress (moodiary_export only)
      moodiary_rust/         #   http client/server, WebDAV/S3 sync, rig chat, graph layout; libmoodiary_rust (four facades, one owner each, lazy)
      fast_tokenizer/        #   Hugging Face tokenizer for the ONNX models, libfasttokenizer
      fast_crypto/           #   AES-GCM + Argon2id, libfastcrypto (facade self-initializes)
      fast_zip/              #   zip write/extract, libfastzip (moodiary_export / moodiary_sync only)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
      mui/                   #   design system, a supplement to material_ui
    core/                    # domain-free infra. Order: platform,http -> storage -> files -> theme
      moodiary_platform/     #   dirs / biometrics / network state / app and device info
      moodiary_http/         #   IHttpClient / IHttpServer ports, implemented in Rust
      moodiary_storage/      #   KV (MMKV) / SecureKV (no database here)
      moodiary_files/        #   file layout + media pipeline + file picker port
      moodiary_theme/        #   system color, accent tiers, custom fonts -> ThemeData
    feature_base/            # -> core/foundation. Order: models,ml -> data -> components,migration,preferences -> picker -> editor
      moodiary_models/       #   pure Freezed models + DTOs + event types
      moodiary_data/         #   SQLite (drift) + repositories + controllers + shared transient state
      moodiary_components/   #   UI shared by features that mui cannot reach; code-highlight table, DiaryShare hook
      moodiary_migration/    #   one-shot legacy migration; legacy/ freezes the old Isar models
      moodiary_preferences/  #   preference state
      moodiary_ml/           #   local ML on onnxruntime_plus + model download/activation (sole owner of onnxruntime_plus)
      moodiary_picker/       #   wechat_assets_picker reskinned + image_picker camera (mobile only)
      moodiary_editor/       #   TipTap webview editor base, embedded by diary
    feature/                 # -> feature_base/core/foundation; features never import each other
      moodiary_export/       #   export Markdown/Word/PDF/image, local backup, Markdown import, share (= single-entry export)
      moodiary_diary/        #   diary CRUD/search/category/calendar/map/recycle
      moodiary_sync/         #   sync engine + UI
      moodiary_assistant/    #   AI assistant (flutter_chat_ui + rig); runJavascript sandbox on our flutter_js fork
      moodiary_media/        #   media library
      moodiary_lock/         #   app lock
```

Unqualified `lib/...` means `mobile/lib/...`; `packages/` and `tool/` are repo-root-relative.

### Layer Dependencies

The DAG is strictly `foundation -> core -> feature_base -> feature -> apps`. Features never import each other; shared logic sinks a layer, cross-feature composition happens in the app. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`** at a zero baseline. Melos `categories:` are filters only.

core and feature_base each have an intra-layer order (`_coreOrder` / `_featureBaseOrder`; same-tier packages never import each other). Two edges were bought with injection and must not be reverted:

- **`storage` below `files`**: the database directory and schema list come from the composition root, so storage knows nothing about the file layout.
- **`moodiary_logging` stays in foundation** because the release log path is injected via `AppLogger.configure`; reading `AppFiles` directly would float the package above core, out of reach of almost everyone.

**core knows no domain type** (`Diary` / `Category` / `Font`): schema tables live in `moodiary_models`, orphan-media cleanup in `moodiary_migration`, `Font` assembly in `moodiary_data`. `moodiary_i18n` belongs in foundation even though its namespaces carry feature names: that knowledge is JSON keys, not type dependencies.

In-app layering within `mobile/lib`: `gen -> core -> data -> component -> feature/<x> -> app -> main.dart`, zero violations.

### Package barrels: bare exports, visibility in the file

A barrel exports whole `src/` files without `show`. Anything a file does not need to share gets a `_` prefix; a symbol other files in the package use but nobody outside should is `@internal` plus a `hide` on the barrel (the analyzer demands the hide); a symbol only tests use is `@visibleForTesting`. `show` stays only where a file's public surface cannot be trimmed: FRB `frb_generated.dart`, third-party re-exports (`dynamic_color`, `re_highlight`) and the picker skin.

### Routing: go_router, parameters via `extra`

The app never targets the web, so routes carry no path or query parameters. A route class in `moodiary_router` holds `location` (its `static const path`) and a `params` map with snake_case keys; `push`/`go`/`replace` send it as `extra`. Each page exposes `factory X.fromRoute(GoRouterState)` and reads `state.params`. Feature packages define their `xxxRoutes()` list in the package barrel; there is no `routes.dart`. Keep `params` to JSON scalars (ids, bools): go_router falls back to `json.encode` for state restoration, and an object in the stack would be a stale snapshot.

### DI: get_it + injectable (details in mobile/CLAUDE.md)

- Binding annotations go on implementation classes (`@Singleton(as:)` etc.). storage / http / ml / data / assistant / sync / editor / theme are micro-packages mounted by `mobile/lib/app/di/di.dart`; there is exactly one `configureDependencies`.
- The container owns the whole object graph: `MoodiaryDatabase` (preResolve), the 14 repositories (`@lazySingleton`, constructor-injected), and the process-level holders (`@singleton`). Resolve with `getIt<X>()`; Riverpod Notifiers / widgets write `late final _repo = getIt<X>()`. Riverpod manages UI state only; there are no repository providers and no static `X.get()` facades (`MoodiaryKVs.x.get()` is a key accessor and stays).
- Tests: `XxxRepository(MoodiaryDatabase.forTesting(...))` for repositories; `getIt.registerSingleton<XxxRepository>(fake)` + `tearDown(getIt.reset)` above them.
- After changing annotations run `dart tool/task.dart build-runner` (generated files are committed). Business code never hand-writes `getIt.register*`; the one exception is the session scope opened by `activateSyncProvider()`, which exposes the `@Named(SyncProviderIds.x)` backend as the unnamed `IRemoteSyncBackend`.
- `@PostConstruct` is deliberately unused (the watcher would wake before the migration); startup belongs to main's bootstrap, not the container.

### mui: a supplement to material, not a replacement

- material is exported only through `package:mui/mui.dart`; business code imports mui, never material. `tool/check_layers.dart` guards it; the allowlist has one entry (`picker_theme.dart`, wechat_assets_picker needs a legacy ThemeData).
- Use material_ui directly when it suffices; add to mui only when it does not, with an `M` prefix.
- `ColorScheme` / `TextTheme` are the sources of truth; `buildMuiTheme()` is the only place that constructs `ThemeData`. Access via `context.theme.typography.titleSmall.emphasized.primary`; what `ThemeData` cannot hold goes in `MuiTokens` (token tables, `onMedia`, `success`, `MuiFontConfig` for variable-font weights).
- mui has zero `moodiary_*` deps and ships its own slang strings.

### i18n: slang, not gen-l10n (both modes and pitfalls in packages/foundation/moodiary_i18n/CLAUDE.md)

Two unrelated slang outputs: the App (default mode, `Translations` / top-level `l10n`) and mui (`locale_handling: false` + hand-written delegate, `context.muiL10n`). **i18n** is the mechanism, **l10n** the resolved strings, **Localizations** only Flutter's chain (mui alone).

- Widgets use `context.l10n.xxx` (rebuilds on language change); services / export / callbacks use top-level `l10n.xxx`. Parameters are named. Write `l10n.xxx.yyy` in full; a local alias makes analyze report the key as dead.
- One namespace file per feature; feature packages do not install slang (mui excepted).
- After editing `*.i18n.json` run `dart tool/task.dart i18n` (generated files are committed, nothing catches a stale one).
- Text for the model (prompts, tool descriptions, tool results) is hardcoded English and never enters i18n; text for the user goes through slang.
- Some Chinese literals are kept on purpose (sync log lines, font family names, legal text); check moodiary_i18n's list before translating one.

### KV: MMKV, synchronous

- `IKVStorage.set` / `remove` / `clear` return `void`; `init` and SecureKV stay async. Detect "no value" with `containsKey`.
- Keys may use only int / bool / double / String / List<String>; another type fails at runtime, and a test guards it.
- Secrets (app-lock PIN, third-party API keys) live in `MoodiarySecureKVs`. In widgets use `secretKvProvider(key)` and `ref.invalidate` after every write.
- Never touch `password` directly; go through `AppLockPin` (Argon2id PHC string). App lock on = a credential exists (`AppLockPin.enabled`, loaded in `main.dart`).

### Full-text search lives in `sqlite3_simple`, a git dependency

`diary_fts` is external content over `diaries` with `tokenize='simple'`, maintained by three triggers
in `diary_tables.drift`. The tokenizer is **not in this repo**: it is
[`sqlite3_simple`](https://github.com/ZhuJHua/sqlite3_simple), our fork of
[wangfenjin/simple](https://github.com/wangfenjin/simple) rebuilt as a pure Dart package that
compiles the C++ sources through a build hook. It is pinned by commit sha, not published to pub.
An FTS5 tokenizer has to be a C-ABI loadable extension — `fts5_api` is only reachable through
`SELECT fts5(?1)` + `sqlite3_bind_pointer` from inside one — so it is the one native library here
that does not go through FRB.

`loadSimpleExtension(jiebaDictDir: ...)` runs in `MoodiaryDatabase.open` (and `installJiebaDict()`
in `.forTesting`) before any connection is created. Both the `sqlite3_auto_extension` registration
and the dictionary path are process-level native state, so one call covers the background isolate
and every connection in `readPool`. **The dictionary install is not optional**: cppjieba reads its
dictionaries as real files and aborts the process on a missing one, so a `jieba_query()` without it
does not fail, it crashes.

Han text is indexed per character with pinyin variants as colocated tokens, which is what makes
`pingguo` and `pg` find 苹果. Queries go through `jieba_query(text)`, which returns a finished
MATCH expression — word phrases for Han, pinyin candidate groups for latin, **AND between terms**.

### Rust: several `fast_*` packages, one native library each

Principle: split freely, never duplicate dependencies. http / sync / llm share one network base and live in `moodiary_rust` (the only real binary duplication otherwise, 2 MiB); graph lives there too. Each package ships its own crate, native library, hook, about.toml, rust-toolchain and Cargo.lock.

| Package | Owner | Loading |
|---|---|---|
| moodiary_rust | one owner per facade: http.dart -> moodiary_http, sync.dart -> moodiary_sync, llm.dart -> moodiary_assistant, graph.dart -> moodiary_diary (`_rustFacadeOwners`) | lazy |
| fast_tokenizer | moodiary_ml | first ONNX model load, `FastTokenizer.ensureInitialized` |
| fast_image | whole repo | startup, `FastImageRuntime.init` |
| fast_press | moodiary_export (`_nativePkgOwners`) | first export |
| fast_zip | moodiary_export / moodiary_sync (`_nativePkgOwners`) | first archive / extract |
| fast_crypto | whole repo | facade self-initializes per call |

- Every build hook returns early when the target OS is the host (`flutter test`): Dart tests never load a Rust library, the editor bundle or the license manifest; Rust and the editor are tested by their own suites. **The SQLite extensions are the exception** — `sqlite3_vec` and `sqlite3_simple` build for the host too, because `diary_fts` cannot even be created without the `simple` tokenizer and every DB test would fail.
- Every package exposes `XxxLib` and an idempotent `Xxx.ensureInitialized()`. Opaque handles (`CancelToken`) cannot cross a .so, so there is one per library, constructed synchronously; construct only after the await. After touching `rust/src/api` run `dart tool/task.dart gen-rust`.
- Everything goes through FRB; raw dart:ffi saves only the 0.3 MB floor.
- No `[workspace.dependencies]`: the same crate is pinned per package, and `tool/check_generated.dart` fails on drift across Cargo.toml, toolchain channel and FRB / ffigen pins.
- If APK size does not change after a Rust dependency change, suspect the hook cache under the workspace root's `.dart_tool/hooks_runner/` (`flutter clean` does not touch it; `dart tool/task.dart clean` does).
- Splitting libraries is a delivery strategy, not a size saving (619 KB floor per library). The license manifest `mobile/assets/licenses/third_party.json` is generated at build time by `mobile/hook/build.dart`; local machines and CI need `cargo-about` 0.9.2. It scans the in-repo crates, and merges the `third_party.json` that each package in `_externalLicensePackages` (`sqlite3_simple`, `sqlite3_vec` — vendored C/C++ that cargo-about cannot see) ships at its root, resolved through `.dart_tool/package_config.json`.
- zip stays in Rust: the LAN archive uses entry-level AES-256, and pure Dart manages 17 MB/s with the whole entry on the heap.
- `lanProtoVersion` is 3: `lan_receiver._admit` requires the `x-moodiary-proto` header to equal 3, because 2.8.0 would overwrite placeId references with position snapshots. `LanPeer.compatible` still admits `proto == null`, so a 2.8.0 peer looks tappable and fails only at the handshake.
