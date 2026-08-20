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
      moodiary_di/           #   get_it 容器的唯一实例（全仓最底层）
      moodiary_logging/      #   日志；落盘路径由组合根注入，故不认识文件布局
      moodiary_l10n/         #   localization (slang，见下)
      moodiary_router/       #   typed route primitives over go_router
      moodiary_rust/         #   Rust FFI package (cargo workspace in rust/, built by hook/build.dart)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
      mui/                   #   设计系统：material_ui 的**补充**（详见下）
    core/                    # 无领域基建。内部次序 platform,http → storage → files → theme
      moodiary_platform/     #   应用目录/缓存目录/生物识别探测
      moodiary_http/         #   IHttpClient / IHttpServer 端口，实现走 Rust
      moodiary_storage/      #   KV(MMKV) / SecureKV / Isar 句柄；目录与 schema 都靠注入
      moodiary_files/        #   文件布局 + 媒体管线 + 文件选择端口
      moodiary_theme/        #   系统取色、强调色档位、自定义字体 → ThemeData
    feature_base/            # → core/foundation。内部次序 models → data → components,migration,preferences
      moodiary_models/       #   domain: Isar @Collection + Freezed DTOs + schema 注册真源
      moodiary_data/         #   repositories + controllers + 跨 feature 共享的进程级瞬态状态与端口
      moodiary_components/   #   业务组件：features 共用、够不着 mui 的那部分 UI
      moodiary_migration/    #   one-shot legacy data migration
      moodiary_preferences/  #   preference state
    feature/                 # → feature_base/core/foundation (features never import each other)
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

