# CLAUDE.md

## Project Overview

Moodiary — a Flutter + Rust diary app. **Layered pub-workspace monorepo**: 20 shared packages under `packages/` across four dependency layers, consumed by the single Flutter app **`mobile/`** (Android + iOS, pub name `moodiary`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code). A desktop app will be rebuilt later — the packages are already layered for it, but no desktop target exists in the tree today.

## Tech Stack

- **Flutter 3.47.0 / Dart 3.13.0** (FVM, `.fvmrc`)
- **Rust** (pinned in `packages/foundation/moodiary_rust/rust/rust-toolchain.toml`), `flutter_rust_bridge` 2.13.0-beta.6 — native lib built & bundled via Native Assets build hooks (`rustup` required)
- **Android**: AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.0，内置 Kotlin（`android.builtInKotlin=true`）；daemon JVM 由 `gradle-daemon-jvm.properties` 钉在 21
- **Riverpod** (dev) + code gen, **go_router**, **get_it**, **Isar**, **Freezed** + **json_serializable**

## Commands

```bash
# Setup
fvm use
dart tool/task.dart setup          # flutter pub get + build editor

# Run & Build (targets mobile app)
dart tool/task.dart run            # build editor + flutter run
dart tool/task.dart build-apk / build-ios  # 只有 android/ios 两个目标
# Extra flutter flags go after --:  dart tool/task.dart run -- --release

# Code Gen (after model/router/provider changes)
dart tool/task.dart build-runner   # build_runner build（2.16.0 起 --delete-conflicting-outputs 已移除）
dart tool/task.dart gen-rust       # regenerate Rust FFI bindings
dart tool/task.dart l10n           # slang 文案生成（改了 i18n/*.json 必跑）
dart tool/task.dart gen            # gen-rust + l10n + rebuild editor asset
dart tool/task.dart editor         # rebuild editor asset only (needs corepack on PATH)

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # mobile/ tests ONLY — not the full suite
melos exec --dir-exists=test --fail-fast -c 1 -- flutter test   # 全仓 Dart 测试（CI 口径，自动发现）
cd packages/foundation/moodiary_rust/rust && cargo test --workspace && cargo clippy --workspace --all-targets -- -D warnings
cd packages/feature/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test
```

Full-repo verification = the four blocks above (analyze + layers, melos test sweep, Rust, editor). `flutter test` at the repo root finds nothing.

**Melos**: `melos bootstrap` activates the workspace and regenerates IDE module files — pure, no codegen; run `dart tool/task.dart gen` separately. `melos list` / `melos run <script> --category <layer>` filter by layer.

**Versions** are exact-pinned everywhere; the root `melos` caret is the only exception.

## Architecture

### Directory Layout

```
moodiary/                    # root = workspace + Melos coordinator (no app code)
  tool/                      # cross-platform task runner + layer check
  mobile/                    # pure-mobile Flutter app (pub: moodiary)
    lib/
      app/                   # composition layer: di, router, shell, lifecycle
        home/                # home tab (diary_home_page)
        settings/            # settings hub
      main.dart
  packages/
    foundation/              # leaf layer — no internal deps
      moodiary_lint/         #   shared analyzer options
      moodiary_l10n/         #   localization (slang，见下)
      moodiary_router/       #   typed route primitives over go_router
      moodiary_rust/         #   Rust FFI package (cargo workspace in rust/, built by hook/build.dart)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
      mui/                   #   设计系统：material_ui 的**补充**（详见下）
    core/                    # → foundation; internal order models → core → data,migration → preferences
      moodiary_models/       #   domain: Isar @Collection + Freezed DTOs
      moodiary_core/         #   infra: Isar/KV/SecureKV + theme + exceptions
      moodiary_data/         #   repositories + controllers + 跨 feature 共享的进程级瞬态状态
      moodiary_migration/    #   one-shot legacy data migration
      moodiary_preferences/  #   preference state
    ui/                      # → core/foundation
      moodiary_ui/           #   只剩够不着 mui 的 7 个组件（要 core 基建或 riverpod）
    feature/                 # → ui/core/foundation (features never import each other)
      moodiary_export/       #   导出 Markdown/Word/PDF + 本地备份导入
      moodiary_editor/       #   TipTap webview editor (complete)
      moodiary_diary/        #   diary CRUD/search/category/calendar/map/recycle
      moodiary_sync/         #   sync engine + UI
      moodiary_assistant/    #   AI assistant (flutter_chat_ui + rig)
      moodiary_media/        #   media library
      moodiary_lock/         #   app lock
      moodiary_share/        #   diary sharing
```

Path convention: unqualified `lib/...` refers to `mobile/lib/...`; `packages/` and `tool/` are repo-root-relative.

### Layer Dependencies

