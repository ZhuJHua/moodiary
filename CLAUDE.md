# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Moodiary is a cross-platform diary application built with Flutter and Rust (Android, iOS, Windows, macOS), organized as a **layered pub-workspace monorepo**: shared code lives in layered packages under `packages/`, consumed by **two separate Flutter apps** — `mobile/` (pure mobile: Android + iOS) and `desktop/` (Windows + macOS). The old single `app/` that forked at runtime via `isMobilePlatform` was split: `mobile/` is now pure-mobile (all desktop branches stripped, flag removed), and `desktop/` is a **fresh app currently scaffolded only as a runnable skeleton** — its UI is being redesigned/rebuilt from scratch, so most desktop pages don't exist yet.

## Tech Stack

- **Flutter 3.44.0** (managed via FVM in `.fvmrc`)
- **Rust** (stable) with `flutter_rust_bridge` for native performance operations (crypto, image processing, text analysis, WebDAV/S3)
- **Riverpod** (dev versions) for state management with code generation
- **go_router** for declarative routing with code generation
- **get_it** for dependency injection (singleton pattern)
- **Isar** for local database
- **Freezed** + **json_serializable** for immutable models

## Commands

Dev tasks run through a cross-platform Dart task runner (`tool/task.dart`) — there is no Makefile (`make` isn't available on Windows, a build target). Invoke with `dart` (not `dart run`, which would trigger the Rust build hooks).

**Monorepo management: Melos** (`8.0.0`, config in the **root** `pubspec.yaml` `melos:` section, on top of the Dart pub workspace). The root `pubspec.yaml` is a *pure coordinator* (`name: moodiary_workspace`, no Flutter deps, no app code) whose `workspace:` lists all members — the two apps (`mobile`, `desktop`) plus the packages under `packages/` (four dependency layers; ~18 packages after the thin-app refactor sank every feature into a package) — each carrying `resolution: workspace`. `workspace:` uses a glob (`packages/*/*` + `mobile`/`desktop`), so new packages auto-join; pub supports globs here. One shared `pubspec.lock` + `.dart_tool/` resolve at the root. Activate once: `dart pub global activate melos 8.0.0`, then `melos bootstrap` (runs `flutter pub get` across the workspace **and regenerates the IntelliJ module files** — `melos_*.iml` — so members show as proper modules, not "library roots"). `melos list` lists the managed packages; `melos run analyze|test|gen|gen-rust|gen-editor` runs the scripts (which all wrap `tool/task.dart`, whose flutter/dart commands `cd` into **`mobile/`**). The `melos:` section also declares **`categories:`** = the four dependency layers (low→high): `foundation` (`moodiary_lint`/`moodiary_l10n`/`moodiary_rust`/`moodiary_utils`), `core` (`moodiary_models`/`moodiary_core`/`moodiary_data`/`moodiary_preferences`), `ui` (`moodiary_ui`), `feature` (`moodiary_editor`/`moodiary_scan`/`moodiary_assistant`/`moodiary_media`/`moodiary_diary`/`moodiary_sync`/`moodiary_lock`/`moodiary_share`) — declared as globs (`packages/<layer>/*`) so a new package auto-joins its layer; usable as a command filter (`melos list --category foundation`, `melos run <s> --category feature`); the directory layout `packages/<layer>/` mirrors these categories one-to-one. Categories are **filters only**, NOT a dependency firewall: "upper depends on lower" is enforced by pub's acyclic dependency graph, not by Melos. **`melos bootstrap` has a `post` hook** (`command.bootstrap.hooks.post: fvm dart tool/task.dart gen`) — so every bootstrap, *after* `flutter pub get`, regenerates the Rust FFI bindings (`gen-rust`) **and** rebuilds the editor single-file asset (`gen-editor`). That means a fresh `melos bootstrap` needs the FRB codegen CLI (`flutter_rust_bridge_codegen`, version-matched) **and** `corepack` on PATH for the editor build (Node ≥25 no longer bundles corepack — install via `npm i -g corepack` / `brew install corepack`; `tool/task.dart` fails fast with a hint if it's missing). Melos is **not** a workspace member dependency — its `cli_util ^0.5.0` clashes with the mobile app's `flutter_launcher_icons`' `^0.4.1`, so it's a **root** dev_dependency with a root `dependency_overrides: cli_util: 0.5.0` (cli_util is tooling-only, not in the app runtime; `dependency_overrides` only take effect in the workspace-root pubspec). All `*.iml`/`.idea/` are gitignored, so each clone runs `melos bootstrap` to get IDE files.

### Setup
```bash
fvm use                          # Install correct Flutter version
dart tool/task.dart setup        # builds editor + flutter pub get
```

### Build & Run
`tool/task.dart`'s build/run target the **mobile** app; the editor (`packages/feature/moodiary_editor/editor/`) is built automatically as a prerequisite:
```bash
dart tool/task.dart run              # build editor + flutter run
dart tool/task.dart build-apk        # Android
dart tool/task.dart build-ios        # iOS
dart tool/task.dart build-windows    # Windows
dart tool/task.dart build-macos      # macOS
```
Pass extra flutter flags after `--` (e.g. `dart tool/task.dart run -- --release`).

> The desktop app (`desktop/`, pub name `moodiary_desktop`) is **not yet wired into `tool/task.dart`** — it's a runnable placeholder skeleton; build/run it directly: `cd desktop && fvm flutter run -d macos` (or `-d windows`).

Or build the editor manually if needed:
```bash
dart tool/task.dart editor           # cd packages/feature/moodiary_editor/editor && pnpm install && pnpm build
```

