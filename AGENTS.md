# Agent instructions

## Project Overview

Moodiary is a Flutter + Rust diary app. Shared packages under `packages/` form four dependency layers, consumed by **`mobile/`** (Android + iOS, pub name `moodiary_mobile`). The root `pubspec.yaml` coordinates the pub workspace and Melos; it contains no app code.

## Tech Stack

- **Flutter 3.47.8 / Dart 3.13.0**. `.fvmrc` pins 3.47.2; `>=3.47.0` in `mobile/pubspec.yaml` is only the lower bound.
- **Rust 1.99.1 stable** (one `rust/rust-toolchain.toml` per native package, kept identical by `tool/check_generated.dart`), `flutter_rust_bridge` 2.13.0. Native libraries are built by Native Assets build hooks (needs `rustup`).
- **Android**: AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.0, built-in Kotlin (`android.builtInKotlin=true`); daemon JVM pinned to 21 in `gradle-daemon-jvm.properties`.

## Commands

```bash
# Setup
fvm use
fvm dart tool/task.dart setup          # flutter pub get (the editor bundle is built by moodiary_editor's build hook on run/build; needs corepack)

# Run & Build (mobile app)
fvm dart tool/task.dart run -- --flavor production # Android
fvm dart tool/task.dart run            # iOS; select an iOS device
fvm dart tool/task.dart build-apk      # defaults to the production flavor
fvm dart tool/task.dart build-ios
fvm dart tool/task.dart build-apk -- --flavor alpha --release
# Extra flutter flags go after --:  fvm dart tool/task.dart run -- --release

# Code Gen
fvm dart tool/task.dart build-runner   # whole workspace
fvm dart tool/task.dart gen-rust       # regenerate Rust FFI bindings after touching rust/src/api
fvm dart tool/task.dart i18n           # slang codegen after editing i18n/flutter (i18n/web needs no codegen)
fvm dart tool/task.dart pigeon         # moodiary_native bindings after editing its pigeons/*.dart
fvm dart tool/task.dart migrations     # drift schema snapshot + step-by-step migration codegen, after bumping schemaVersion
fvm dart tool/task.dart gen            # gen-rust + i18n + pigeon

# Lint & Test
fvm dart tool/task.dart analyze        # generated-binding checks + layer checks + flutter analyze
fvm dart tool/task.dart test           # affected packages only: changed vs --diff=<ref> (default: the merge-base with origin/develop, so the whole branch, plus uncommitted and untracked) plus transitive dependents; root pubspec change or --all runs everything (CI). Only the legacy-database migration tests need ISAR_TEST_DYLIB
fvm dart tool/task.dart test-mobile    # mobile/ only
for d in packages/foundation/*/rust; do (cd "$d" && cargo clippy --all-targets -- -D warnings && cargo test); done
(cd packages/feature_base/moodiary_editor/editor && corepack pnpm install --frozen-lockfile && corepack pnpm type-check && corepack pnpm test)

# Release (run on develop, clean tree, in sync with origin)
fvm dart tool/release.dart --bump patch     # or an explicit X.Y.Z
```

For full verification, use `test --all` alongside the analysis, Rust, and editor commands above. CI (`quality.yml`) groups these into Dart, Rust, and Editor jobs; its `changes` job skips jobs unaffected by the PR paths.

**Tests are one process**: one `flutter test` at the repo root over the affected packages' `test/` dirs, so hooks and the frontend compiler run once, not once per package.

- The root dev-depends on `moodiary_data` / `moodiary_assistant` only to pull `sqlite3_simple` / `sqlite3_vec` / `flutter_js` into the hook tree: a hook runs only for the cwd package's deps.
- cwd is the repo root, so tests read repo files through `repoRoot` (`moodiary_lint/testing.dart`), never a relative path, and write only into their own `createTempSync` directory.

**Melos**: `melos bootstrap` activates the workspace and regenerates IDE module files; it runs no codegen. `melos list` / `melos run <script> --category <layer>` filter by layer.

**Release**: `tool/release.dart` bumps `mobile/pubspec.yaml`, prepends a git-cliff section to `CHANGELOG.md` for review, opens the `chore(release): X.Y.Z` PR and dispatches `build.yml` from the release branch. The build reads the version from the pubspec and the notes from that section, then leaves a **draft** release — no tag yet. Merging the PR fires `publish-release.yml`, which undrafts it; undrafting is what creates the tag, at the squash commit. Changelog generation never runs in CI. To keep a PR out of the changelog, put `Changelog: skip` in the squashed commit body or use a skipped scope (`chore(deps|readme|pr|pull)`); `chore(release)` skips the release commit itself.

Keep dependency versions pinned; match shared native pins across packages.

