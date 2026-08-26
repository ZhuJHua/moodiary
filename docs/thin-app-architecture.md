# Moodiary — Thin Composition App Design

> **STATUS: ✅ EXECUTED (all phases 0–7 shipped).** `mobile/lib` now has zero `feature/` slice; `moodiary_diary`/`moodiary_sync`/`moodiary_lock`/`moodiary_share` extracted, `moodiary_editor_host` merged into `moodiary_editor`, `user`/`web_view` deleted; the settings hub relocated to `app/settings` and the diary home to `app/home`; `tool/layer_baseline.txt` is empty (0 violations). This doc is kept as the design record; the numbered roadmap in §6 is history.

> **SINCE THEN (2026-07-28).** The body below is a snapshot of the state at execution time; these parts have changed and the doc was deliberately *not* rewritten:
> - `flutter_quill` is gone from the whole repo. `merge/merge.dart` moved to `moodiary_migration` (`src/version_migrator.dart`, class `VersionMigrator`) and now validates/wraps Delta with the pure-Dart `QuillDelta` helper; legacy richText diaries render by converting to TipTap on open.
> - The `desktop/` skeleton was deleted — a desktop app will be rebuilt later. Everything below about desktop is *intent*, not current code. `moodiary_scan` no longer exists either.
> - `XxxUtil` classes were renamed to role-based names (`FileUtil`→`AppFiles`, `MergeUtil`→`VersionMigrator`, …), so identifiers quoted below may not resolve.
> - Package layer direction is now machine-enforced by `tool/check_layers.dart`, not just by convention.
> - **(2026-08-26)** DI 从手写 `registerX()` barrel 迁到 get_it + **injectable**：`app/di/service_di.dart`
>   / `basic_service.dart` 已删，绑定是实现类上的注解（storage/http/assistant/sync 四个
>   micro-package + `mobile/lib/app/di/di.dart` 单份 config），启动引导在 `bootstrap.dart` +
>   `main.dart`；下文 §5(b) 与所有 `registerRemoteSync()` / `AutoSyncWatcher.create()` 示例
>   均为历史。现行参考 CLAUDE.md 的「DI —— get_it + injectable」一节。

**Goal:** `mobile/lib` retains *no* `feature/` slice. It becomes a composition root plus the two app-owned presentation surfaces the vision explicitly permits (导航布局 + 设置页). Every self-contained capability sinks into a package; both apps assemble the *same* packages into their own shells.

**Taxonomy rule (settled):** **one feature = one self-contained package** — engine / logic / UI all inside. A package may hold multiple or adaptive UIs; we do **not** split a package merely because desktop rebuilds its UI (YAGNI — desktop is still a skeleton). We only keep the headless engine code **widget-free inside** its package (`src/data`+`src/application`), so a future engine-only split for desktop stays a trivial `git mv`.

---

## 1. Executive Summary

- **`mobile/lib` collapses to ~11 hand-written files**: `main.dart` + `app/{router,shell,di,lifecycle}` + `app/home/diary_home_page.dart` + `app/settings/*` + `merge/` + `gen/`. No `feature/` directory survives.
- **4 new packages** — `moodiary_diary`, `moodiary_sync`, `moodiary_lock`, `moodiary_share`. **`moodiary_editor_host` merges back into `moodiary_editor`** (−1). **2 dead features deleted** (`user`, `web_view`). Final workspace: 15 − 1 + 4 = **~18 packages**.
- **The diary home-host and the settings page STAY app-side** — not packaged. They are *assembled surfaces* (mobile nav chrome); desktop rebuilds its own over the same shared controllers.
- **`moodiary_editor`** = one complete editor (webview + `editor_body`/toolbar/record + `EditController` + 分类/地理天气). **`moodiary_sync`** = one complete sync (engine + logic + UI); the engine part (`IncrementalEngine`/codec/backends/`AutoSyncWatcher` + Riverpod providers) stays **widget-free** inside `src/data`+`src/application`, the UI in `src/presentation`.
- **Zero feature→feature dependencies.** The only three coupling channels are all indirected: `moodiary_router` string route contracts, the shared `getIt` + per-package `registerX()`, and app-side composition of self-contained exported widgets (`SyncStatusButton`, `AppLockTile`, `AssistantSummaryTile`).
- **Both baseline cross-feature edges dissolve** (diary-home→sync, settings→lock) into app-side composition — `tool/layer_baseline.txt` goes **2 → 0**.