Cross-package DAG is strictly upper → lower: `foundation → core → feature_base → feature → apps`. Features never import each other (the one kept exception is `diary → editor`); shared logic sinks to lower layers, cross-feature composition happens in the app layer. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`**, which reads every pubspec's `moodiary_*`/`mui` deps (no baseline — must stay at zero). Melos `categories:` are filter/grouping only.

**core 与 feature_base 各有一条层内次序**（`_coreOrder` / `_featureBaseOrder`，同 tier 之间一律禁止互引）。两条边值得单记，它们都是**靠注入换来的**，改回去就会成环：

- **`storage` 在 `files` 之下**：Isar 的目录与 schema 列表都由组合根传入，所以存储层不认识文件布局。反过来 `files` 在 `storage` 之上，是因为 `MediaManager` 要读 `MoodiaryKVs.imageOptimize`。
- **`moodiary_logging` 能待在 foundation**，是因为 release 的落盘路径由 `AppLogger.configure` 注入。它一旦回去直接读 `AppFiles`，就得整包上浮到 core 之上，而那样几乎所有人都够不着它了。

**core 一个领域词都不认识**：`Diary` / `Category` / `Font` 都不在它的依赖图里。四个曾经的耦合点分别靠注入或上移解决了 —— schema 表进了 `moodiary_models`（`moodiarySchemas`），孤儿媒体清理进了 `moodiary_migration`，`FontManager` 只吐原始描述、装配成 `Font` 在 `moodiary_data`（`scanDiskFonts` / `themeDescriptor`）。

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

**共存期的三个硬点**：

1. `MaterialUiCompatibilityBridge` 挂在 `MaterialApp.builder`、**套在 `FlutterSmartDialog.init()`
   外面**（init 自建 Overlay，toast/loading 是与 child 平级的兄弟 entry）。它只映射
   platform / visualDensity / colorScheme / textTheme 四项，**25 个组件子主题不过桥** ——
   第三方 widget 保留我们的配色与排版，但组件级样式回落 Material 默认。它出厂即
   `@Deprecated`，依赖全部迁移后摘掉。
2. `localizationsDelegates` 里**只剩 material_ui 自带的 `GlobalMaterialLocalizations.delegates`**
   （已含 cupertino/widgets）。不能用 `flutter_localizations` 的同名类：那份给出 **legacy**
   类型，material_ui 的 widget 认不得，中文下会退化并让日期选择器一类直接抛。
   我们自己的文案走 slang，不再有 delegate。
3. **路由一律用 `MoodiaryGoRoute`，不用裸 `GoRoute`**（moodiary_router/src/route_page.dart）。
   go_router 靠 `findAncestorWidgetOfExactType<MaterialApp>()` 猜宿主类型来决定 `builder:`
   路由包成哪种 Page，它认的是 legacy `MaterialApp`；我们挂的是 material_ui 的同名新类，
   探测于是落到 WidgetsApp 分支，**所有页面被包成 `NoTransitionPage`，切页没有动画**。
   `MoodiaryGoRoute` 直接给出 `MaterialPage`，转场重新走
   `ThemeData.pageTransitionsTheme`。`mobile/test/app/router/router_test.dart`
   里有条闸门守着「每条路由都带 pageBuilder」。

   同一处探测还牵着另外两样，也都自己接了回来：

   - **hero 飞行**：go_router 装的是不带 `createRectTween` 的裸 `HeroController`，
     弧线退成直线。它在自己 Navigator 之上的 `HeroControllerScope` 里，外面盖不住；
     好在 Hero 自带的 `createRectTween` 优先级更高（heroes.dart 的
     `_HeroFlightManifest`），所以**跨页 hero 一律用 `MHero`**，别用裸 `Hero`。
   - **错误页**：默认会落到无样式的 widgets 版 `ErrorScreen`。`buildRouter` 里给了
     `errorPageBuilder`（不是 `errorBuilder`——后者仍由 go_router 包 Page，一样没转场），
     页面是 `mobile/lib/app/router/route_error_page.dart`。

> 官方的 `dart fix --code=migrate_design_widgets` **当前不生效**：转换规则在 SDK 里
> （`fix_data/fix_material/fix_material.yaml`），但 `material.dart` 还没标 `@Deprecated`，
> 数据驱动 fix 挂不上诊断。实测加了 material_ui 依赖也一样 `Nothing to fix!`。

### i18n —— slang，不是 gen-l10n

文案由 **slang 4.19** 生成，`flutter_localizations` 退回只服务 material 组件自己的字串
（且它不会从依赖图消失：material_ui 与 slang_flutter 都依赖它）。

全仓有**两份**互不相干的 slang 产物，各自 `slang.yaml`：

| | 源文件 | 产物 | 符号 |
|---|---|---|---|
| App | `moodiary_l10n/lib/i18n/<ns>_{zh,en}.i18n.json` | `strings.g.dart` | `Translations` / `AppLocale` / `l10n` |
| mui | `mui/lib/src/l10n/i18n/{zh,en}.i18n.json` | `mui_strings.g.dart` | `MuiTranslations` / `MuiAppLocale` / `muiL10n` |

App 那份按 **namespace 一个 feature 一份文件**：`common`（无领域含义的基础词）+
`app` / `diary` / `assistant` / `export` / `sync` / `media` / `editor` / `ui` / `lock` /
`onboarding` / `share`。取串写成 `l10n.diary.searchResult`；**删 feature 就删它那两个文件**。

**feature 包不各自装 slang**（只有 mui 例外，因为它是零 `moodiary_*` 依赖的对外叶子包）：
每份 slang 都会生成自己的 `TranslationProvider`，得在 `main.dart` 手工逐个嵌套，
漏挂是**运行时抛**而不是编译错。namespace 已经给到分域的全部好处，不必付这个代价。

- **取串按有没有 context 分**：widget 里用 `context.l10n.xxx`（依赖 `TranslationProvider`，
  切语言自动重建）；service / 导出 / 回调里用顶层的 `l10n.xxx`（**不会重建**）。
- **参数是具名的**：`l10n.diarySearchResult(count: n)`。gen-l10n 时代的位置参数已全部改完。
- **语种真源是 slang 的 `GlobalLocaleState` 单例**，跨包共享 —— `applyStoredLanguage()`
  调一次 App 那份 `LocaleSettings.setLocale`，App 与 mui 两棵树一起刷新（slang_flutter
  的 `_GlobalKeyHandler` 也是进程级单例，会遍历所有已注册 provider 逐个 `updateState`）。
  **但这一条挂在 mui 的 `lazy: false` 上**，见下面第 3 点。KV 里只存偏好枚举。
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
3. **非 base 语种的翻译类默认是 deferred import**（`lazy: true`），所以 App 那份一律用
   异步的 `setLocale`，别用 `setLocaleSync`（它绕开 `loadLibrary()`）。
   **mui 那份必须 `lazy: false`**，因为**我们在 `runApp` 之前就切语种**：那时一个
   `TranslationProvider` 都还没构造（GlobalKey 在 `BaseTranslationProvider` 的构造器里
   才注册），`updateProviderState` 遍历的是空集合。App 那棵没事——它自己那份 `setLocale`
   会 `await loadLocale`；mui 那棵没人替它调，`translationMap` 里只有 base(zh)，
   `map[current] ?? map[base]` 一路回落，英文用户在每个 mui 组件里看到中文，冷启动必现、
   进设置改一次语言才好（那时 provider 已挂载，`updateState` 会补上 `loadLocale`）。
   闸门在 `mui/test/l10n_test.dart`。
4. `timestamp` 与 `flat_map` 默认都是 `true`：前者让提交的产物每次生成都有噪声 diff，
   后者多生成一份全量 `Map<String, String>`。两个都在 `slang.yaml` 里关掉了。
5. **`analyze` 是按 `l10n.` 前缀做子串匹配的，存成局部别名它就瞎了**：写
   `final t = l10n.assistant;` 再 `t.toolUntitled`，那个键会被报成未使用，照着删就是运行时
   少一句文案。取串一律把 `l10n.xxx.yyy` 写全。

**读者是谁，决定这串走不走 slang**（助手这边尤其容易混）：

| 读者 | 例子 | 怎么写 |
|---|---|---|
| 模型 | 系统提示词、工具描述、入参 schema、工具**返回文本** | 英文写死在源码里，不进 i18n |
| 用户 | 提示条上的类型词与摘要、错误提示 | 走 slang |

工具返回文本进的是对话上下文，翻译它等于按用户语言改模型的输入；而同一次调用在界面上
显示成什么，是 `AssistantTool.summarize` 另算的一份、走 l10n。两者**不共用字符串**。

**哪些中文字面量该留着**（扫描器会一直报它们，别每次都重新判断一遍）：

- **同步引擎的日志行**：事件按天写成 jsonl 落盘，message 已烤进历史记录；翻译只影响新条目，
  日志页会中英混排。日志页自己的标题 / 筛选 / 分组名是 UI，已翻。
- **助手里读者是模型的那些串**（`moodiary_assistant/lib/src/data/`）：系统提示词、工具描述、
  工具入参 schema、工具返回的文本，**一律英文写死，不进 slang**（见上面「读者是谁」一节）。
  扫描器不会报它们，但别顺手「补翻译」。
- **不是文案的字符串**：`'宋体'` 是字体族名、`'『压测』'` 是压测日记的标题标记（翻了就认不出
  历史数据）、ICP 备案号是法律标识、`logger.e` / `assert` 的文字进的是日志文件。
- **`agreement_page` / `privacy_page` 里内联的用户协议与隐私政策全文**：法律文本，机翻不算数。

> slang 自带的 `dart run slang migrate arb` **不能用**：它按 camelCase 把键强行拆成嵌套路径
> （`accentCustomTitle` → `accent.custom.title`），既改掉全部调用点，又会在
> `accentCustom` / `accentCustomTitle` 这种前缀重叠上直接抛异常。当年是脚本平铺转的。

### KV —— MMKV，且是同步的

2.8.0 起本地 KV 落在 **MMKV**（`mmkv: 2.4.1`），后端换掉之后接口跟着变了形：

**`IKVStorage.set` / `remove` / `clear` 返回 `void`，不是 `Future`。** MMKV 是 mmap +
增量 append，没有平台通道往返可等，落盘交给内核。由此 `KVNotifier` 的监听者在赋值当帧
就收到通知（旧后端要等一个平台往返，开关类 UI 肉眼可见地滞后）。`init` 仍是异步的
（要等平台侧给出 rootDir），`ISecureKVStorage` 也保持全异步——那边是真的钥匙串调用。

后端实现在 `moodiary_storage/lib/src/kv/mmkv.dart`，四个不报错的点：

1. **「没有值」得靠 `containsKey` 判**：`decodeBool` / `decodeInt` 一类不返回 null，
   取不到就给 defaultValue，直接读会把「没设过」和「设成了 false / 0」混为一谈。
2. **MMKV 没有字符串数组类型**：`List<String>` 存成 JSON 文本。解不出来当作没有值
   （回退 defaultValue），不让一格坏数据把整条读取路径带崩。
3. **mmapID（`moodiary`）与 rootDir（`applicationSupport/mmkv`）改了就等于弃数据。**
   rootDir 是显式钉的：MMKV 默认落 `${Documents}/mmkv`，而 iOS 的 Documents 用户在
   「文件」App 里看得见、还会进 iCloud 备份。
4. **加键只能用那五种类型**（int / bool / double / String / List&lt;String&gt;）：类型分派是
   `switch (T)` 加一个抛异常的 default，多加一种不会有编译错误，只会在运行时炸。
   `moodiary_storage/test/kv_migration_test.dart` 里有条闸门守着。

**2.8.0 的一次性搬迁整个在 `MmkvKVStorage._migrateFromPrefsOnce` 里**，一轮四步：
读旧仓库 → 机密进 SecureKV（`SecretKVMigration`）→ 明文进 MMKV → `clearStore()` 删掉旧仓库
→ 置 `__migrated_from_prefs`。

- **不能挂进 `VersionMigrator`**：判版本用的 `appVersion` 自己就存在 KV 里，搬完之前读不到，
  挂过去会把老用户误判成全新安装。
- **整轮共用一个标记，中途失败就整轮重来**，所以**机密必须排在明文之前** ——
  写钥匙串是唯一可能整体失败的一步，让它在任何东西落地之前失败，重试才干净；反过来
  先搬明文的话，重试会拿旧仓库的值覆盖掉用户在这中间改过的配置。机密失败时
  `SecretKVMigration` 一律上抛，调用方亮 `legacyMigrationPending` 并整轮跳过 —— 吞掉的话
  应用锁会变成「开着但没有密码」，用户直接进不去。
- **搬完直接删旧仓库**：那里躺着明文 PIN / API Key / WebDAV 密码。两个平台都不允许降级
  安装、卸载重装又等于清数据，没有回滚路径要照顾。`resetAllData` 仍调一次 `clearStore()`，
  兜住「重置发生在搬迁完成之前」；`MmkvKVStorage.clear()` 要把标记补回去，否则重置后的
  那次启动会重跑搬迁。
- `shared_preferences` 依赖只为这次搬迁留着，窗口过后连同 `legacy_pref.dart` 一起删。

**机密不进明文 KV**：应用锁 PIN（`password`）与两个第三方 API Key（`qweatherKey` /
`tiandituKey`）2.8.0 起归 `MoodiarySecureKVs`，已从 `MoodiaryKVs` 删除。它们在 2.7.3 是明文
写进旧仓库的，而枚举驱动的明文那趟不再经手它们，所以 `LegacyPrefsKVSource` 有一份
**字面量** `_legacyKeys`（读的 allowList 与清除共用）。别改成从枚举推导 —— 那只是「旧名字
碰巧等于新名字」，给枚举改个名就静默地少读一个键、少清一个键，不报错。闸门在
`secret_migration_test.dart`。

取值分两种：事件回调里直接 `await MoodiarySecureKVs.xxx.get()`；widget 里走
`secretKvProvider(key)`（moodiary_data），**写完必须 `ref.invalidate`** —— SecureKV 没有
`KVNotifier` 那套通知，不 invalidate 界面不刷新。

**PIN 别直接读写 `MoodiarySecureKVs.password`，走 `AppLockPin`**：存的是 Argon2id 的
PHC 串（`rust.Argon2.hash`，盐随机且写在串里），不是原文。钥匙串已经加密了它，多这一层
是因为加密可逆而哈希不可逆 —— 四位 PIN 挡不住爆破，真正防的是**PIN 复用**（应用锁 PIN
常常就是手机解锁 PIN）。原语可注入（`AppLockPin.hasher` / `verifier`），宿主单测没有
Rust FFI，同 `SyncKeyManager` 的做法。

**「应用锁开没开」= 有没有凭据**（`AppLockPin.enabled`），没有独立的 `lock` 开关。
那个开关早先在 MMKV 而凭据在钥匙串，两边存活条件不同：MMKV 是普通文件、恢复备份照样
带过来，钥匙串的密文却要 Keystore 私钥来解，而那把钥匙不进备份。一旦分叉就是「锁开着
但没有密码」——校验对任何输入都 false，用户永久进不去，只能卸载重装。现在读不出凭据
就是没开锁（fail-open）：应用锁本就不保护静态数据，能拿到 App 文件的人直接读 Isar 就行。
`enabled` 是进程内的 `ValueListenable`（路由与生命周期回调都是同步的，够不着异步的
SecureKV），由 `main.dart` 里的 `AppLockPin.load()` 装载，不落盘所以不会再分叉。
**因此搬迁只在旧 `lock` 为真时才搬 PIN** —— 否则等于替关着锁的用户把锁打开。

**搬迁把 PIN 原样挪过去，哈希推迟到 `verify` 头一次比对时就地做**（`isHashed` 分辨）。
不在搬迁里哈希是有原因的：那会让 KV 初始化依赖 Rust 桥先就绪，等于让一次性迁移的需求
永久钉死 `main.dart` 的启动顺序，而那个顺序只有注释守着 —— 谁调换一下，`Argon2.hash`
抛 `StateError`，整轮搬迁被静默跳过、每次启动都一样。代价只是 PIN 在钥匙串里明文待到
下次解锁，而开着锁的用户下一次启动就是解锁。

### Rust Workspace

`packages/foundation/moodiary_rust/rust/` is both the cargo workspace root **and** the bridge package `moodiary_rust` — that shape is load-bearing: the Native Assets hook runs `cargo build --manifest-path rust/Cargo.toml --package moodiary_rust` and requires `Cargo.toml` + `rust-toolchain.toml` at `hook/build.dart`'s `cratePath`, so keeping `rust/` as the root means the hook and `flutter_rust_bridge.yaml` need no changes.

```
rust/
  src/api/            # bridge = app layer: the ONLY place that knows about FRB
  crates/
    foundation/       # http (reqwest client + hyper server) / crypto / archive / media / text / font
                      #   js —— QuickJS 沙箱（rquickjs）。三道闸门在 JsSandbox::new 一次装齐；
                      #   **别开 rust-alloc**：那会让 set_memory_limit 静默变成 no-op
    core/             # doc (导出 IR，Dart export_doc.dart 的镜像)
    feature/          # sync (s3+webdav) / export (pdf+docx) / assistant (rig) / graph
