# CLAUDE.md

## Project Overview

Moodiary — a Flutter + Rust diary app. **Layered pub-workspace monorepo**: 27 shared packages under `packages/` across four dependency layers, consumed by the single Flutter app **`mobile/`** (Android + iOS, pub name `moodiary`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code). A desktop app will be rebuilt later — the packages are already layered for it, but no desktop target exists in the tree today.

## Tech Stack

- **Flutter 3.47.0 / Dart 3.13.0** (FVM, `.fvmrc`)
- **Rust** (pinned in `packages/foundation/moodiary_rust/rust/rust-toolchain.toml`), `flutter_rust_bridge` 2.13.0-beta.6 — native lib built & bundled via Native Assets build hooks (`rustup` required)
- **Android**: AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.0，内置 Kotlin（`android.builtInKotlin=true`）；daemon JVM 由 `gradle-daemon-jvm.properties` 钉在 21
- **Riverpod** (dev) + code gen, **go_router**, **get_it**, **SQLite**（drift + FTS5，schema 真源在 `moodiary_data` 的 `.drift` 文件），**Freezed** + **json_serializable**

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
dart tool/task.dart build-runner   # 全仓 build_runner（melos 扫所有含 build_runner 的包；只跑 mobile 会漏掉包侧注解）
dart tool/task.dart gen-rust       # regenerate Rust FFI bindings
dart tool/task.dart i18n           # slang 文案生成（改了 i18n/*.json 必跑）
dart tool/task.dart gen            # gen-rust + i18n + rebuild editor asset
dart tool/task.dart editor         # rebuild editor asset only (needs corepack on PATH)

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # 全仓 Dart 测试（CI 口径；SQLite 用例零门槛，仅 migration 的旧库用例要 ISAR_TEST_DYLIB）
dart tool/task.dart test-mobile    # 只跑 mobile/ 的测试
cd packages/foundation/moodiary_rust/rust && cargo test --workspace && cargo clippy --workspace --all-targets -- -D warnings
cd packages/feature_base/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test
```

Full-repo verification = the four blocks above (analyze + layers, `task.dart test`, Rust, editor). `flutter test` at the repo root finds nothing.

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
      moodiary_di/           #   get_it 容器的唯一实例（全仓最底层）
      moodiary_logging/      #   日志；落盘路径由组合根注入，故不认识文件布局
      moodiary_i18n/         #   i18n：slang 文案与取串入口（见下）
      moodiary_router/       #   typed route primitives over go_router
      moodiary_rust/         #   Rust FFI package (cargo workspace in rust/, built by hook/build.dart)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
      mui/                   #   设计系统：material_ui 的**补充**（详见下）
    core/                    # 无领域基建。内部次序 platform,http → storage → files → theme
      moodiary_platform/     #   应用目录/缓存目录/生物识别/网络状态/应用与设备信息
      moodiary_http/         #   IHttpClient / IHttpServer 端口，实现走 Rust
      moodiary_storage/      #   KV(MMKV) / SecureKV；数据库不在这（SQLite/drift 归 moodiary_data）
      moodiary_files/        #   文件布局 + 媒体管线 + 文件选择端口
      moodiary_theme/        #   系统取色、强调色档位、自定义字体 → ThemeData
    feature_base/            # → core/foundation。内部次序 models → data → components,migration,preferences → picker → editor
      moodiary_models/       #   domain: 纯 Freezed 模型 + DTOs + 事件类型（零存储依赖）
      moodiary_data/         #   SQLite（drift，src/db/*_tables.drift 是 schema 真源）+ repositories + controllers + 共享瞬态状态
      moodiary_components/   #   业务组件：features 共用、够不着 mui 的那部分 UI
      moodiary_migration/    #   one-shot legacy migration；legacy/ 冻结旧 Isar 模型（isar_plus 最后据点）
      moodiary_preferences/  #   preference state
      moodiary_picker/       #   相册选择器：骑 wechat_assets_picker 换皮 + image_picker 系统相机（仅 mobile 依赖）
      moodiary_editor/       #   TipTap webview 编辑器基建（EditorBody/controller/本地回环服务），被 diary 内嵌消费
    feature/                 # → feature_base/core/foundation (features never import each other)
      moodiary_export/       #   导出 Markdown/Word/PDF + 本地备份导入
      moodiary_diary/        #   diary CRUD/search/category/calendar/map/recycle
      moodiary_sync/         #   sync engine + UI
      moodiary_assistant/    #   AI assistant (flutter_chat_ui + rig)
      moodiary_media/        #   media library
      moodiary_lock/         #   app lock
      moodiary_share/        #   diary sharing
```