---

## 2. The Thin `mobile/lib`

```
mobile/lib/
  main.dart                            # composition root: init order, launch-gate, MaterialApp.router
  app/
    di/service_di.dart                 # DI root → each package's registerX() barrel fn
    router/router.dart                 # buildRouter(): concat every pkg's xRoutes() + bind cross-owner builders
    shell/root_shell.dart              # MobileRootShell: bottom-nav IndexedStack of feature entry widgets
    lifecycle/app_lock_observer.dart   # mobile lock-on-background policy (skip-list from route contracts)
    home/
      diary_home_page.dart             # mobile diary TAB: moodiary_diary bodies + SyncStatusButton + FAB + segmented AppBar
    settings/
      settings_page.dart               # aggregation HUB: nav via contracts + embedded feature tiles
      font_page.dart  diary_setting_page.dart  services_page.dart
      about/{about,privacy,agreement,sponsor}_page.dart
      widget/{dashboard_section, color_sheet, language_dialog, theme_mode_dialog,
              data_repair_tile, reset_data_tile, rebuild_index_tile, cache_usage_tile}.dart
      settings_routes.dart             # app-owned routes for the mobile settings sub-pages
  core/values/{assistant,diary_type_icon}.dart      # unchanged holdouts
  merge/merge.dart                     # mobile-only legacy Isar v2.4.8→2.8.0 migration (keeps flutter_quill in MOBILE pubspec)
  gen/{assets,fonts}.gen.dart          # per-app FlutterGen assets
```

| What stays | Why it cannot / should-not be a package |
|---|---|
| `main.dart` | The composition root — boots `RustLib.init` + `injectBasicService` + `MergeUtil.runVersionMigration` + `registerService` + `MaterialApp.router`. A package cannot boot the app; desktop writes its own. |
| `app/router/router.dart` | The *set* of routes IS the app's identity. Aggregates `...diaryRoutes()/syncRoutes()/…` and binds `AssistantDiaryPickerRoute → DiarySelectPage`. |
| `app/di/service_di.dart` | The *choice* of implementations is the app's identity. Calls each package's `registerX()`. |
| `app/shell/root_shell.dart` | Bottom-nav tab set = mobile chrome. Desktop builds a NavigationRail from the same entry widgets. |
| `app/lifecycle/app_lock_observer.dart` | Mobile lock-on-background policy; touches the global `router` singleton + startup. |
| **`app/home/diary_home_page.dart`** | **App-owned presentation** — welds diary bodies + `SyncStatusButton` + FAB into the mobile segmented-AppBar home. The *last* diary↔sync seam AND mobile nav layout with zero desktop reuse. |
| **`app/settings/*`** | **App-owned presentation** — the aggregation HUB + mobile-chromed leaf pages/pickers over already-shared controllers (`moodiary_preferences`/`moodiary_data`). The vision literally names 设置页 as app presentation. |
| `merge/merge.dart` | One-shot legacy Isar migration; pulls `flutter_quill` (`Document.fromJson`). Desktop has no legacy install base → never runs it. Keeps `flutter_quill` a mobile-only dep. |
| `gen/`, `core/values/*` | Per-app generated assets / legacy holdouts. Per-app by definition. (`component/quill_embed/*` already moved into `moodiary_editor`.) |

**`application/`?** No. No cross-cutting app-level application logic remains — the residual view-state controllers (`search_controller`, `calendar_controller`) belong to `moodiary_diary`; the reactive/settings controllers already live in `moodiary_data` / `moodiary_preferences`. The app's only "application" code is DI + router wiring under `app/`.

---

## 3. New / Changed Packages