### Code Generation (required after model/router/controller changes)
```bash
dart tool/task.dart build-runner     # or: fvm dart run build_runner build --delete-conflicting-outputs
dart tool/task.dart gen-rust         # regenerate Rust FFI bindings (cd packages/foundation/moodiary_rust && frb generate)
dart tool/task.dart gen              # gen-rust + build editor asset (also the `melos bootstrap` post hook)
```

### Lint
```bash
dart tool/task.dart analyze          # layer check + flutter analyze
```

### Tests
```bash
fvm flutter test
```

## Architecture

### Directory Structure

This is a **layered pub-workspace monorepo**. The repo root is a *pure coordinator* (workspace + Melos config, no app code); the two Flutter apps live in top-level **`mobile/`** (pub name still `moodiary`) and **`desktop/`** (pub name `moodiary_desktop`), and shared code is split into ~18 packages under `packages/`, organized into four dependency layers `foundation → core → ui → feature` (one directory per layer). After the thin-app refactor, **every feature is a package** (`moodiary_editor`/`scan`/`assistant`/`media`/`diary`/`sync`/`lock`/`share`) and `mobile/lib` retains no `feature/` slice — it is a pure composition root plus two app-owned presentation surfaces (`app/home`, `app/settings`). Cross-layer deps go strictly downward; the only within-layer edges are inside `core` (`models → core → data`, a natural data backbone).

```
moodiary/              # Monorepo root — pub-workspace + Melos coordinator (NO app code here)
  pubspec.yaml         # workspace root: name `moodiary_workspace`, `workspace:` members,
                       #   `melos:` scripts, melos dev_dep, and the `dependency_overrides`
                       #   (overrides only take effect in the workspace-root pubspec)
  pubspec.lock         # single shared lock for the whole workspace
  tool/                # cross-platform task runner + layer check (run from root)
  mobile/              # ── Pure-mobile Flutter app (workspace member, pub name `moodiary`) ──
    pubspec.yaml       #   resolution: workspace; depends on the runtime packages (+ moodiary_lint dev),
                       #   flutter_launcher_icons, flutter_native_splash, flutter assets/fonts
    android/ ios/      #   mobile-only platform projects (macos/windows now live in desktop/)
    lib/               # THIN composition root — NO feature/ slice (all features sank into packages)
      app/             # Composition layer + the two app-owned presentation surfaces
        di/            #   service_di.dart — calls each package's registerX() barrel fn
        router/        #   router.dart — aggregates every pkg's xRoutes() + cross-owner bindings
        shell/         #   root_shell.dart — bottom-nav IndexedStack of package entry widgets
        lifecycle/     #   app_lock_observer.dart — background-lock policy (skip-list from route contracts)
        home/          #   diary_home_page.dart — mobile diary TAB (moodiary_diary bodies + SyncStatusButton + FAB)
        settings/      #   the settings HUB (app presentation): setting_routes.dart + presentation/{pages,widget}
      merge/           # one-shot legacy-data migration (MergeUtil.runVersionMigration; keeps flutter_quill)
      gen/             # per-app generated assets (l10n → moodiary_l10n package)
      main.dart        # Entry point (highest)
    test/  assets/  res/  splitMap/ # tests, app assets, marketing res, obfuscation symbol maps
  desktop/             # ── Desktop Flutter app (workspace member, pub name `moodiary_desktop`) ──
    pubspec.yaml       #   resolution: workspace; SKELETON — minimal placeholder, no runtime workspace
    macos/ windows/    #   deps yet; shell/routing/pages to be rebuilt from scratch
    lib/main.dart  test/
  packages/            # shared code — four dependency layers low→high (dir = layer)
    foundation/        # leaves — no domain, no internal deps (pure)
      moodiary_lint/   #   shared analyzer config (lib/analysis_options.yaml)
      moodiary_l10n/   #   gen-l10n output + arb + l10n.yaml (flutter: generate) + BuildContext.l10n
      moodiary_rust/   #   self-contained Rust FFI plugin (crate + cargokit + bindings; RustLib + api)
      moodiary_utils/  #   leaf util helpers + pure-Dart content/migration converters (NO domain types)
    core/              # → foundation; internal order models → core → data (the data backbone)
      moodiary_models/ #   domain: 9 Isar @Collection + Freezed DTOs + events + domain enums
      moodiary_core/   #   storage (Isar/KV/SecureKV) + init/di + theme_util + values + exceptions
      moodiary_data/   #   repositories + DiaryContentUtil (singleton .get())
    ui/                # → core/foundation
      moodiary_ui/     #   reusable business-agnostic widgets (component basic + common)
    feature/           # → ui/core/foundation — self-contained, ready-to-use features (top of packages)
      moodiary_editor/ #   COMPLETE editor: TipTap webview + local server + Vue source (editor/) + asset,
                       #     EditController (autosave), editor body/toolbar/record, geo/weather, migration tool
      moodiary_scan/   #   QR feature: encrypted QR generation widgets + time-window crypto (QrCrypto)
      moodiary_assistant/ # AI assistant: chat UI + rig service + provider config + AssistantSummaryTile
      moodiary_media/  #   media library: image/audio/video overview, cleanup, viewers
      moodiary_diary/  #   diary detail/edit + search/category/analyse/map/recycle/manager + view bodies
                       #     (list/waterfall/calendar) + DiaryCategorySectionView + diaryRoutes (uses editor)
      moodiary_sync/   #   ONE sync package: engine+providers widget-free in src/{data,application}, UI in
                       #     src/presentation (+ SyncStatusButton, registerRemoteSync, AutoSyncWatcher)
      moodiary_lock/   #   app lock: LockPage/StartPage/AppLockTile + lockRoutes
      moodiary_share/  #   diary → image/text share: SharePage + shareRoutes
```