Path convention: unqualified `lib/...` refers to `mobile/lib/...`; `packages/` and `tool/` are repo-root-relative.

### Layer Dependencies

Cross-package DAG is strictly upper → lower: `foundation → core → feature_base → feature → apps`. Features never import each other (zero exceptions — `moodiary_editor` was demoted to feature_base precisely to kill the last one, `diary → editor`); shared logic sinks to lower layers, cross-feature composition happens in the app layer. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`**, which reads every pubspec's `moodiary_*`/`mui` deps (no baseline — must stay at zero). Melos `categories:` are filter/grouping only.

**core 与 feature_base 各有一条层内次序**（`_coreOrder` / `_featureBaseOrder`，同 tier 之间一律禁止互引）。两条边值得单记，它们都是**靠注入换来的**，改回去就会成环：

- **`storage` 在 `files` 之下**：Isar 的目录与 schema 列表都由组合根传入，所以存储层不认识文件布局。反过来 `files` 在 `storage` 之上，是因为 `MediaManager` 要读 `MoodiaryKVs.imageOptimize`。
- **`moodiary_logging` 能待在 foundation**，是因为 release 的落盘路径由 `AppLogger.configure` 注入。它一旦回去直接读 `AppFiles`，就得整包上浮到 core 之上，而那样几乎所有人都够不着它了。

**core 一个领域词都不认识**：`Diary` / `Category` / `Font` 都不在它的依赖图里。四个曾经的耦合点分别靠注入或上移解决了 —— schema 表进了 `moodiary_models`（`moodiarySchemas`），孤儿媒体清理进了 `moodiary_migration`，`FontManager` 只吐原始描述、装配成 `Font` 在 `moodiary_data`（`scanDiskFonts` / `themeDescriptor`）。

> 由此有一条会被反复重问的：**`moodiary_i18n` 的 namespace 带着 `diary` / `assistant` / `sync`
> 这些 feature 名，但它该留在 foundation，不是 core。** 那些领域知识是**数据**（json 的键），
> 不是**代码** —— 包本身零 `moodiary_*` 依赖，`Translations` 对 `Diary` 一无所知，删掉
> `diary_*.i18n.json` 照样编译；而 core 里被禁的那种耦合是**类型**依赖，会把编译期的边拽出来。
> 分层的维度是依赖方向，不是词汇纯度。反过来搬进 core 还会亏两头：破坏上面那句「一个领域词都
> 不认识」，且 core 同 tier 禁止互引，core 自己反而再也够不着它（今天够得着，只是没人用）。

In-app layering within `mobile/lib` (same script): `gen → core → data → component → feature/<x> → app → main.dart`. Baseline is **zero violations**.

### DI —— get_it + injectable（引导编排与拍板细节见 mobile/CLAUDE.md）

- **绑定注解落在实现类上**（`@Singleton(as:)` / `@LazySingleton(as:)` / `@Injectable(as:)`）；
  storage / http / assistant / sync 四包各是 micro-package，由 `mobile/lib/app/di/di.dart`
  一处挂载，**全仓只有一份 `configureDependencies`**。
- 改了注解**必跑 `dart tool/task.dart build-runner`**（生成物是提交的）。业务代码不手写
  `getIt.register*`；`IRemoteSyncBackend` 的运行时切换走 `RemoteSyncRegistry`，不进容器。
- **`@PostConstruct` 是刻意不用的**（watcher 会赶在迁移之前醒来）；启动阶段属于 main 的
  引导编排，不属于容器。

### mui —— material 的补充，不是替代（主题树细节见 packages/foundation/mui/CLAUDE.md，共存期硬点见 mobile/CLAUDE.md）

- **material 只经 `package:mui/mui.dart` 出，业务代码 import mui 不 import material**，
  `tool/check_layers.dart` 零基线守住（名单 4 条，都是第三方 API 只认 legacy 类型）。
- 组件：material_ui 够用的直接用，不够用才在 mui 里补，命名一律 `M` 开头。
- `ColorScheme` / `TextTheme` 是配色与排版真源；**`buildMuiTheme()` 是全仓唯一构造
  `ThemeData` 的地方**（闸门钉住）；取用写法
  `context.theme.typography.titleSmall.emphasized.primary`，`ThemeData` 装不下的收在 `MuiTokens`。
- mui 是零 `moodiary_*` 依赖的 foundation 叶子包，自带一份 slang 文案。

### i18n —— slang，不是 gen-l10n（两种模式与全部坑见 packages/foundation/moodiary_i18n/CLAUDE.md）

全仓两份互不相干的 slang 产物：App（moodiary_i18n，默认模式，`Translations` / 顶层 `l10n`）
与 mui（`locale_handling: false` + 手写 delegate，`context.muiL10n`）。词的分法：**i18n** 指
机制、**l10n** 指取到的文案对象、**Localizations** 只给真走 Flutter 那条链的（全仓只有 mui）。

- widget 里 `context.l10n.xxx`（切语言自动重建）；service / 导出 / 回调用顶层 `l10n.xxx`
  （不重建）。参数是具名的。取串把 `l10n.xxx.yyy` 写全，存局部别名会被 analyze 误报死键。
- namespace 一个 feature 一份文件；feature 包不各自装 slang（只有 mui 例外）。
- 改了 `*.i18n.json` **必跑 `dart tool/task.dart i18n`**（产物是提交的，没有闸门兜底）。
- **读者是谁决定走不走 slang**：给模型的（系统提示词 / 工具描述 / 工具返回文本）英文写死
  不进 i18n；给用户的走 slang。两者不共用字符串。
- 有些中文字面量是**刻意保留**的（同步日志行、字体族名、法律文本等），动手「补翻译」前先看
  moodiary_i18n 那份 CLAUDE.md 的清单。

### KV —— MMKV，且是同步的（后端四点与 2.8.0 搬迁全文见 packages/core/moodiary_storage/CLAUDE.md）

- **`IKVStorage.set` / `remove` / `clear` 返回 `void` 不是 `Future`**；`init` 与 SecureKV
  仍是异步的。「没有值」靠 `containsKey` 判（decode 系列不返回 null）。
- 加键只能用五种类型（int / bool / double / String / List<String>），多加一种只在运行时炸，
  有闸门守着。
- 机密不进明文 KV：应用锁 PIN 与两个第三方 API Key 归 `MoodiarySecureKVs`。widget 里走
  `secretKvProvider(key)`，**写完必须 `ref.invalidate`**（SecureKV 没有通知）。
- **PIN 别直接读写 `password`，走 `AppLockPin`**（存 Argon2id PHC 串）；「应用锁开没开」=
  有没有凭据（`AppLockPin.enabled`，进程内 ValueListenable，`main.dart` 里 load）。

### Rust —— 详见 packages/foundation/moodiary_rust/CLAUDE.md

原生库只有一个 .so，必须只有一个；业务 Rust 的所有权用六个门面表达
（foundation / assistant / export / sync / graph / rust / testing），零基线闸门在
`tool/check_layers.dart` 的 `_rustFacadeOwners`。workspace 分层、拆库与体积实测、
依赖收窄的四条结论都在 `packages/foundation/moodiary_rust/CLAUDE.md`（碰那棵目录树时自动加载）。