```

Same direction rule as Dart, enforced by the same script: `foundation → core → feature → bridge`, features never import each other, zero violations.

### moodiary_rust —— 一个 .so，六扇门

**原生库只有一个，而且必须只有一个。** 2026-08-20 实测（Android arm64、仓库真实
profile 与 feature 集）：拆成两个 cdylib、共享 crate 走普通 cargo 依赖是 **+95.6%**
（rustls/reqwest/tokio 在两个库里各一份，`strings | grep rustls` 各 65 次）；给共享
crate 手写 `extern "C"` 再动态链接能收回 82%，但仍 **+17.1%**，而那点余量的 99% 是
**每库固定地板**——一个什么都不干的 Android cdylib 就要 294 KB（std + libunwind +
compiler-builtins 每库静态各带一份）。Rust ABI 的 `dylib` + `-C prefer-dynamic` 是死路：
rustc 在 `lto="thin"` 下直接拒绝，强行关掉 LTO 是 +170%。**拆库是投递策略，不是省体积
手段。** 而且真正的大头 typst 只有一个消费者，去重一个字节都省不到。

所以「业务 Rust 归对应的包」这件事**不能用包边界表达**，用门面表达：

| 门面 | 内容 | 谁能推 |
|---|---|---|
| `foundation.dart` | cancel / crypto / font / http / http_server / image / text / zip | 全仓 |
| `assistant.dart` | rig 对话流 + QuickJS 沙箱 | 只有 `moodiary_assistant` |
| `export.dart` | pdf(typst) / docx / 导出 IR | 只有 `moodiary_export` |
| `sync.dart` | s3 / webdav | 只有 `moodiary_sync` |
| `graph.dart` | 力导向布局 | 只有 `moodiary_diary` |
| `rust.dart` | `RustLib.init()` | 只有 app 组合根 |
| `testing.dart` | 分词替身 | 只有 `moodiary_data` 的测试 |

零基线闸门在 `tool/check_layers.dart` 的 `_rustFacadeOwners`，另带一条「不许绕过门面
深入 `package:moodiary_rust/src/`」。**没有 `moodiary_rust.dart` 这个总 barrel 了** ——
它以前让 `moodiary_storage` 够得着 `PdfBuilder` 和 `rigChatStream`。

> **content hash 只覆盖 api 函数名**（codegen 对排序后的函数名做 SHA1 取前四字节），
> 参数类型、返回类型、结构体定义都不在里面。所以「改了签名但没改名、且只提交了一半
> 生成物」不会被它抓到。`tool/check_generated.dart` 现在比对两侧 hash 相等来堵住
> 「只提交一半」；要堵死签名漂移得在 CI 装 codegen 重跑 + `git diff --exit-code`，
> 那要付一次没有缓存的 cargo install，暂时没做。

Two invariants worth keeping:
- **Sub-crates never mention `StreamSink` / `DartFnFuture`.** They take plain closures (`impl FnMut(T) -> bool`, `Arc<dyn Fn(..) -> BoxFuture<..>>`); `src/api/` adapts those to FRB.
- **FFI-visible types are declared in the sub-crate and re-exposed via `#[frb(mirror(T))]` in `src/api/`.** Mirror emits identical Dart to a local declaration, so no DTO is duplicated and no `From` conversion is needed. Opaque handles (`S3Client`, `Zip`, …) are thin newtypes in `src/api/` that delegate.

All third-party versions are exact-pinned (`=x.y.z`) in `[workspace.dependencies]`; sub-crates use `{ workspace = true }` and add only the features they need.