Cross-package DAG is strictly upper → lower: `foundation → core → ui → feature → apps`. Features never import each other (the one kept exception is `diary → editor`); shared logic sinks to lower layers, cross-feature composition happens in the app layer. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`**, which reads every pubspec's `moodiary_*` deps (no baseline — must stay at zero). Melos `categories:` are filter/grouping only.

In-app layering within `mobile/lib` (same script): `gen → core → data → component → feature/<x> → app → main.dart`. Baseline is **zero violations**.

### mui —— material 的补充，不是替代

Flutter 3.47 把 Material 拆成独立包 `material_ui`，SDK 内的
`package:flutter/material.dart` 将于 2026-11 弃用。全仓的规矩因此是：

**material 只经 `package:mui/mui.dart` 出。业务代码 import mui，不 import material。**
由 `tool/check_layers.dart` 零基线守住，名单外出现一处 legacy import 就红。名单目前 4 条
（wechat 的三个 picker 文件 + assistant 的 chat 页），都是第三方 API 只认 legacy 类型。

主题是**一棵树**：

- **`ColorScheme` 是配色真源，`TextTheme` 是排版真源**，mui 不再自建色板。
  `context.theme.colors` 返回的就是 material 的 `ColorScheme` 本体。
- `ThemeData` 装不下的东西收在单个 `MuiTokens extends ThemeExtension`：七张 token 表
  （圆角/间距/动效/描边/投影/状态）、`onMedia`，以及 **`MuiFontConfig`**——可变字体的 wght
  轴值只有宿主读过 ttf 才知道，`ThemeData` 没有槽位放它，漏了 `.emphasized` 会静默出错字重。
- `buildMuiTheme()` 是**全仓唯一构造 `ThemeData` 的地方**（闸门钉住），
  25 个组件子主题都在里面。
- `context.theme` 是 `Theme.of(context)` 的只读派生视图，按 `ThemeData` 实例 memoize。
  取用写法：`context.theme.typography.titleSmall.emphasized.primary`。
- **没有 `MuiAnimatedTheme`**：`MaterialApp` 已经把 `builder` 包在 `AnimatedTheme` 里，
  深浅切换的过渡是免费的。

组件：material_ui 够用的直接用（`Switch` / `Scaffold` / `AppBar`…），不够用的才在 mui 里补，
命名一律 `M` 开头（`MMenuButton`、`MAlert.show(...)`）。mui 是**零 `moodiary_*` 依赖**的
foundation 叶子包，所以它自带一份 slang 文案（十来个通用词），不吃 App 的文案包 —— 见下面
「i18n」一节。

**共存期的两个硬点**：

1. `MaterialUiCompatibilityBridge` 挂在 `MaterialApp.builder`、**套在 `FlutterSmartDialog.init()`
   外面**（init 自建 Overlay，toast/loading 是与 child 平级的兄弟 entry）。它只映射
   platform / visualDensity / colorScheme / textTheme 四项，**25 个组件子主题不过桥** ——
   第三方 widget 保留我们的配色与排版，但组件级样式回落 Material 默认。它出厂即
   `@Deprecated`，依赖全部迁移后摘掉。
2. `localizationsDelegates` 里**只剩 material_ui 自带的 `GlobalMaterialLocalizations.delegates`**
   （已含 cupertino/widgets）。不能用 `flutter_localizations` 的同名类：那份给出 **legacy**
   类型，material_ui 的 widget 认不得，中文下会退化并让日期选择器一类直接抛。
   我们自己的文案走 slang，不再有 delegate。

> 官方的 `dart fix --code=migrate_design_widgets` **当前不生效**：转换规则在 SDK 里
> （`fix_data/fix_material/fix_material.yaml`），但 `material.dart` 还没标 `@Deprecated`，
> 数据驱动 fix 挂不上诊断。实测加了 material_ui 依赖也一样 `Nothing to fix!`。

### i18n —— slang，不是 gen-l10n

文案由 **slang 4.19** 生成，`flutter_localizations` 退回只服务 material 组件自己的字串
（且它不会从依赖图消失：material_ui 与 slang_flutter 都依赖它）。

全仓有**两份**互不相干的 slang 产物，各自 `slang.yaml`：

| | 源文件 | 产物 | 符号 |
|---|---|---|---|
| App | `moodiary_l10n/lib/i18n/{zh,en}.i18n.json` | `strings.g.dart` | `Translations` / `AppLocale` / `l10n` |
| mui | `mui/lib/src/l10n/i18n/{zh,en}.i18n.json` | `mui_strings.g.dart` | `MuiTranslations` / `MuiAppLocale` / `muiL10n` |

- **取串按有没有 context 分**：widget 里用 `context.l10n.xxx`（依赖 `TranslationProvider`，
  切语言自动重建）；service / 导出 / 回调里用顶层的 `l10n.xxx`（**不会重建**）。
- **参数是具名的**：`l10n.diarySearchResult(count: n)`。gen-l10n 时代的位置参数已全部改完。
- **语种真源是 slang 的 `GlobalLocaleState` 单例**，跨包共享 —— `applyStoredLanguage()`
  调一次 `LocaleSettings.setLocale`，App 与 mui 两棵树一起刷新。KV 里只存偏好枚举。
  `MaterialApp.locale` 从 `TranslationProvider.of(context).flutterLocale` 取。
- 改了 `*.i18n.json` **必须跑 `dart tool/task.dart l10n`**（产物是提交的，且没有闸门兜底）。
- 查死键要开 `--full`（不开只比对语种间差集），并把源码目录指回仓库 —— 默认只扫当前包的
  `lib/`，那里一个调用点都没有。在 `moodiary_l10n` 下跑，约 9 秒：

  ```bash
  dart run slang analyze --full --source-dirs=../../../packages,../../../mobile
  ```

  它是**去空白后的子串匹配**，所以 mui 的 `muiL10n.back` 里含 `l10n.back`，会让 App 侧同名
  的死键假装被用了。取名时别让别的变量以 `translate_var` 收尾。

四个不报错的坑：

1. **`TranslationProvider` / `LocaleSettings` / `AppLocaleUtils` 三个类名在生成器里是硬编码的**，
   只有 `class_name` / `enum_name` / `translate_var` 可配。所以 mui 的生成物**不进 barrel**，
   对外只露 `MuiTranslationScope`（裸导出会和 App 那份撞成 ambiguous import）。
2. **复数是英文的需求，中文被顺带拖进来**：slang 要求同一个键在所有语种里节点形状一致，
   所以 `1 entry / 2 entries` 这类键的中文侧也是复数节点（只有 `other`）。而 slang 的内置
   复数规则表里没有 zh（只有 ar cs de en es fr he it ja pl ru sv uk vi），渲染中文时**每次
   都走一遍 `print`** 再用兜底（`log.error` 就是裸 print，release 也打）。`setupPluralResolvers()`
   就是来说「zh 一律取 other」的，在 `runApp` 之前登记即可（与 `setLocale` 先后无关，
   但它不会通知已挂载的 provider）。
3. **非 base 语种的翻译类是 deferred import**（`lazy: true`），所以一律用异步的
   `setLocale`，别用 `setLocaleSync`（它绕开 `loadLibrary()`）。
4. `timestamp` 与 `flat_map` 默认都是 `true`：前者让提交的产物每次生成都有噪声 diff，
   后者多生成一份全量 `Map<String, String>`。两个都在 `slang.yaml` 里关掉了。

> slang 自带的 `dart run slang migrate arb` **不能用**：它按 camelCase 把键强行拆成嵌套路径
> （`accentCustomTitle` → `accent.custom.title`），既改掉全部调用点，又会在
> `accentCustom` / `accentCustomTitle` 这种前缀重叠上直接抛异常。当年是脚本平铺转的。

### Rust Workspace

`packages/foundation/moodiary_rust/rust/` is both the cargo workspace root **and** the bridge package `moodiary_rust` — that shape is load-bearing: the Native Assets hook runs `cargo build --manifest-path rust/Cargo.toml --package moodiary_rust` and requires `Cargo.toml` + `rust-toolchain.toml` at `hook/build.dart`'s `cratePath`, so keeping `rust/` as the root means the hook and `flutter_rust_bridge.yaml` need no changes.

```
rust/
  src/api/            # bridge = app layer: the ONLY place that knows about FRB
  crates/
    foundation/       # http (reqwest client + hyper server) / crypto / archive / media / text / font
    core/             # doc (导出 IR，Dart export_doc.dart 的镜像)
    feature/          # sync (s3+webdav) / export (pdf+docx) / assistant (rig) / graph
```

Same direction rule as Dart, enforced by the same script: `foundation → core → feature → bridge`, features never import each other, zero violations.

Two invariants worth keeping:
- **Sub-crates never mention `StreamSink` / `DartFnFuture`.** They take plain closures (`impl FnMut(T) -> bool`, `Arc<dyn Fn(..) -> BoxFuture<..>>`); `src/api/` adapts those to FRB.
- **FFI-visible types are declared in the sub-crate and re-exposed via `#[frb(mirror(T))]` in `src/api/`.** Mirror emits identical Dart to a local declaration, so no DTO is duplicated and no `From` conversion is needed. Opaque handles (`S3Client`, `Zip`, …) are thin newtypes in `src/api/` that delegate.

All third-party versions are exact-pinned (`=x.y.z`) in `[workspace.dependencies]`; sub-crates use `{ workspace = true }` and add only the features they need.