| Name | Layer | From | Contents | Owns routes? | Desktop | Effort | Risk |
|---|---|---|---|---|---|---|---|
| **moodiary_editor** *(merge)* | feature | `moodiary_editor` + `moodiary_editor_host` | The **complete editor**, one package: webview (`src/` current) + `editor_body`/toolbar/`record_sheet`/quill_embed + `EditController` (autosave→repo) + category picker + geo/weather + `MoodiaryEditorView`. `editor_host` is deleted; its consumers import `moodiary_editor`. | migration route only | ✅ full (same webview both apps) | M | med |
| **moodiary_diary** | feature | `feature/diary` (4164 LOC) *minus* the mobile tab scaffold | Detail `DiaryPage` (uses `moodiary_editor`), search/category/analyse/map/recycle/manager/calendar pages, `DiarySelectPage`, view bodies (`DiaryListView`/`DiaryWaterFallView`/`CalendarView`), `ViewModeSheet`, `diary_card` (injected `onTap`), `openDiaryDetail`, extracted `DiaryCategorySectionView`, the 2 view-controllers (`search_controller`, `calendar_controller` + `.g/.freezed`), `diaryRoutes()`. Deps: ui/core/data/models + **moodiary_editor** (acyclic) + flutter_map/latlong2/calendar_date_picker2/font_awesome_flutter/waterfall_flow/substring_highlight. **Never depends on sync.** | ✅ | ✅ full | XL | med |
| **moodiary_sync** | feature | `feature/sync` (6005 LOC) — whole | **One package.** `src/data`+`src/application` = headless engine (`IncrementalEngine`, codec/cipher, WebDAV/S3/json-file backends + `registerRemoteSync()`, `AutoSyncWatcher`, `SyncLogger`, tombstone/remote_lease, `sync_stores` ports) **+ Riverpod providers** (`syncControllerProvider`/`syncStatsProvider`/`userKeyControllerProvider` + `SyncState`/`SyncStats`) — kept **widget-free**. `src/presentation` = `backup_sync_page`, S3/WebDAV form sheets, `sync_status_sheet`+`showSyncStatusSheet`, `SyncStatusButton`, `sync_log_page`, user-key flows, `syncRoutes()`. Deps: core/models/data/rust/ui + scan (QR key) + router + pool/synchronized/file_picker/share_plus. | ✅ | engine reused; desktop adds its own UI (same package) | L | med |
| **moodiary_lock** | feature | `feature/lock` (855 LOC) *minus* observer + launch-gate | `LockPage` (PIN + biometric), `StartPage` (onboarding), **`AppLockTile`** + Set/Remove/Change password sheets (self-inject via KV + `AuthUtil` + `LockPinPad`), `lockRoutes()`. Deps: core/utils/ui/router only. `AppLockObserver` + `_resolveInitialLocation` stay app-side. | ✅ | ✅ (credential core; unlock UI restyled) | M | low |
| **moodiary_share** | feature | `feature/share` (204 LOC) | `SharePage` (FutureProvider → RepaintBoundary → PNG → share_plus; copy `contentText`) + `shareRoutes()`. Deps: models/core/data/ui + share_plus. Currently orphaned — wire an entry button in diary detail during composition. | ✅ | ✅ (logic; UX differs) | S | low |
| ~~user~~ | — | `feature/user` (171 LOC) | **DELETE.** Dead placeholder — `UserRoute` unreachable, `LoginPage` is a "账户体系暂未启用" stub; reset duplicates settings. Prune `UserRoute`/`LoginRoute` contracts. | — | — | — | — |
| ~~web_view~~ | — | `feature/web_view` (83 LOC) | **DELETE.** Trivial `url_launcher` indirection, one caller. Rewire `about_page.dart:121` to `launchUrl(...)` directly; prune `WebViewRoute`. | — | — | — | — |

**Settings does NOT become a package** — it relocates to `app/settings/` as app presentation (see §4/§7). **Three pieces leave `feature/setting` for *existing* packages:**
- `dashboard_controller.dart(+.g.dart)` → **`moodiary_data`** (a read-model, matches the reactive-controller precedent).
- editor-migration tool (`editor_migration_service` + `editor_migration_page` + `migration_compare_page`) → **`moodiary_editor`** (its compare page hard-depends on `EditorBody`/`MoodiaryEditorView`); relocate `EditorMigrationRoute` into `moodiary_editor`'s `routes.dart`.
- AI-summary tile in `services_page` → **`moodiary_assistant`** as an exported `AssistantSummaryTile`.

