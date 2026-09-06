# CLAUDE.md

## Project Overview

Moodiary — a Flutter + Rust diary app. **Layered pub-workspace monorepo**: 33 shared packages under `packages/` across four dependency layers, consumed by the single Flutter app **`mobile/`** (Android + iOS, pub name `moodiary`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code). A desktop app will be rebuilt later — the packages are already layered for it, but no desktop target exists in the tree today.

## Tech Stack

- **Flutter 3.47.2 / Dart 3.13.0** —— `.fvmrc` 钉的是 3.47.2，`mobile/pubspec.yaml` 的下限约束才是 3.47.0，别把两者混为一谈
- **Rust 1.95.0 stable**（不是 nightly；每个原生库包的 `rust/rust-toolchain.toml` 各一份，`tool/check_generated.dart` 保证一致），`flutter_rust_bridge` 2.13.0 — 原生库经 Native Assets 构建钩子构建并打包（需要 `rustup`）
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
dart tool/task.dart licenses       # 第三方许可清单（Rust crates + 编辑器 npm；改了 Cargo.toml / package.json 依赖才要跑）
dart tool/task.dart editor         # rebuild editor asset only (needs corepack on PATH)

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # 全仓 Dart 测试（CI 口径；SQLite 用例零门槛，仅 migration 的旧库用例要 ISAR_TEST_DYLIB）
dart tool/task.dart test-mobile    # 只跑 mobile/ 的测试
for d in packages/foundation/*/rust; do (cd $d && cargo clippy --all-targets -- -D warnings && cargo test); done  # 六个包，别写成 fast_*：那样会漏掉 moodiary_rust
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
      fast_image/            #   图片管线：派生物 / 区域解码 / 分片看图页，自带 FRB 与原生库 libfastimage
      fast_press/            #   导出压印：IR → PDF(typst) / DOCX，自带 FRB 与原生库 libfastpress（只给 moodiary_export）
      moodiary_rust/         #   业务库：http 客户端/服务端 → WebDAV/S3 / rig 对话（共享一套 reqwest 底座）+ 图布局，libmoodiary_rust（四个门面各有主，延迟装载）
      fast_tokenizer/        #   jieba 分词 + HF tokenizer，自带 FRB 与原生库 libfasttokenizer（启动装载，带测试替身）
      fast_crypto/           #   AES-GCM + Argon2id，自带 FRB 与原生库 libfastcrypto（门面自带 ensureInitialized，调用方不用 init）
      fast_zip/              #   zip 写/解压，自带 FRB 与原生库 libfastzip（只给 moodiary_export / moodiary_sync）
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
      mui/                   #   设计系统：material_ui 的**补充**（详见下）
      moodiary_sqlite_vec/   #   sqlite-vec 0.1.9：vendor 源码 + 构建钩子编成 code asset，供本地 RAG 向量检索
    core/                    # 无领域基建。内部次序 platform,http → storage → files → theme
      moodiary_platform/     #   应用目录/缓存目录/生物识别/网络状态/应用与设备信息
      moodiary_http/         #   IHttpClient / IHttpServer 端口，实现走 Rust
      moodiary_storage/      #   KV(MMKV) / SecureKV；数据库不在这（SQLite/drift 归 moodiary_data）
      moodiary_files/        #   文件布局 + 媒体管线 + 文件选择端口
      moodiary_theme/        #   系统取色、强调色档位、自定义字体 → ThemeData
    feature_base/            # → core/foundation。内部次序 models,ml → data → components,migration,preferences → picker → editor
      moodiary_models/       #   domain: 纯 Freezed 模型 + DTOs + 事件类型（零存储依赖）
      moodiary_data/         #   SQLite（drift，src/db/*_tables.drift 是 schema 真源）+ repositories + controllers + 共享瞬态状态
      moodiary_components/   #   业务组件：features 共用、够不着 mui 的那部分 UI；代码高亮表与 DiaryShare 挂钩也在这
      moodiary_migration/    #   one-shot legacy migration；legacy/ 冻结旧 Isar 模型（isar_plus 最后据点）
      moodiary_preferences/  #   preference state
      moodiary_ml/           #   本地 ML：onnxruntime_plus 嵌入/情感引擎 + 模型下载与激活（独家 own onnxruntime_plus）
      moodiary_picker/       #   相册选择器：骑 wechat_assets_picker 换皮 + image_picker 系统相机（仅 mobile 依赖）
      moodiary_editor/       #   TipTap webview 编辑器基建（EditorBody/controller/本地回环服务），被 diary 内嵌消费
    feature/                 # → feature_base/core/foundation (features never import each other)
      moodiary_export/       #   导出 Markdown/Word/PDF/图片 + 本地备份与 Markdown 导入；**分享也在这里**（= scope 只有一篇的导出）
      moodiary_diary/        #   diary CRUD/search/category/calendar/map/recycle
      moodiary_sync/         #   sync engine + UI
      moodiary_assistant/    #   AI assistant (flutter_chat_ui + rig)；runJavascript 沙箱走 flutter_js 自家 fork（git 钉 commit，quickjs-ng code asset）
      moodiary_media/        #   media library
      moodiary_lock/         #   app lock
```

Path convention: unqualified `lib/...` refers to `mobile/lib/...`; `packages/` and `tool/` are repo-root-relative.

### Layer Dependencies

Cross-package DAG is strictly upper → lower: `foundation → core → feature_base → feature → apps`. Features never import each other (zero exceptions — `moodiary_editor` was demoted to feature_base precisely to kill the last one, `diary → editor`); shared logic sinks to lower layers, cross-feature composition happens in the app layer. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`**, which reads every pubspec's `moodiary_*`/`mui` deps (no baseline — must stay at zero). Melos `categories:` are filter/grouping only.

**core 与 feature_base 各有一条层内次序**（`_coreOrder` / `_featureBaseOrder`，同 tier 之间一律禁止互引）。两条边值得单记，它们都是**靠注入换来的**，改回去就会成环：

- **`storage` 在 `files` 之下**：Isar 的目录与 schema 列表都由组合根传入，所以存储层不认识文件布局。反过来 `files` 在 `storage` 之上是历史次序（`MediaManager` 曾读 `imageOptimize`，2026-09-02 随图片优化开关一起删了），今天 files 已不 import storage，但层内次序保持不动。
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
  storage / http / ml / data / assistant / sync / editor / theme 八包各是 micro-package，由
  `mobile/lib/app/di/di.dart` 一处挂载，**全仓只有一份 `configureDependencies`**。
- **容器管整张对象图**：`MoodiaryDatabase`（app 的 `AppModule.database`，preResolve）、
  14 个仓储（`@lazySingleton`，构造器注入 DB / IHttpClient）、进程级持有者（Registry /
  Tracker / Cancellation，`@singleton`）都在容器里。取用一律 `getIt<X>()`：容器内的类走
  构造器注入，Riverpod Notifier / widget 写 `late final _repo = getIt<X>()`。**Riverpod 只管
  界面状态**，不再有仓储 provider（2026-09-04 撤掉薄 provider 桥与全部静态 `.get()` 门面）。
  测试：仓储自测 `XxxRepository(MoodiaryDatabase.forTesting(...))`；上层测试
  `getIt.registerSingleton<XxxRepository>(替身)` + `tearDown(getIt.reset)`。
  **全仓没有 `X.get()` 静态门面**（端口的 `IHttpClient.get()` 一类也已删）；`MoodiaryKVs.x.get()`
  是键访问器不是容器门面，保留。
- 改了注解**必跑 `dart tool/task.dart build-runner`**（生成物是提交的）。业务代码不手写
  `getIt.register*`，**唯一例外是会话型 scope**：injectable 的 `@Scope` 进不了 micro-package，
  「当前同步 provider」这种会话由手写的 `activateSyncProvider()` 开 get_it scope 表达——基础层
  各实现 `@Named(SyncProviderIds.x)`（名字与枚举 value 同源），scope 里以无名
  `IRemoteSyncBackend` 暴露选中的那个，切换 = pop 再 push；上层只写 `getIt<IRemoteSyncBackend>()`。
- **`@PostConstruct` 是刻意不用的**（watcher 会赶在迁移之前醒来）；启动阶段属于 main 的
  引导编排，不属于容器。

### mui —— material 的补充，不是替代（主题树细节见 packages/foundation/mui/CLAUDE.md，共存期硬点见 mobile/CLAUDE.md）

- **material 只经 `package:mui/mui.dart` 出，业务代码 import mui 不 import material**，
  `tool/check_layers.dart` 零基线守住（名单随依赖迁移持续收缩，当前 1 条：`moodiary_picker` 的 `picker_theme.dart`，wechat_assets_picker 的 pickerTheme 只吃 legacy ThemeData）。
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

### Rust —— 若干 `fast_*` 包，各自一个原生库

原则（2026-09-03 拍板，账在 `docs/native-libs-review.md`）：**允许拆分，但不重复依赖**。有独立价值的
能力各自成包；共享一套网络底座的 http / sync / llm 合在 `moodiary_rust` 里（包内 `http → sync / llm`
分层，实测这是唯一一处真实的二进制重复，2 MiB），graph 也放那里（不值得单独一个库）。每个包自带一个 crate、一个原生库、一份 hook /
about.toml / rust-toolchain / Cargo.lock，坑各记在自己的 CLAUDE.md：

| 包 | 桥 | 归属 | 装载 |
|---|---|---|---|
| moodiary_rust | FRB | 门面各有主：http.dart → moodiary_http / sync.dart → moodiary_sync / llm.dart → moodiary_assistant / graph.dart → moodiary_diary（`_rustFacadeOwners`） | 首次请求 / 起服务 / 对话 / 开图谱 |
| fast_tokenizer | FRB | 全仓（含 `testing.dart` 替身） | 启动 `FastTokenizer.ensureInitialized` |
| fast_image | FRB | 全仓 | 启动 `FastImageRuntime.init` |
| fast_press | FRB | moodiary_export（`_nativePkgOwners`） | 首次导出 |
| fast_zip | FRB | moodiary_export / moodiary_sync（`_nativePkgOwners`） | 首次打包 / 解压 |
| fast_crypto | FRB | 全仓 | 门面每次调用自己 ensureInitialized |

- **FRB 包**：每个暴露 `XxxLib` 与幂等的 `Xxx.ensureInitialized()`；不透明句柄（`CancelToken`
  之类）跨不了 .so，每库一枚，且是同步构造——**库没装载就构造会抛**，先 await 再 new。
  改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`（名单 `tool/task.dart` 的 `_frbPkgDirs`）。
- **全部走 FRB**（2026-09-03 拍板：裸 dart:ffi 省的只是 0.3 MB 地板，不值得手写 C ABI）。
- **跨包版本一致**：没有 `[workspace.dependencies]` 了，同一 crate 在多个包里各钉一次；
  `tool/check_generated.dart` 比对所有 `fast_*/rust/Cargo.toml` 的同名 crate、toolchain channel、
  FRB / ffigen 的 pubspec 钉版本，漂了就红。
- **换了 Rust 依赖 / `[patch]` / profile 之后 APK 体积没变，先怀疑钩子缓存**：hooks_runner 的缓存在
  workspace 根的 `.dart_tool/hooks_runner/`，`flutter clean` 碰不到；各 hook 已显式登记 Cargo.toml /
  Cargo.lock 为依赖，改动能触发重跑，仍不放心就 `dart tool/task.dart clean`。
- 拆库是投递策略，不是省体积手段：每库地板（带 FRB 运行时）实测 619 KB；两库之间共享 crate 的
  实际字节看 `docs/native-libs-review.md` 第四节，依赖树重叠不等于二进制重复。改了任何 `rust/Cargo.toml` 依赖必跑
  `dart tool/task.dart licenses`。
- **zip 必须留在 Rust**（2026-09-04 复决）：局域网归档用的是 zip 条目级 AES-256，纯 Dart 只有 17 MB/s
  且整条目进堆（实测见 `docs/native-libs-review.md` 第五节）。当时的撤回判据是「让 `lanProtoVersion`
  停在 2、与 2.8.0 互通」，**那个前提 2.8.1 里已经不成立**（`lanProtoVersion` 现为 3，见下），
  但性能与内存那条独立成立，所以 zip 仍留在 Rust。
- **`lanProtoVersion` 现为 3**（2.8.1，`3062d85e`）：地点重构要挡住 2.8.0 用 position 快照覆盖
  placeId 引用，顺势 bump 并**删掉了「没带 `x-moodiary-proto` 头就当协议 2 放行」的宽容**——
  `lan_receiver._admit` 现在要求头存在且严格等于 3，2.8.1 与 2.8.0 之间局域网传输一定 426。
  注意 `LanPeer.compatible` 仍放行 `proto == null`，那只管发现列表的置灰：2.8.0 广播不带 TXT
  attributes，在附近设备里是正常颜色可点的，不兼容要握手才暴露。