**Path convention for the rest of this doc:** unqualified app paths — `lib/...`, `android/`, `ios/`, `test/`, `assets/` — refer to the **`mobile/`** app (e.g. `lib/main.dart` → `mobile/lib/main.dart`). Paths starting with `packages/`, `tool/`, or `desktop/` are repo-root-relative. **Beware two distinct `app`s:** top-level **`mobile/`**/`desktop/` are the whole Flutter projects; **`mobile/lib/app/`** is the in-app composition layer (router/shell/di). The `macos/`/`windows/` platform projects now belong to **`desktop/`**, not the mobile app.

### Layered Packages

The cross-package dependency DAG (upper → lower; enforced by pub's acyclic graph, mirrored by the Melos `categories:` as filters only):

**foundation** (leaves — no domain, no internal deps, pure):
- **`moodiary_lint`** — shared analyzer config only (`lib/analysis_options.yaml`); every package/app does `include: package:moodiary_lint/analysis_options.yaml` + a dev_dep on it (`flutter_lints` is a *regular* dep of this package so the nested include resolves transitively).
- **`moodiary_l10n`** — localization (see Localization).
- **`moodiary_rust`** — Rust FFI plugin (see Rust FFI).
- **`moodiary_utils`** — pure leaf, business-agnostic helpers (file/media/network/logging/color, etc.) **plus the pure-Dart content + migration converters** `tiptap_content.dart`, `quill_to_tiptap.dart` (`QuillDeltaToTiptap`), `markdown_to_tiptap.dart` (`MarkdownToTiptap`). ⚠️ **No domain types, no workspace deps** — utils = generic tools only.

**core** (→ foundation; internal order `models → core → data`) — the domain + data backbone:
- **`moodiary_models`** — domain: 9 Isar `@Collection`s + Freezed DTOs + events, and **domain field enums** (`DiaryType`, `AssistantProviderType`). Generated `.g.dart`/`.freezed.dart` were moved as-is (no `build_runner` re-run) so the Isar schema stays byte-identical → zero DB-migration risk.
- **`moodiary_core`** — infrastructure: storage (Isar DB, KV, SecureKV), `init.dart` + `di.dart` (the shared `getIt`), `theme_util.dart`, constants/values, exceptions (`NetworkException`/`DatabaseException`).
- **`moodiary_data`** — repositories (`DiaryRepository`, `CategoryRepository`, …) + `DiaryContentUtil` + the reactive/read-model controllers (`diary_controller`, `category_controller`, `dashboard_controller`). Kept singleton `.get()` access.
- **`moodiary_preferences`** — app-settings/font/cache state controllers (`appSettingsControllerProvider`, etc.).

**ui** (→ core/foundation):
- **`moodiary_ui`** — reusable, business-agnostic widgets (`component/basic` + `common`).

**feature** (→ ui/core/foundation) — self-contained, ready-to-use features. Every one exposes a uniform barrel (entry widgets, `xRoutes()`, `registerX()`) and the app composes them; siblings never import each other (shared code sinks down to a lower layer, cross-feature composition happens app-side):
- **`moodiary_editor`** — the **complete editor** (see Diary Editor): TipTap webview + `EditController` (autosave) + editor body/toolbar/record + category picker + geo/weather + the legacy→tiptap migration tool + `editorRoutes()`. Decoupled from the app via injection. (`moodiary_editor_host` was merged back in — one package.)
- **`moodiary_scan`** — QR feature: encrypted QR generation widgets (`EncryptQrCode`/`QrInputTile`) + time-window symmetric crypto (`QrCrypto`, on the Rust AES bindings).
- **`moodiary_assistant`** — AI assistant: chat UI (flutter_chat_ui) + rig-based service + provider config + `AssistantSummaryTile` + `assistantRoutes()`.
- **`moodiary_media`** — media library: image/audio/video overview, cleanup, viewers.
- **`moodiary_diary`** — diary detail/edit page (uses `moodiary_editor`), search/category/analyse/map/recycle/manager pages, `DiarySelectPage`, view bodies (`DiaryListView`/`DiaryWaterFallView`/`CalendarView`), `DiaryCategorySectionView`, `diaryRoutes()`. Never depends on `moodiary_sync` — the home scaffold that welds them is app-side (`app/home`).
- **`moodiary_sync`** — **one** sync package (see Sync System): engine + providers widget-free in `src/data`+`src/application`, UI in `src/presentation` (+ `SyncStatusButton`, `registerRemoteSync()`, `syncRoutes()`).
- **`moodiary_lock`** — app lock: `LockPage`/`StartPage`/`AppLockTile` + `lockRoutes()`; the `AppLockObserver` + launch-gate stay app-side.
- **`moodiary_share`** — diary → image/text share: `SharePage` + `shareRoutes()`.

**Apps** (`mobile`, `desktop`) sit above all packages and compose them. After the thin-app refactor, `mobile/lib` keeps only true app-side artifacts: the composition root (`app/{di,router,shell,lifecycle}`), the two app-owned presentation surfaces (`app/home`, `app/settings`), and mobile-only holdouts `merge/` (one-shot legacy Isar migration, keeps `flutter_quill`) + `gen/` (per-app generated assets). The former `core/values/*` and `component/quill_embed/*` holdouts were pushed down into packages (quill_embed → `moodiary_editor`).

### Layered Dependencies (enforced)

Two layerings:

**1. Cross-package DAG** (foundation → core → ui → feature → apps): upper packages depend on lower, never the reverse (the one exception is the natural `models → core → data` order *inside* the `core` layer). Enforced by **pub's acyclic dependency graph** (a cycle fails resolution); the Melos `categories:` only group/filter. See **Layered Packages** above.

**2. In-app layering inside `mobile/lib`** — checked by `tool/check_layers.dart` (pure Dart, no native build) over `package:moodiary/...` imports: **a module may import only from strictly lower layers; same-layer cross-module imports are forbidden** (within `feature/`, one feature may not import another — push shared code down to a package, or up to the `app` composition layer). Layers low→high:

`gen` → `core` → `data` → `component`,`merge` → `feature/<x>` → `app` → `main.dart`

(After the thin-app refactor the in-app `feature/` layer is **empty** — every feature sank into a package — so `mobile/lib` is essentially just the `app` layer + `gen`/`merge`; the checker's lower-layer rows exist for safety but hold no in-app files.) Run via `dart tool/task.dart check-layers` / `analyze` and the `flutter-ci.yml` "Check Layer Dependencies" step; it scans `mobile/lib` only (desktop isn't wired in yet). `tool/layer_baseline.txt` is a ratchet (may only shrink); it is now **empty (0 violations)** — both former cross-feature edges (diary→sync, setting→lock) dissolved into app-side composition. To add a temporary exception run `dart tool/check_layers.dart --update-baseline`; the proper fix is to flip the dependency direction.

### Feature Module Pattern

Each feature is now a **package** (`packages/feature/moodiary_<name>/`), exposing a uniform barrel surface: entry widget(s), `xRoutes()`, route contracts (cross-referenced ones in `moodiary_router`), and `registerX()`. Internally it keeps the same layered structure under `lib/src/`:
```
packages/feature/moodiary_<name>/lib/src/
  application/     # Controllers (Riverpod providers with @riverpod annotation) — keep widget-free
  data/            # Feature-specific models / engine / repositories — keep widget-free
  presentation/    # Pages and widgets
```
The app never imports a feature's internals; it composes public barrels (see The Composition Model). Keeping `src/data`+`src/application` widget-free lets desktop reuse the headless engine (e.g. `moodiary_sync`).

### Adaptive Layout

The mobile/desktop split is now **two separate apps**, not a runtime `isMobilePlatform` fork (that flag and all desktop branches were stripped from `mobile/`). `mobile/` is pure mobile (bottom nav, mobile routes); `desktop/` (Windows/macOS) is a fresh app to be rebuilt with its own shell/routing/pages — currently just a placeholder skeleton. Shared behavior lives in the packages; each app composes its own `app/` layer (router/shell/di).

### Initialization Flow

`main.dart` → `_initSystem()`:
1. Rust bridge init (parallel)
2. `injectBasicService()`: PlatformService → directories → Isar DB; KV + SecureKV (parallel)
3. Theme, service registration, locale resolution (parallel)
4. System UI configuration

### Code Generation

Run `build_runner` after modifying:
- `@riverpod` annotated controllers → generates `.g.dart`
- `@freezed` annotated models → generates `.freezed.dart` + `.g.dart`
- `@TypedGoRoute` annotations in router → generates `router.g.dart`

### Rust FFI (`moodiary_rust` package)

Rust is a **self-contained FFI plugin package** scaffolded by the official tool (`flutter_rust_bridge_codegen create moodiary_rust --template plugin`, `flutter_rust_bridge` 2.13.0-beta.4). Layout (canonical):
- `packages/foundation/moodiary_rust/rust/` — cargo crate (lib name `moodiary_rust` == pub package name).
- `packages/foundation/moodiary_rust/cargokit/` — native build glue; gradle/podspec/cmake reach the crate via relative `../rust` (all platforms, windows included).
- `packages/foundation/moodiary_rust/lib/src/rust/` — generated bindings; `packages/foundation/moodiary_rust/lib/moodiary_rust.dart` — the **public barrel** (re-exports `RustLib` + all `api/*`).
- `packages/foundation/moodiary_rust/flutter_rust_bridge.yaml` — the package owns its FRB config (`rust_input: crate::api`, `rust_root: rust/`, `dart_output: lib/src/rust`); there is **no repo-root config**.

App code imports the barrel `package:moodiary_rust/moodiary_rust.dart` (aliased `as rust` where it calls `rust.imageThumbnail(...)` etc.); `RustLib.init()` is in `lib/main.dart`. The iOS/macOS podspecs carry custom linker flags re-added after scaffolding: `-framework SystemConfiguration` (rig→reqwest) and `-lbz2 -llzma` (zip).

Modules: `assistant`, `crypto`, `font`, `image`, `s3`, `text`, `uuid`, `webdav`, `zip`. When adding/removing a module, update the barrel's exports.

The FRB codegen CLI version must match the library version exactly (`cargo install flutter_rust_bridge_codegen --version 2.13.0-beta.4`). After changing Rust, run codegen **from within the package**: `cd packages/foundation/moodiary_rust && flutter_rust_bridge_codegen generate`.

### Diary Editor (TipTap in a webview)

> **Now a package** (`packages/feature/moodiary_editor/`). The webview editor widget and local server were extracted into the `moodiary_editor` package, consumed via `package:moodiary_editor/moodiary_editor.dart` (exports `MoodiaryEditor`, `MoodiaryEditorController`, `EditorLocalServer`, `MediaResolver`, `imageMimeOf`). **Path mapping for the prose below**: web source `editor/` → `packages/feature/moodiary_editor/editor/`; built asset `assets/editor/` → `packages/feature/moodiary_editor/assets/editor/` (the package's rootBundle prefix the shelf server reads `index.html` from); the Flutter files `moodiary_editor.dart` / `editor_local_server.dart` → `packages/feature/moodiary_editor/lib/src/`. The package is **decoupled from the app via injection** — `MoodiaryEditor` takes `seedResolver` (app passes `() => ThemeUtil().editorSeed`), `fontResolver` (active custom font family+disk path, or null for system font; app passes `() => ThemeUtil().editorFont`), `mediaResolver` (disk path+mime; `appMediaResolver` in `packages/feature/moodiary_editor/lib/src/data/markdown_media.dart`), `loadingBuilder`, plus the media pick/play/save callbacks. The host wiring all of these — `MoodiaryEditorView`, `EditorBody`, `EditController`, and the legacy Quill embeds (`quill_embed/*`) — now all live **inside** the `moodiary_editor` package (`src/presentation/`, `src/application/`), since `moodiary_editor_host` was merged back into `moodiary_editor` (one complete editor package). The webview plugins (`webview_flutter` for Android/iOS/macOS, `flutter_inappwebview_windows` for Windows) are dependencies of the editor package (not the app), hidden behind the `EditorTransport` abstraction in `packages/feature/moodiary_editor/lib/src/transport/`.

The diary editor runs inside a webview. **Plugin (hybrid, behind `EditorTransport`)**: Android/iOS/macOS use **`webview_flutter`** (4.14.0 + endorsed `webview_flutter_android` 4.12.0 / `webview_flutter_wkwebview` 3.26.0 — pinned, no `^`; needs Flutter ≥ 3.44.0, the wkwebview floor). **Windows** uses **`flutter_inappwebview_windows`** (0.7.0-beta.3 + `flutter_inappwebview_platform_interface` 1.4.0-beta.3, WebView2) — webview_flutter has no Windows impl, and on Windows the Chinese-IME candidate window lands correctly with inappwebview because its WebView2 composition controller is parented to a real Flutter child HWND tracked via `SetWindowPos`, unlike `webview_windows`' positionless `HWND_MESSAGE` window (do NOT use `webview_windows`; both render off-screen/composition, the difference is parent-HWND geometry, not explicit IME code). The Windows package's plugin block declares `platforms: windows` only, so it adds **no native code** to the other three platforms (verify via `mobile/.flutter-plugins-dependencies`); do NOT depend on the `flutter_inappwebview` umbrella (it pulls all platforms + re-exports an iOS-internal Dart file). The split lives in `packages/feature/moodiary_editor/lib/src/transport/` — `EditorTransport` (interface + `createEditorTransport()`, picks by `Platform.isWindows`), `WebViewFlutterTransport`, `WindowsInAppWebViewTransport`; `MoodiaryEditor` holds one `EditorTransport` and is otherwise platform-agnostic. **Linux** is unsupported (`_loadError` placeholder, no crash). **Setup**: building Windows needs the NuGet CLI on PATH (WebView2 SDK fetched via NuGet at build time — CI agents too) plus the WebView2 Runtime on the target machine; iOS & macOS need `NSAllowsLocalNetworking` under `NSAppTransportSecurity` in `Info.plist` (WKWebView won't load `http://localhost` otherwise); Android already permits cleartext-to-localhost; WebView2 treats `http://localhost` as a secure context (no extra config). Web source lives in `editor/` (Vue 3 + Vite + **TipTap 3.x / ProseMirror**; the Flutter-facing bridge object is `window.MoodiaryBridge`). `dart tool/task.dart editor` (or `cd editor && pnpm build`) emits a **single `index.html`** — everything (TipTap, Vue, styles) inlined via `vite-plugin-singlefile` — into `assets/editor/` (checked into VCS; regenerate + commit it after editor source changes). **No runtime sidecar**: TipTap has no WASM parser, so unlike the former Vditor/Lute setup there are no `vditor/dist/...` siblings; the whole editor is ~1.0 MB in one file (incl. Tailwind/daisyUI; media playback uses native elements, no player lib). **Storage = TipTap document JSON** (`editor.getJSON()`): `DiaryType.tiptap` is the only editable/creatable type — content is the ProseMirror doc JSON, so custom blocks (image/audio/video/future cards) are first-class nodes whose attrs serialize losslessly. tiptap-markdown is kept only to read old `DiaryType.markdown` diaries for **read-only** viewing (markdown→JSON conversion for migration/assistant is now pure Dart — see Migration below, no webview). Legacy `markdown`/`richText` diaries are **read-only** (`DiaryType.isEditable` is false for them; `EditorBody` routes tiptap→editable editor, markdown→read-only editor, richText→read-only Quill); to edit one you convert it to `tiptap` via the migration tool. The markdown *authoring feel* comes from StarterKit's input rules (`# `, `**`, `- `, `> `, ` ``` `); on top of that there's an **in-webview toolbar** (`editor/src/components/EditorToolbar.vue` — TipTap is headless / ships no toolbar UI, so it's custom-built against the command API, daisyUI-styled (`btn btn-ghost`), with live `editor.isActive(...)` states driven by the `transaction` event): bold/italic/**underline**/strike/inline-code, H1–H3, bullet & ordered list, **task list** (`@tiptap/extension-task-list`+`-task-item`, checkboxes; `- [ ]` round-trips via tiptap-markdown's markdown-it-task-lists), quote, **code block** (`CodeBlockNodeView.vue` Vue node view = a read-only language label top-left + copy button top-right; the `language` attr is set by the ` ```lang ` input rule or by markdown, not an in-block picker; lowlight syntax-highlights only when `language` is set — unset shows 「纯文本」 with no tokens, which is why a fresh ``` block looks "unhighlighted"; the highlight plugin coexists with the node view), **table** (`@tiptap/extension-table` `TableKit`, resizable columns; an "insert table" button (opens an 8×8 grid size picker) plus contextual +/− row/col & delete buttons that appear only when the caret is inside a table — GFM simple tables round-trip through tiptap-markdown, complex tables degrade to HTML in markdown), plus image / audio / video insert buttons (each posts a pick event → Flutter native picker → `insertMedia`/`insertAudio`/`insertVideo`), a **diary-link** button (`[[` → in-editor relevance-ranked search popup for linking another diary; backlinks panel on the diary page), and **find/replace** (toolbar button or Cmd/Ctrl+F → a daisyUI find bar backed by `prosemirror-search`). A **word-count** pill (`CharacterCount` re-exported from `@tiptap/extensions`, read via `editor.storage.characterCount`) sits at the editor's bottom-right in editable mode, updated on `transaction`. Placement is driven by the `platform` boot flag — **desktop pins the bar to the top, mobile to the bottom**; the mobile bottom bar floats above the soft keyboard purely via Flutter's `Scaffold.resizeToAvoidBottomInset` (the webview shrinks above the keyboard, so a flex-bottom bar sits on top of it — no `visualViewport` math; same mechanism as the native Quill toolbar). It renders only in editable mode (`MoodiaryEditor.vue` tracks editability via the kit's `onEditableChange` callback, since `setEditable(emitUpdate=false)` won't fire `onUpdate`). On mobile, when the soft keyboard opens it shrinks the webview (Flutter `Scaffold.resizeToAvoidBottomInset`); ProseMirror doesn't re-scroll on a resize and a plain tap doesn't auto-scroll, so a `window` `resize` → `editor.commands.scrollIntoView()` listener in `MoodiaryEditor.vue` (mobile-only, rAF-coalesced, fires only while focused) re-scrolls the caret back into view so it isn't hidden under the toolbar/keyboard (the editor's base 16px padding gives the small gap — no fixed offset). The editor is hosted via **`@tiptap/vue-3`'s `useEditor`** in `editor/src/components/MoodiaryEditor.vue` (so the editor lifecycle is component-managed — auto-destroyed on unmount — and future **Vue node-views** get the Vue app context); `editor/src/editor/tiptap.ts` `createEditorKit()` produces the `useEditor` options + the imperative `EditorApi` (sharing one closure for the `suppress`/upload state), bound to the bridge in the editor's `onCreate`. **Audio & video** are custom block-atom nodes (`editor/src/editor/media-nodes.ts`, `draggable:false` so the player's scrubber drag isn't hijacked as a node drag) rendered by **Vue node-views via `VueNodeViewRenderer`** (`components/nodes/{Audio,Video}NodeView.vue`) — plain JSON nodes with a bare `filename` attr (no markdown serialize, no prefix routing; JSON carries the node `type`, so they never degrade to images). Playback is **in-webview with NO player library** — native `<audio>`/`<video>` (`HTMLMediaElement` API) driven by a shared composable `editor/src/editor/use-media.ts` (`useMediaControls` maps play/seek/time/mute/buffering to refs; `onBeforeUnmount` pauses + unbinds), with **daisyUI-only chrome**: `btn btn-circle` buttons + a `range range-primary` seek bar (daisyUI 5's range renders the played-fill automatically via `--range-fill`/`--range-progress`, so zero JS for the fill). The `<audio>`/`<video>` bytes are streamed by the local server **with HTTP Range** (mandatory for WKWebView `<video>` — see Loading below). Video sets `poster` to the `video-` thumbnail via the same URL + `?poster=1`, sets `playsinline` imperatively (iOS inline), and "fullscreen" is a **CSS full-window** toggle (`fixed inset-0`, fills the webview viewport — the native Fullscreen API is unreliable in webviews; Escape exits). No third-party JS, no CDN dependency → works offline + in read-only diary view. There is **no longer a `playMedia` event / native audio-sheet / Chewie path** in the editor (the app's `_VideoPlayerPage`/`onPlayMedia` wiring was removed; the standalone `AudioPlayerComponent`/`VideoPlayerComponent` stay for other features). `contentText` (search/cards) + media lists are derived from the JSON doc in Dart (`packages/foundation/moodiary_utils/lib/src/tiptap_content.dart` — media by node *type*), wired through `DiaryContentUtil`. **Migration** (legacy → tiptap, reversible): the visual tool (Settings → Data → "迁移到新编辑器", `editor_migration_page.dart` + `editor_migration_service.dart`) converts **both** `richText` (Delta → JSON via `packages/foundation/moodiary_utils/lib/src/quill_to_tiptap.dart` `QuillDeltaToTiptap`) and `markdown` (md → JSON via `packages/foundation/moodiary_utils/lib/src/markdown_to_tiptap.dart` `MarkdownToTiptap`) — **both pure Dart, unit-tested, no webview**. `QuillDeltaToTiptap`: image/audio/video → first-class nodes, bold/italic/underline/strike/code/link + Quill checklist→taskList preserved, drops color/highlight/align (no TipTap schema). `MarkdownToTiptap`: `markdown` package (GFM) AST → PM nodes; `![](name)` routed to image/audio/video by filename prefix; drops raw HTML & cell alignment. `MarkdownToTiptap` is **also used by the AI assistant** (`assistant_tools.dart`) to store generated markdown as tiptap. Each conversion backs up the original `content`+`type` to a sidecar JSON (`migration_backup/<id>.json`); media files are untouched (same filenames). flutter_quill stays in `pubspec` for read-only `richText` rendering + legacy `merge.dart`. **Dev harness**: `pnpm harness` (in `editor/`) opens `dev.html` — a dev-only page (`editor/dev/`) that embeds the editor in an `<iframe>` inside a phone/desktop frame and mocks the Flutter host (live controls for seed color / brightness / variant / contrast / editable / sample markdown; catches `change`/`saveImage`/`imageTap`/`pickImage` — `pickImage` inserts an external placeholder image since there's no media server in dev; toggling phone/desktop reloads the iframe so the new `platform` re-boots and the toolbar repositions). Lets you iterate on editor styles via Vite HMR without rebuilding Flutter. Excluded from the production build (only `index.html` is a build input). Local media (`image-x.jpg`) won't load in the harness (no media server — use external image URLs in samples); a real Flutter run is still needed to verify on-disk media.

- **Loading**: everything is served by a **`shelf`** loopback server (`packages/feature/moodiary_editor/lib/src/editor_local_server.dart`, lazy singleton on `127.0.0.1`) — plugin-independent `dart:io`, so one server backs all platforms. The page comes from Flutter assets: the handler reads the single `index.html` from `rootBundle` (key `packages/feature/moodiary_editor/assets/editor/index.html`). Diary media: the handler intercepts `GET /<token>/media/<name>` and streams disk bytes on demand **with HTTP Range support** (206 + `Content-Range`/`Accept-Ranges`, 416 for unsatisfiable; required for WKWebView `<video>`/`<audio>` playback + seeking, see `_serveFile`/`_parseRange`). Images/audio/video resolve to their real files; a `?poster=1` query returns the `video-` thumbnail jpeg as the video poster (resolver: `packages/feature/moodiary_editor/lib/src/data/markdown_media.dart` `appMediaResolver(name, {poster})`, injected as the server's `mediaResolver`). **Custom font**: the handler also serves `GET /<token>/font` — the active custom font file (`.ttf`/`.otf`) via the injected `fontResolver` (`() => ThemeUtil().editorFont`, family+disk path, or null→404 for system font), streamed by the same `_serveFile` (Range-capable); the web side loads it via an `@font-face` (see Theme below). The `?v=<family>` query on that URL is a cache-buster (server ignores it), so switching fonts refetches. All other requests fall through to the index page — lazy, binary, no base64. Port: `shelf_io.serve(..., 0)` lets the OS assign a free port, read back via `server.port` (no probe-a-free-port workaround); on bind failure `serve` throws (no hang), surfaced by `ensureStarted`. A per-run 128-bit hex token in the media path keeps other local processes from reading media. macOS `network.server`/`client` entitlements are configured.
- **Embedded only**: the webview renders the editor body only — AppBar / read-mode metadata / status / **diary title** are all Flutter-native (`DiaryPage`'s classic `Scaffold` path; `EditorBody` → `MoodiaryEditorView` → `MoodiaryEditor`). The **diary title** is a native `TextField` above the editor in `DiaryPage._buildBody` (edit mode) / a `Text` header (read mode), bound to the stored `Diary.title` via `EditController.changeTitle` (autosave/dirty like other metadata; not part of the content JSON — search indexes `title` as its own column). Headings (H1–H3) inside the doc are a separate thing (in-webview toolbar).
- **Boot data** (platform/editable/theme/placeholder/**mediaBase**/**fontBase**) is passed as `?boot=<base64url(JSON)>` on the page URL — parsed synchronously by `editor/src/bridge/boot.ts` `readBoot()` before first paint (correct theme + font from frame one). `mediaBase`/`fontBase` are the server URLs, added to the boot map *after* the server starts (need the port); `theme` (incl. the font family) is captured before. `window.__BOOT__` remains as a legacy fallback only.
- **Bridge** (web side only ever knows `window.MoodiaryEditor.postMessage` + `window.MoodiaryBridge.*`, so it's transport-agnostic): Flutter→JS calls `window.MoodiaryBridge.*` (`setContent`/`getContent` — content is TipTap doc JSON, `setContent` also accepts markdown for read-only legacy viewing — `setTheme`/`focus`/`setEditable`/`reset`/`setSaveStatus`/`insertMedia`/`insertAudio`/`insertVideo`/`resolveImage`/`resolveLinkCandidates`) through `EditorTransport.run` (= webview_flutter `runJavaScript` / inappwebview `evaluateJavascript`). JS→Flutter posts to `window.MoodiaryEditor.postMessage` (`editor/src/bridge/post.ts`) — events `ready`/`change` (JSON)/`error`/`saveImage`/`imageTap`/`pickImage`/`pickAudio`/`pickVideo`/`details`/`requestLinkCandidates`/`linkTap` (audio/video play in-webview, so no `playMedia` event). The channel name `MoodiaryEditor` is shared (`kEditorChannel`): on **webview_flutter** it's a named `JavaScriptChannel` that auto-injects `window.MoodiaryEditor.postMessage` (no shim); on **Windows/inappwebview** a DOCUMENT_START `UserScript` defines `window.MoodiaryEditor.postMessage` forwarding to `window.flutter_inappwebview.callHandler('MoodiaryEditor', m)`, received via `controller.addJavaScriptHandler`. `getContent` is served from a Flutter-side cache of `change` events (no JS round-trip). Global JS error hooks are inline in `editor/index.html`. Theme: Flutter sends the **seed color + brightness + variant** (`ThemeUtil.editorSeed`) **plus the active custom-font family** (`ThemeUtil.editorFont?.family`, omitted for system font) in one `_seedTheme()` map used for **both** the initial `boot.theme` and every runtime `setTheme`; the web side (`editor/src/bridge/theme.ts`) regenerates the Material 3 palette with `@material/material-color-utilities` and injects `--app-*` tokens (see `editor/src/styles/moodiary-editor.css`) — TipTap itself needs no JS theme switch (pure CSS via `--app-*` + `[data-theme]`). **Custom font**: `applyTheme` → `applyFont(family)` injects a `<style id=app-font-face>` `@font-face` whose `src` is `boot.fontBase` (the `/<token>/font` route above) and sets inline `--app-font-sans` to `'<family>', <default stack>`; no `font-weight` descriptor, so bold is synthesized (works for static *and* variable fonts). System font → the inline var is removed, falling back to the `:root` default stack in the CSS. The font applies to the writing area (`.ProseMirror` reads `var(--app-font-sans)`), not the toolbar chrome. Live font changes propagate for free: `bumpTheme` → new `ThemeData` → the editor's `didChangeDependencies` → `setTheme` with the new family. `ThemeUtil.buildTheme()` resets `fontFamily`/`_activeFontFileName`/`wghtAxisMap` at the top each rebuild so switching back to system font takes effect without a restart. The editor chrome (toolbar/surfaces + the audio/video controls) is styled with **Tailwind v4 + daisyUI** (now in the production bundle, not just the dev harness): two daisyUI themes `light`/`dark` map `--color-*` → `var(--app-*)` (daisyUI v5 allows `var()` theme colors), so all of it follows the same Material seed + brightness. **Icons** are Material Symbols pulled on-demand via **`unplugin-icons`** — `import Icon from '~icons/material-symbols/<name>-rounded'` → an inline-SVG Vue component; only imported icons ship (tree-shaken), data comes from the `@iconify-json/material-symbols` devDep (not bundled), no icon font/CDN. `~icons/*` typing needs `/// <reference types="unplugin-icons/types/vue" />` (in `vite-env.d.ts`).
- **Images**: stored as bare filenames in markdown (`![](image-x.jpg)`). Display: a custom TipTap `Image` extension's `renderHTML` prepends the boot-supplied `mediaBase` (`http://localhost:PORT/<token>/media/`) to local media names — the node's `src` attr stays bare, so markdown serialization stays bare; on read-back, `stripMediaPrefix` (`editor/src/editor/media.ts`) also strips any prefix (plus the legacy `moodiary-media://media/` scheme) as belt-and-suspenders so persisted markdown stays bare. Native pick (`insertMedia(name)`) and drag/paste (`handlePaste`/`handleDrop`→`saveImage`→`resolveImage`) route through Flutter (`MediaUtil`); `MoodiaryEditorView` implements both. Image tap posts `imageTap` (reserved for a future native preview). The toolbar's image button posts `pickImage` → Flutter opens the native picker (`MoodiaryEditor.onPickImage` → `MoodiaryEditorView._showImageDialog`) → `insertMedia(name)`; drag/paste still works in parallel.
- **Platform quirks**: JS execution is wrapped (`EditorTransport.run` → `_run`) to swallow `PlatformException` — WebKit/WebView2 rethrow JS runtime errors, and the "JS errors don't surface" contract keeps the 10s ready-timeout fallback intact. `isInspectable`/`setInspectable`/Android `enableDebugging` are debug-only (`kDebugMode`). On webview_flutter the named channel + settings are configured before `loadRequest`; on inappwebview the `UserScript` shim + `addJavaScriptHandler` are wired at construction / `onWebViewCreated`. **Windows IME**: WebView2 is off-screen-texture (composition) based; the Chinese IME candidate window lands correctly only because inappwebview parents the composition controller to a real Flutter child HWND it tracks via `SetWindowPos` — this is the whole reason for choosing inappwebview over `webview_windows` on Windows. A missing WebView2 Runtime / server-start failure is covered by the 10s ready-timeout (clears the loading mask) plus the `_loadError` placeholder. **Background color**: the webview stays **opaque** (no transparent-webview dependency) — the page CSS paints the theme base (`html,body{background:var(--app-background)}`, applied synchronously by `readBoot` before first paint); `WebKitWebViewController.setBackgroundColor` is avoided (it calls `setOpaque`, UnimplementedError on macOS).

> `assets/editor/` is a build artifact **checked into VCS** (regenerated by `dart tool/task.dart editor`, or `cd editor && pnpm build`) — rebuild and commit it whenever the editor source changes. Because it's committed, a plain checkout already has it, so CI/tests don't need a Node build just to bundle the app (the release build in `build.yml` still rebuilds it to guarantee freshness).

### Localization

Extracted into the **`moodiary_l10n`** foundation package (`packages/foundation/moodiary_l10n/`): the `intl_*.arb` files, `l10n.yaml` (`flutter: generate: true`), and the generated `AppLocalizations`. The barrel re-exports `AppLocalizations` plus the `BuildContext.l10n` helper; consumers import `package:moodiary_l10n/moodiary_l10n.dart`.
- Template: `intl_zh.arb`
- Supported: Chinese (`zh`), English (`en`)

### Dependency Injection

Services are registered as singletons via `get_it`:
- `moodiary_core` (`init.dart` + `di.dart`): storage layer (KV, SecureKV, Isar) — the shared `getIt` instance lives here.
- `mobile/lib/app/di/service_di.dart`: business services (HttpClient, Assistant, Sync). Lives in the app composition layer; it calls each package's public barrel registration fn (`registerRemoteSync()` from `moodiary_sync`, etc.). The assistant service lives in the `moodiary_assistant` package (`src/data/`).

Access via `getIt.get<T>()` or `T.get()` static methods on repositories (repositories live in `moodiary_data`).

### Sync System

The whole sync feature lives in the **`moodiary_sync`** package (one package): engine + Riverpod providers stay **widget-free** in `src/data`+`src/application`, UI in `src/presentation` (+ `SyncStatusButton`, `syncRoutes()`); the app boots it via the barrel's `registerRemoteSync()` in `service_di`. Supports LAN sync and cloud backup (WebDAV, S3). Key components:
- `SyncRegistry` / `registerRemoteSync()`: Backend registration
- `AutoSyncWatcher`: Watches for diary/category changes
- `IncrementalEngine`: Handles incremental sync with manifests and tombstones