---

## 4. The Composition Model (the heart)

Every feature package barrel exposes a uniform surface (the `moodiary_assistant` reference): **(a)** entry widget(s), **(b)** `xRoutes()`, **(c)** route contracts, **(d)** `registerX()`. The app's composition root does exactly four jobs and never imports a feature's internals.

### (a) Routes — aggregation via `xRoutes()`

```dart
// app/router/router.dart
GoRouter buildRouter() => GoRouter(
  initialLocation: _resolveInitialLocation(),
  routes: [
    GoRoute(path: '/', builder: (_, __) => const MobileRootShell()),
    ...diaryRoutes(),      // moodiary_diary
    ...syncRoutes(),       // moodiary_sync
    ...lockRoutes(),       // moodiary_lock
    ...shareRoutes(),      // moodiary_share
    ...assistantRoutes(),  // moodiary_assistant
    ...mediaRoutes(),      // moodiary_media
    ...editorRoutes(),     // moodiary_editor (migration route)
    ...settingsRoutes(),   // APP-owned (app/settings/settings_routes.dart)
    // Cross-owner builder: contract in assistant, page in diary → the app is the ONLY co-importer
    GoRoute(path: AssistantDiaryPickerRoute.path, builder: (_, __) => const DiarySelectPage()),
  ],
);
```

**Contract-ownership policy:** cross-feature-referenced contracts stay in `moodiary_router` (foundation leaf); package-internal-only contracts live in the owning package's `routes.dart` (the assistant precedent). A feature navigates to any page via `const BRoute().push(context)` without importing B.

### (b) DI — each package registers itself

```dart
// app/di/service_di.dart
void registerService() {
  getIt.registerSingleton<IHttpClient>(DioHttpClient());
  registerAssistantService();        // moodiary_assistant
  registerRemoteSync();              // moodiary_sync barrel
  getIt.registerSingleton(SyncLogger());
  AutoSyncWatcher.create()..start();  // the package ships the class; the APP boots it
  drainReindexQueue();
}
```

The package *ships* the classes; the app *boots* them. `service_di` calls public barrels only.

### (c) Shell/Nav — compose entry widgets

```dart
// app/shell/root_shell.dart
final _pages = [
  const DiaryHomePage(),            // app/home — composes moodiary_diary bodies + sync button
  const MediaPage(),                // moodiary_media entry widget
  const AssistantSessionListPage(), // moodiary_assistant entry widget
  const SettingsPage(),             // app/settings — the aggregation hub
];
// IndexedStack + NavigationBar. Desktop composes the SAME widgets into a NavigationRail.
```

### (d) Cross-feature composition — no feature→feature deps

The **composition root is the sole place two feature packages meet.** Three concrete seams:

**1. Diary-home shows sync status** — resolved by keeping the home scaffold app-side. `app/home/diary_home_page.dart` imports `moodiary_diary` (bodies) *and* `moodiary_sync` (`SyncStatusButton`); it assembles the AppBar. `moodiary_diary` itself carries zero sync types.

```dart
// app/home/diary_home_page.dart  (APP-SIDE — the only diary+sync co-import)
AppBar(
  title: _HomeSegmentedControl(...),      // from moodiary_diary
  actions: const [
    SyncStatusButton(),                    // moodiary_sync — self-watches syncControllerProvider,
    _ViewModeButton(),                     //   calls showSyncStatusSheet; no wiring needed
  ],
),
body: switch (viewMode) {
  ViewModeType.list     => const DiaryListView(),        // moodiary_diary
  ViewModeType.grid     => const DiaryWaterFallView(),   // moodiary_diary
  ViewModeType.calendar => const CalendarView(),         // moodiary_diary
},
floatingActionButton: FloatingActionButton(onPressed: () => openNewDiaryEditor(context)),
```

**2. Settings embeds per-feature tiles** — nav rows push `moodiary_router` contracts; live controls are feature-exported tiles the app drops in verbatim.