## Architecture

### Layout notes

Package roles are each pubspec's `description`; layer = directory. `i18n/flutter` (slang) and `i18n/web` (editor page) hold every translation json; a string both need is duplicated. `moodiary_ml` is the sole owner of `flutter_onnxruntime`. `moodiary_native` is the only home for our own Kotlin / Swift code: every Flutter-to-native call is a pigeon API there, never an ad-hoc MethodChannel or code in `mobile/android` / `mobile/ios`. One pigeon file per feature, generating only the platforms it needs, all into one Kotlin package and one Swift module; each platform's error class comes from the first file that targets it (Kotlin: `selection_handle.dart`, Swift: `editor_keyboard.dart`), and every later file sets `includeErrorClass: false` for that platform.

Paths are relative to the repository root unless stated otherwise.

### Layer Dependencies

The DAG is strictly `foundation -> core -> feature_base -> feature -> apps`. Features never import each other; shared logic sinks a layer, cross-feature composition happens in the app. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`** at a zero baseline. Melos `categories:` are filters only.

core and feature_base each have an intra-layer order (`_coreOrder` / `_featureBaseOrder`; same-tier packages never import each other). Two edges rely on injection; keep them:

- **`storage` below `files`**: the database and dictionary directories come from the composition root, so storage knows nothing about the file layout.
- **`moodiary_logging` stays in foundation** because the release log path is injected via `AppLogger.configure`; reading `AppFiles` directly would float the package above core, out of reach of almost everyone.

**core knows no domain type** (`Diary` / `Category` / `Font`): domain models live in `moodiary_models`, schema tables in `moodiary_data`, and orphan-media cleanup in `moodiary_migration`. `moodiary_i18n` belongs in foundation even though its namespaces carry feature names: that knowledge is JSON keys, not type dependencies.

### Package barrels: bare exports, visibility in the file

A barrel exports whole `src/` files without `show`. Anything a file does not need to share gets a `_` prefix; a symbol other files in the package use but nobody outside should is `@internal` plus a `hide` on the barrel (the analyzer demands the hide); a symbol only tests use is `@visibleForTesting`. `show` stays only where a file's public surface cannot be trimmed: FRB `frb_generated.dart`, third-party re-exports (`dynamic_color`, `re_highlight`) and the picker skin.

### Routing: go_router, parameters via `extra`

Routes carry no path or query parameters, because the app never targets the web. A route class in `moodiary_router` holds `location` (its `static const path`) and a `params` map with snake_case keys; `push`/`go`/`replace` send it as `extra`, and each page exposes `factory X.fromRoute(GoRouterState)` reading `state.params`. Feature packages define their `xxxRoutes()` list in the package barrel; there is no `routes.dart`. Keep `params` to JSON scalars (ids, bools).

### DI: get_it + injectable (details in [mobile/AGENTS.md](mobile/AGENTS.md))

- Binding annotations go on implementation classes (`@Singleton(as:)` etc.). storage / http / ml / data / assistant / sync / editor / theme are micro-packages mounted by `mobile/lib/app/di/di.dart`; there is exactly one `configureDependencies`.
- The container owns the whole object graph: `MoodiaryDatabase` (preResolve), repositories (`@lazySingleton`, constructor-injected), and the process-level holders (`@singleton`). Resolve with `getIt<X>()`; Riverpod Notifiers / widgets write `late final _repo = getIt<X>()`. Riverpod manages UI state only; there are no repository providers and no static `X.get()` facades (`MoodiaryKVs.x.get()` is a key accessor and stays).
- Tests: `XxxRepository(MoodiaryDatabase.forTesting(...))` for repositories; `getIt.registerSingleton<XxxRepository>(fake)` + `tearDown(getIt.reset)` above them.
- After changing annotations run `fvm dart tool/task.dart build-runner` (generated files are committed). Business code never hand-writes `getIt.register*`; the one exception is the session scope opened by `activateSyncProvider()`, which exposes the `@Named(SyncProviderIds.x)` backend as the unnamed `IRemoteSyncBackend`.
- `@PostConstruct` is deliberately unused; startup belongs to main's bootstrap, not the container.

### mui: a supplement to material, not a replacement

- material is exported only through `package:mui/mui.dart`; business code imports mui, never material. `tool/check_layers.dart` guards it; the allowlist has one entry (`picker_theme.dart`, wechat_assets_picker needs a legacy ThemeData).
- Use material_ui directly when it suffices; add to mui only when it does not, with an `M` prefix.
- `ColorScheme` / `TextTheme` are the sources of truth; `buildMuiTheme()` is the only place that constructs `ThemeData`. Access via `context.theme.typography.titleSmall.emphasized.primary`; what `ThemeData` cannot hold goes in `MuiTokens` (token tables, `onMedia`, `success`, `MuiFontConfig` for variable-font weights).
- mui has zero `moodiary_*` deps and ships its own slang strings.

### i18n: slang, not gen-l10n (both modes in [moodiary_i18n/AGENTS.md](packages/foundation/moodiary_i18n/AGENTS.md))

Two unrelated slang outputs: the App (default mode, `Translations` / top-level `l10n`) and mui (`locale_handling: false` + hand-written delegate, `context.muiL10n`). **i18n** is the mechanism, **l10n** the resolved strings, **Localizations** only Flutter's chain (mui alone).

- Widgets use `context.l10n.xxx` (rebuilds on language change); services / export / callbacks use top-level `l10n.xxx`. Parameters are named. Write `l10n.xxx.yyy` in full.
- One namespace file per feature, under `i18n/flutter` (Dart) or `i18n/web` (editor page); feature packages do not install slang (mui excepted).
- After editing `i18n/flutter/*.i18n.json` run `fvm dart tool/task.dart i18n` (generated files are committed). `i18n/web/{zh,en}.json` is bundled into the editor page as-is, so it needs no codegen step.
- Text for the model (prompts, tool descriptions, tool results) is hardcoded English and never enters i18n; text for the user goes through slang.
- Some Chinese literals are kept on purpose (sync log lines, font family names, legal text); check moodiary_i18n's list before translating one.

### KV: MMKV, synchronous

- `IKVStorage.set` / `remove` / `clear` return `void`; `init` and SecureKV stay async. Detect "no value" with `containsKey`.
- Keys may use only int / bool / double / String / List<String>; a test guards it.
- Secrets (app-lock PIN, third-party API keys) live in `MoodiarySecureKVs`. In widgets use `secretKvProvider(key)` and `ref.invalidate` after every write.
- Never touch `password` directly; go through `AppLockPin` (Argon2id PHC string). App lock on = a credential exists (`AppLockPin.enabled`, loaded in `main.dart`).

### Full-text search

The FTS5 tokenizer is the git dependency `sqlite3_simple` (not in this repo); details in [moodiary_data/AGENTS.md](packages/feature_base/moodiary_data/AGENTS.md).

### Rust: several `fast_*` packages, one native library each

Principle: split freely, never duplicate dependencies. http / sync / llm share one network base in `fast_core`; graph lives there too. Each package ships its own crate, native library, hook, about.toml, rust-toolchain and Cargo.lock.

| Package | Owner | Loading |
|---|---|---|
| fast_core | one owner per facade: http.dart -> moodiary_http, sync.dart -> moodiary_sync, llm.dart -> moodiary_assistant, graph.dart -> moodiary_diary (`_rustFacadeOwners`) | lazy |
| fast_tokenizer | moodiary_ml | first ONNX model load, `FastTokenizer.ensureInitialized` |
| fast_image | whole repo | startup, `FastImageRuntime.init` |
| fast_press | moodiary_export (`_nativePkgOwners`) | first export |
| fast_zip | moodiary_export / moodiary_sync (`_nativePkgOwners`) | first archive / extract |
| fast_crypto | whole repo | facade self-initializes per call |

- Every build hook returns early when the target OS is the host (`flutter test`): Dart tests never load a Rust library, the editor bundle or the license manifest; Rust and the editor are tested by their own suites. **Three third-party code assets are the exception** — `sqlite3_vec`, `sqlite3_simple` and `flutter_js` build for the host too (`diary_fts` cannot even be created without the `simple` tokenizer, and the JS sandbox tests need quickjs), which is why the root pubspec dev-depends on their owners.
- Initialize each native runtime before constructing its opaque handles (`CancelToken`); handles cannot cross native libraries. After touching `rust/src/api` run `fvm dart tool/task.dart gen-rust`.
- Use FRB for the in-repo native libraries.
- No `[workspace.dependencies]`: the same crate is pinned per package, and `tool/check_generated.dart` fails on drift across Cargo.toml, toolchain channel and FRB / ffigen pins.
- The license manifest `mobile/assets/licenses/third_party.json` is generated at build time by `mobile/hook/build.dart`; local machines and CI need `cargo-about` 0.9.2. It scans the in-repo crates and merges the root `third_party.json` shipped by each package in `_externalLicensePackages` (`sqlite3_simple`, `sqlite3_vec` — vendored C/C++ that cargo-about cannot see), resolved through `.dart_tool/package_config.json`.
- Keep zip handling in Rust; LAN archives use entry-level AES-256 encryption.
- `lanProtoVersion` is 4: `lan_receiver._admit` requires the `x-moodiary-proto` header to equal 4.