```dart
// app/settings/settings_page.dart  (APP-SIDE hub)
_PrivacySection(children: const [
  AppLockTile(),                 // moodiary_lock barrel — self-injects via KV + AuthUtil + LockPinPad
]),
_MoreSection(children: [
  ListTile(title: Text(l10n.backup), onTap: () => const BackupSyncRoute().push(context)), // contract → sync page
  ListTile(title: Text(l10n.font),   onTap: () => const FontRoute().push(context)),        // contract → app page
  const AssistantSummaryTile(),  // moodiary_assistant barrel — exported tile
]),
```

**No slot/registry indirection is introduced.** Because the home and settings surfaces are *app-side*, the app is naturally the co-importer — a self-contained exported widget (`SyncStatusButton`, `AppLockTile`, `AssistantSummaryTile`) is a parameterless `const` embed. Matches the `diary_card` injected-`onTap` / editor callback-decoupled precedent, no runtime `SettingsContribution` registry (deferred until tile count justifies it).

---

## 5. How Desktop Reuses the Same Features

Desktop depends on **every feature package** — `moodiary_editor`, `moodiary_diary`, `moodiary_sync`, `moodiary_lock`, `moodiary_share`, `moodiary_assistant`, `moodiary_media`, `moodiary_scan` — plus the full foundation/core/ui stack, and reuses `moodiary_router` route *contracts* verbatim so deep-links stay identical. It writes its **own** composition root: a desktop `main.dart` (no `merge/`, its own init order), its own router aggregating the same `xRoutes()` fragments, its own DI calling the same `registerX()` fns, and its own **NavigationRail / multi-pane shell** composing the same entry widgets.

It rebuilds only the mobile-specific presentation it cannot reuse — the diary home *screen* and the settings *hub* (both app-side, not packaged). For **sync**, desktop reuses `moodiary_sync`'s engine + providers (`syncControllerProvider` → identical state semantics) and either uses the package's mobile sync screens or adds its own desktop sync UI **inside the same `moodiary_sync` package** (the widget-free engine boundary makes an engine-only split trivial later if ever needed). It never imports anything under `mobile/lib`.

---

## 6. Sequenced Roadmap

Each phase is independently shippable and green (`dart tool/task.dart analyze` + `flutter test`). Ordered low→high risk. **Move-as-is codegen** = `git mv` the `.dart` + its `.g.dart`/`.freezed.dart` together, **no `build_runner` rerun**.

| # | Phase | Does | Move-as-is? | Risk |
|---|---|---|---|---|
| **0** | **Prune dead code** | Delete `feature/user` + `feature/web_view`; drop `UserRoute`/`LoginRoute`/`WebViewRoute` + their `xRoutes()`; rewire `about_page.dart:121` → `url_launcher`. | — | low |
| **1** | **moodiary_share** | Extract the 204-LOC slice + `shareRoutes()`; wire the orphaned `ShareRoute` to a diary-detail button. Proves the pattern on the smallest surface. | — | low |
| **2** | **moodiary_lock** | Extract `LockPage`/`StartPage`/`AppLockTile`/sheets + `lockRoutes()`. `AppLockObserver` + launch-gate stay app-side. Settings embeds `const AppLockTile()` → **dissolves setting→lock**. | — | low |
| **3** | **editor merge** | Merge `moodiary_editor_host` **into** `moodiary_editor` (one complete editor package); delete `moodiary_editor_host`; repoint its 3 consumers (`migration_compare`, diary detail, home FAB) to `moodiary_editor`. | ✅ (edit `.g/.freezed`) | med |
| **4** | **moodiary_sync** | Extract the whole `feature/sync` → one `moodiary_sync` package: engine+providers in `src/data`+`src/application` (widget-free), UI in `src/presentation` (+`SyncStatusButton`, `syncRoutes()`). `service_di` calls the barrel's `registerRemoteSync()`. Severs diary→sync's *internal* import. | ✅ (sync `.g`) | med |
| **5** | **moodiary_diary** | Extract diary pages + bodies + view-controllers + `diaryRoutes()`; leave `DiaryListPageMobile`/`_DiaryListView` as `app/home/diary_home_page.dart` (composing package bodies + `const SyncStatusButton()`) → **dissolves the last diary→sync edge**. Confirm `diary→editor` acyclic. | ✅ (search/calendar/analyse/map `.g/.freezed`) | med |
| **6** | **setting teardown** | 6a: migration tool → `moodiary_editor` (+ `EditorMigrationRoute`); 6b: `dashboard_controller(+.g)` → `moodiary_data`; 6c: AI tile → `moodiary_assistant` (`AssistantSummaryTile`); 6d: **relocate the rest of `feature/setting` → `mobile/lib/app/settings/`** + app-owned `settingsRoutes()`. Delete the now-empty `feature/`. | ✅ (dashboard `.g`) | med |
| **7** | **Thin-app cleanup** | Collapse `router.dart`/`service_di.dart` to pure barrel calls; rebuild `app_lock_observer` skip-list from route contracts; drive `tool/layer_baseline.txt` → **0**; `melos bootstrap`; confirm no `mobile/lib/feature/` remains. | — | low |

---

## 7. Risks & What NOT To Do

### The two contested calls — resolved

- **Diary home-host does NOT become a package** (`app/home/diary_home_page.dart` stays app-side). It welds three features + is mobile segmented-AppBar/bottom-FAB chrome with **zero desktop reuse**; keeping it app-side dissolves the diary→sync seam with **zero injection plumbing** (the app is naturally the co-importer). Only the reusable inner pieces (bodies, calendar, `DiaryCategorySectionView`) sink into `moodiary_diary`.
- **Settings does NOT become `moodiary_settings`** — it relocates to `app/settings/`. The vision keeps 设置页 as app presentation; desktop rebuilds its own over the same controllers. The hub is already ~90% decoupled (nav rows = `moodiary_router` contract pushes; one live embed = `AppLockTile`). Only the 3 genuinely-shared pieces leave.

### Over-packaging traps — do NOT

- **Do NOT** make `moodiary_diary` depend on `moodiary_sync`. The sync button is composed app-side; a feature→feature dep re-introduces the edge you just removed.
- **Do NOT** create `moodiary_settings`, and **do NOT** package the composition root (main/router/di/shell) — you cannot package "the act of composing."
- **Do NOT** move `diary_card` into `moodiary_ui` — it is domain-coupled (`Diary`/`Category`, `categoryColorOf`/`FileUtil`); it stays in `moodiary_diary` with injected `onTap`.
- **Do NOT** extract `user`/`web_view` — delete them.

### Correctness risks — hold the line

- **Keep the sync engine widget-free inside `moodiary_sync`.** The engine + Riverpod providers (`syncControllerProvider` etc.) live in `src/data`+`src/application` with **no `flutter/material`/`flutter/widgets` import** — so desktop can reuse sync state headlessly and a future engine-only split is a trivial `git mv`. Grep to enforce.
- **Byte-identical Isar schema:** every generated file moves via **`git mv` with NO `build_runner` rerun**. Re-running risks a byte-different Isar schema (a real DB migration) and shifts Riverpod provider identity that `ProviderScope` overrides + watchers depend on. Load-bearing for sync/diary/dashboard controllers. **Never** re-run `build_runner` over `moodiary_models`.
- **`diary → editor` acyclic:** diary (detail page + home FAB + migration tool) depends on `moodiary_editor`; verify `moodiary_editor` has no `diary` import before adding the pubspec dep — a cycle fails pub resolution.
- **`app_lock_observer` skip-list `{'/lock','/edit','/share'}`** is string-coupled to paths moving into packages — reassemble it from `moodiary_router` contracts, not literals, or background-lock silently skips the wrong screens.

### Mobile-only holdouts — do NOT share

- **`merge/merge.dart`** keeps `flutter_quill` (`Document.fromJson`) — a mobile-only one-shot legacy migration; desktop's pubspec omits `flutter_quill`. **Do NOT** put it in any shared package.
- **`gen/`** and `core/values/*` are per-app artifacts — desktop generates its own.

### Net end-state

`mobile/lib` = composition root (`main` + `app/{di,router,shell,lifecycle}`) + two app-owned presentation surfaces (`app/home`, `app/settings`) + mobile-only holdouts (`merge`, `gen`, legacy `core/values`). **Zero `feature/` slice, zero cross-feature baseline edges, ~18 packages, desktop composes the same 8 feature packages into its own shell.**
