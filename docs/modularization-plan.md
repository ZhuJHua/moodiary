# Moodiary 模块化拆分计划 (v2.8.0 后续)

> 面向 `refactor/2.8.0/new_arch` 之后的架构演进。目标：把更多共享代码**下沉进 package**，让 `mobile/` 与待重建的 `desktop/` 复用；瘦身 feature 巨石；清零分层违规（尤其 `app/router` 耦合与 feature↔feature 边）。
>
> 本文由多代理深度调研综合而成（7 个区域读者 → 3 个不同哲学的架构方案 → 综合裁决），关键事实已核验。

---

## 0. 现状勘校（与 CLAUDE.md 的偏差 + 核验结论）

- **包数量已从 9 → 12**：`foundation` 新增 `moodiary_router`；`feature` 新增 `moodiary_assistant`（原在 app 内）。CLAUDE.md 的“9 个包”描述已过时。
- **`moodiary_assistant` 已经是目标范式的样板**：它自带 `src/routes.dart`（`assistantRoutes()` + 基于 `moodiary_router.MoodiaryRouteBase` 的路由契约），app 的 `router.dart` 只做 `...assistantRoutes()` 聚合并 re-export barrel。**后续每个 feature 抽包都照抄这个配方。**
- **已核验的具体主张**（Phase 0/1 依赖）：
  - `HomeNavigatorBar` / `DiaryCategoryTabBar` / `DiaryMapItem` — 外部引用 **0**（死代码，确认）。
  - `mobile/lib/core/values/diary_type_icon.dart`、`mobile/lib/component/basic/lottie_modal.dart` — 引用 **0**（死代码 holdout，确认）。
  - `package:moodiary/app/router/router.dart` — 被 **15** 个 feature 文件 import（确认，= `layer_baseline.txt` 27 条中的 15 条）。

---

## 1. 执行摘要

四步动作承载约 90% 的价值，按此顺序做：

1. **导航缝合优先（keystone）**：把 `mobile/lib/app/router/router.dart` 里约 40 个 `MoodiaryRouteBase` 子类下沉到 foundation 的 `moodiary_router` —— **只搬契约半边**（`path` / `location` / `fromState`），页面构建半边剥离为各 feature 的 `xRoutes()` 片段。这一步单独清掉 **15/27** 条 baseline 违规（≈55%），且是抽取**任何** feature 的硬前置（lock/sync/media/edit 今天都 import app router）。
2. **把共享 state & widget 下沉进已有的包**：`SyncPendingTracker`/`SyncDirtyTracker` → `moodiary_core`；`diary_card`/badge/`LockPinPad`/`ShareCard`/`category_color` → `moodiary_ui`；`EditorMigrationService`/dashboard-stats/geo-weather → `moodiary_data`；app 级 settings state → 新包 `moodiary_preferences`。这会**在不新建 feature 包**的前提下溶解跨 feature 边，并把可复用原语交给 desktop。
3. **抽 `moodiary_sync`（feature 层）**：分离度最干净的巨石（6117 LOC，端口全注入，`data/` 零 widget/Riverpod import）。两个 app 复用同一套 WebDAV/S3 LWW+tombstone+lease+加密语义。**放最后**，因为增量引擎对行为敏感。
4. **抽 `moodiary_media` + `moodiary_editor_host`（feature 层）**：两块最干净的跨 app 切片；desktop 换皮页面即可复用 ~300 LOC 的编辑器接线。

**终态**：推荐波次 `12 → 16` 个包（新增 4：`moodiary_preferences`、`moodiary_sync`、`moodiary_media`、`moodiary_editor_host`）；若延后项 `moodiary_lock`/`moodiary_analyse` 落地则 `~17–18`。四层 DAG 形状不变，feature 层变成一组只向下连边的兄弟。

```
foundation:  lint  l10n  rust  utils(+excerpt)  router(+路由契约, +NavigationService)
                                   │
core:        models ─► core(+SyncPendingTracker) ─► data(+migration, +dashboard-stats, +geo/weather,
                                   │                        +getDiaryProvider, +category-read)
             preferences(新, →core: AppSettings/Font/Cache)
                                   │
ui:          ui(+diary_card[callback], +badges, +category_color, +LockPinPad, +ShareCard)
                                   │
feature:     editor  editor_host(新)  scan  assistant  sync(新)  media(新)   [lock(新, 延后)]
                                   │
apps:        mobile  ·  desktop   (各自组合自己的 app/shell + router 聚合器)
```

---

## 2. 现状评估

**真正好的地方（别动）：**
- `moodiary_editor` 是树里最干净的包——**零内部依赖**，全注入驱动（`seedResolver`/`mediaResolver`/回调）。它是解耦的参考样板。
- `moodiary_assistant` 已证明目标范式：自带 `src/routes.dart`，`.get()` 自注入；跨 feature builder 由 **app** 绑定。
- sync **引擎**只经注入端口触达存储（`SyncDiaryStore`/`SyncCategoryStore`/`SyncMediaFiles`），cipher/logger/并发全构造注入。31 个 sync 文件里只有 **2 个** 带 app/router 依赖，都在 presentation。
- `moodiary_core` 已有两个反转缝合可作后续共享 state 的模板：`OpenDiaryRegistry`（diary↔sync）与编辑器注入解耦。

**耦合的地方（关键数字）：**
- **`app/router/router.dart` 被 15 个 feature 文件 import** = 27 条 baseline 里的 15 条。其中 4 条是**跨 feature 导航借道 app 层洗白**（`edit→diary` `NewDiaryRoute`、`setting→sync` `BackupSyncRoute`、`setting→web_view` `WebViewRoute`、`lock→setting` `Agreement/PrivacyRoute`）。
- **“sync 被 import 86×”** 是命名空间用量，不是 import 广度：真正 touch sync 的外部文件只有 5 个；真实跨 feature 面只有 `SyncPendingTracker`/`SyncDirtyTracker` + `showSyncStatusSheet`（都在 diary）。
- **`getDiaryProvider` 被 import 7×**、**`categoryControllerProvider` 被 import 9×** —— diary 这两个 controller 才是它真正的跨 feature API，是 `edit⇄diary`、`calendar⇄diary` 环的脊柱。
- `moodiary_core` 是 god-infra 瓶颈（DI 缝 + Isar/KV/Secure + dio + PlatformService + theme + media_util + `flutter_quill` + `font_awesome`）；`moodiary_data` 仅为了从旧 Delta 抽纯文本就拉了 `flutter_quill`。

**baseline ratchet 的真实含义**：`tool/check_layers.dart` 只扫 `mobile/lib` 内的 `package:moodiary/...` import，**看不到跨包边**（跨包由 pub 的无环图强制）。这 27 条是 in-app 债；光导航那步就退掉 15 条。**只能变短。**

---

## 3. 导航解耦地基（keystone）

**决策：方案 B —— 契约向下 + 各 feature `xRoutes()` 片段 + 一小片命令式逃生口。**

被否决的替代：`AppNavigator.openX()` god-interface（中心瓶颈，丢掉 go_router 的类型化路由）；把契约搬进各 owner feature（会把 4 条洗白边变成**被禁的** feature→feature import）；`go_router_builder`/`StatefulShellRoute`（已按既定决策弃用；与本问题正交——本问题是**层归属**）。

**各方案分歧的承重约束**：路由契约留在**已有的 foundation `moodiary_router`**，且 `DiaryRoute`/`NewDiaryRoute` 用 `DiaryType` 的 **String `.value`**，不用枚举。原因：`moodiary_models` 在 *core* 层，foundation 包 import 它就是**非法的 foundation→core 边**。所以“新建 `moodiary_routes`（依赖 router+models）”其实落不进 foundation，得放 core，白加一个包。保持 `moodiary_router` 为纯叶子；枚举↔字符串转换放在各 feature 的 `xRoutes()` builder 里（它们本就 import models）。现有的 `_diaryTypeToQuery`/`diaryTypeFromQueryOrNull` helper 随契约一起下沉。

| 半边 | 内容 | 归属 | 层规则 |
|---|---|---|---|
| **WHERE**（契约） | `static path`、ctor 参数、`location` getter、`fromState()` 解析 | `moodiary_router`（foundation） | 纯字符串——无 models 依赖 |
| **WHAT**（builder） | `fromState(state).build()` → 页面 Widget | owner feature 的 `xRoutes()` 片段 | import 自己的页面是同模块，允许 |
| **imperative** | `currentLocation` + 无 context 的 push | `NavigationService` 接口在 `moodiary_router`，实现在 `mobile/lib/app/`（经 `getIt`） | feature 依赖接口，不依赖 GoRouter 单例 |

```dart
// packages/foundation/moodiary_router/lib/src/routes/diary_route.dart  (只放契约)
class DiaryRoute extends MoodiaryRouteBase {
  const DiaryRoute({required this.id, this.type});
  final String id;
  final String? type;                       // DiaryType.value —— 纯字符串，无 models 依赖
  static const path = '/diary/:id';
  @override
  String get location => buildLocation('/diary/$id', {if (type != null) 'type': type!});
  factory DiaryRoute.fromState(GoRouterState s) =>
      DiaryRoute(id: s.pathParameters['id']!, type: s.uri.queryParameters['type']);
}

// packages/foundation/moodiary_router/lib/src/navigation_service.dart
abstract interface class NavigationService {
  String get currentLocation;
  Future<T?> push<T>(String location);
}

// mobile/lib/feature/diary/diary_routes.dart  (builder —— 留 feature 侧)
List<RouteBase> diaryRoutes() => [
  GoRoute(
    path: DiaryRoute.path,
    builder: (c, s) {
      final r = DiaryRoute.fromState(s);
      return DiaryPage(id: r.id, type: DiaryType.fromValue(r.type)); // 枚举↔字符串在此
    },
  ),
];

// mobile/lib/app/router/router.dart  (385 行 → ~40 行聚合器)
List<RouteBase> _mobileRoutes() => [
  homeRoute,
  ...diaryRoutes(), ...settingRoutes(), ...syncRoutes(),
  ...lockRoutes(), ...userRoutes(), ...shareRoutes(),
  ...webViewRoutes(), ...assistantRoutes(),
];
```

**迁移路径**：逐 feature 进行。过渡期 `router.dart` 继续 **re-export** 契约，无 big-bang。每迁一个 feature 就退掉它那条 baseline。跨 feature 目的地（如 `AssistantDiaryPickerRoute` → diary 的 `DiarySelectPage`）契约留在 `moodiary_router`，但让 **app 聚合器**绑定 builder——正如 assistant 今天所做——feature 永不 import 另一个 feature。

**唯一的命令式个案**：`feature/lock/.../app_lock_observer.dart` 读 `router.routerDelegate.currentConfiguration.uri.path` 并无 context push `LockRoute`。**首选修法：把 `app_lock_observer.dart` 挪到 `mobile/lib/app/`** —— 它是 app 生命周期基础设施，不是 diary 领域，无需新抽象；即使日后抽 `moodiary_lock`，它仍留 app 侧（打包的 lock 只拥有 `LockPage`/`AppLockTile`/sheet，不含生命周期 observer）。其硬编码跳过位置 `{/lock,/edit,/share}` 改成可配置参数（desktop 路由不同）。`_locking`/`whenComplete()` 防重入逻辑**逐字保留**。

**保证**：迁移后 location 字符串逐字节相同——迁移前后对每条路由的 `location` 输出做快照测试，证明深链与锁屏恢复（`/lock`、`/start`、`/`）不变。

---

## 4. 拟新增/扩展的包

### 推荐波次

| 名称 | 层 | 抽自 | 内容 | Desktop? | 工作量 | 依赖 |
|---|---|---|---|---|---|---|
| **`moodiary_router`** *(扩展)* | foundation | `app/router/router.dart` | ~40 个路由契约类（`path`/`location`/`fromState`，`DiaryType`-as-string）+ `_diaryTypeToQuery` helper + `NavigationService` 接口 | 是 | M | `go_router` |
| **`moodiary_core`** *(扩展)* | core | `feature/sync/data` | `SyncPendingTracker`、`SyncDirtyTracker`、`SyncPendingState`（ValueNotifier 单例） | 是 | S | — |
| **`moodiary_data`** *(扩展)* | core | `setting`, `edit`, `diary` | `EditorMigrationService`+`MigrationReport/Backup`；`DashboardStats` 派生函数；`GeoRepository`/`WeatherRepository`+DTO；`getDiaryProvider`（load-or-seed）+ category **读** provider | 是 | M | core, models, utils |
| **`moodiary_ui`** *(扩展)* | ui | `lock`, `diary`, `share` | `LockPinPad`；`diary_card`（导航经注入 `onTap`）；`SyncPendingBadge/DirtyBadge/SummaryCard`（无状态）；`category_color`；`ShareCard` | 是 | M | core, models |
| **`moodiary_utils`** *(扩展)* | foundation | `diary/search` | `getHighlightedExcerpt`（纯字符串） | 是 | S | — |
| **`moodiary_preferences`** *(新)* | core | `feature/setting/application` | `AppSettings`+`AppSettingsController`+`appInitialLocaleProvider`；`FontController`；`CacheController`+`CacheUsage` | 是 | M | core |
| **`moodiary_sync`** *(新)* | feature | `feature/sync` | 整个引擎：全部 `data/` + `application/{re_cipher,auto_sync_watcher}` + 可选 3 个 Riverpod controller。**presentation 留 app 侧。** | 是 | L | data, core, rust, models |
| **`moodiary_media`** *(新)* | feature | `feature/media` | `MediaDiaries`/`MediaCleanupController`/`buildMediaGroup`；`MediaPage`/`runMediaCleanup`；`MediaImageViewer`/`MediaVideoViewer` | 是 | M | data, core, ui, models |
| **`moodiary_editor_host`** *(新)* | feature | `feature/edit` | `MoodiaryEditorView`（接好线的 host adapter）；`appMediaResolver`；`RecordSheet`；`EditorBody` 的 tiptap 分支 | 是 | M | editor, data, core, ui |

### 可选 / 延后

| 名称 | 层 | 抽自 | 为何延后 | 工作量 |
|---|---|---|---|---|
| **`moodiary_lock`** *(新)* | feature | `feature/lock` | `LockPinPad`→ui 后再抽 `LockPage`/`AppLockTile`/sheet。安全时序敏感；需先做路由反转（Phase 1）+ 可配置跳过位置。desktop 应用锁 UX 未定。 | L |
| **`moodiary_analyse`** *(新)* | feature | `feature/diary/analyse` | 最干净的只读切片（零跨 feature、零 app/router），但优先级低——可继续留作 diary 内的文件夹。 | S |
| **`moodiary_di`** | foundation | `core/src/di.dart` | 隔离 `getIt`。**目前没有 core 以下、只用 getIt 的具体消费者**——sync/lock 都经 core re-export 拿 getIt。等真有了再做。 | S |
| **`moodiary_location`** | core | `edit` geo/weather | 折进 `moodiary_data` 的替代方案；仅当在意别把 `geolocator` 塞进数据主干时才做。 | S |
| `moodiary_category` / `_search` / `_settings`(UI) / `_diary`(list) | feature | diary/setting | **desktop 从零重建 UI**——页面级 feature 不是像素可复用的。等 desktop UX 设计出来再议。 | L–XL |
| `moodiary_quill_view` | feature | `component/quill_embed` | 只读 richText 正被 tiptap 迁移淘汰；desktop 复用属投机。把 `flutter_quill` 隔离在 mobile holdout 里即可。 | M |
| media_util 出 `moodiary_core` | ui | `core` | 触达 core 内部（`file_util`/`notice_util`/`kv`/`media_type`/`log_util`）；在那些缝合就位前上提会倒转 DAG。延后。 | M |

---

## 5. 跨 feature 解耦

每条边都靠把共享物**下沉**或**合并**修复——绝不横向（那会造出被禁的同层 feature→feature 边）。

- **`diary → sync`**（badge 读 `SyncPendingTracker`/`SyncDirtyTracker`）：把它们 + `SyncPendingState` 从 `feature/sync/data/sync_pending.dart` 上提进 **`moodiary_core`**（`OpenDiaryRegistry` 先例）。这是**强制而非美化**——一旦 sync 成为 *feature 层包*，diary 直接读它的 tracker 就是被禁的 feature→feature **包**依赖；core 是唯一合法归宿。`showSyncStatusSheet` 留 app 侧，因为调用者（首页 tab host `presentation/diary_page.dart`）本就是把 3 个兄弟 feature 接起来的 app 组合接线。

- **`edit ⇄ diary`**（双向环：`edit_controller` 要 diary 的 `getDiaryProvider`；diary 详情页要 edit 的 `EditController`/`EditorBody`）：**不做完全拆分**——它们是一个编辑单元，全拆是高 churn 低 desktop 收益。只软化*方向*：把 `getDiaryProvider`（本质是 `DiaryRepository` 读，披了 diary provider 皮）与 category **读** provider **下沉进 `moodiary_data`**。edit 与 diary 就都从下方消费。`category_picker_sheet.dart` 的 `categoryControllerProvider` 边同法溶解。`detail/diary_page.dart` 暂留原地（或日后随 `moodiary_editor_host` 一起搬）；category **写/CRUD UI** 留 app 侧。

- **`calendar ⇄ diary`**（真环：`CalendarView` 用 `categoryByIdProvider` + `CalendarDiaryCard`，而 `diary_page.dart` import `CalendarView`）：**把 `feature/calendar` 折进 `feature/diary`**。`CalendarView` 不是独立 feature——它是“全部”分段的子视图。把 `CalendarDiaryCard` 移到 `moodiary_ui`（回调导航）去掉 widget 边；折叠去掉环。退一条 baseline，零新包。

- **`share → diary`**（`share_page` import `getDiaryProvider` 取一篇 `Diary`）：把 `Diary` 作为**路由参数**传入（或把 `share_page` 折进 diary），并把渲染成 PNG 的 `_Card` 上提到 `moodiary_ui` 作可复用 **`ShareCard`**。

- **副作用式化解**：`setting → edit`（迁移对比预览）在 host 打包后变成 `setting → moodiary_editor_host`（向下）。`setting → lock`（`AppLockTile`）与 `sync → scan`（`user_key_tile` 里的 `EncryptQrCode`）留作 **app 侧嵌入**——sync/settings 的 *presentation* 留 app 侧，故它们永不阻塞引擎抽取，也不必为 desktop 不复用的代码去破这些边。

---

## 6. 排序路线图（risk-first；每阶段可独立发布 + 可回滚）

> **进度**（2026-07-03）：
> - **Phase 1（导航缝合）✅** — 契约下沉 `moodiary_router`（String 编码 + `moodiary_models` 的 `.routeQuery` 编解码，保 foundation 纯叶子）；7 个 feature 各带 `xRoutes()`；`router.dart` 缩为聚合器；`app_lock_observer` 迁 `app/lifecycle/`。**baseline 27→12**，`router_test` location 逐字节不变。
> - **Phase 2（安全叶子下沉）✅** — `SyncPendingTracker`/`SyncDirtyTracker`/`SyncPendingState` → `moodiary_core`（`src/values/sync_pending.dart`）；`LockPinPad` → `moodiary_ui`（`src/common/`）；`getHighlightedExcerpt` → `moodiary_utils`（`src/text_util.dart`）。纯搬无行为/schema 变；额外清掉 `listview`/`waterfall_view -> feature/sync` 两条边。**baseline 12→10**。
> - **Phase 3（共享 widget 下沉，keep-ui-pure 变体）✅** — 用户定选「保持 moodiary_ui 业务无关」：只下沉真正通用的 `category_color` + 同步角标（`SyncPendingBadge`/`DirtyBadge`/`SummaryCard`）→ `moodiary_ui/src/common/`（`category_color_test` 一并迁入 ui 包）；`diary_card` 导航改注入 `onTap`（新 `diary_nav.dart` 集中路由，卡片去 router 依赖）但**暂留 diary feature**；`ShareCard` 及 `diary_card` 搬包**延后**到桌面 UI 定稿。baseline 仍 10（剩余是 provider 边，归 Phase 4/5）。
> - **Phase 4（折叠消环）✅** — 把 `feature/calendar` 折进 `feature/diary`（它是首页「全部」段的日历子视图，非独立特性；`calendar_controller`+`.g.dart` 连同 part 文件整体 `git mv`，`monthDiariesProvider` 身份不变、无需 build_runner）；`share_page` 改用 `moodiary_data` 仓库一次性取快照（导出页无需流式），去掉对 diary 的依赖。清掉 `calendar↔diary` 环 + `share→diary` 共 3 条边，**baseline 10→7**。
> - **Phase 5a（settings state → 新包）✅** — 抽出 **`moodiary_preferences`**（core 层）：`AppSettings`(freezed)+`AppSettingsController`+`appInitialLocaleProvider`、`FontController`、`CacheController`+`CacheUsage` 连同生成文件**整体 git mv**（生成文件自包含、无 `package:moodiary` 路径，故**免 build_runner**，同 models 抽取先例）；7 个消费者（setting 页 + `main.dart`）改依赖包 barrel。deps 已在 workspace lock 内→`flutter pub get` 零冲突。桌面端可据此从共享 settings 建 `MaterialApp`。baseline 仍 7（settings 非跨特性边）。
>   - **Phase 5 待续**（更高触面、需 build_runner regen）：`getDiaryProvider`+category 读 provider → `moodiary_data`（软化 edit⇄diary，清 2 条边）；`EditorMigrationService`/`DashboardStats`/geo-weather → `moodiary_data`。
> - 至此 `flutter analyze` 全绿、mobile 148 + ui 2 测试通过。前四阶段已 4 个 commit（`0834e76`/`702d75b`/`b1a28a7`/`0e24156`）。Phase 0（删死代码）未动。

| 阶段 | 做什么 | 解锁什么 | 风险 |
|---|---|---|---|
| **0 — 清扫** | 删死代码（`diary_type_icon.dart`、`lottie_modal.dart`、`navigator_bar.dart`、`tab_bar.dart`、`data/model/map.dart` —— 均零引用，已核验）。修 lint 漂移（`moodiary_rust`/`moodiary_editor` 直接 dev-dep `flutter_lints` → 改用 `moodiary_lint`）。删 `webdav_form_sheet.dart:141` 过期的 “Milestone G+” 文案。 | 拆分前缩小面。 | low |
| **1 — 导航缝合（KEYSTONE）** | 把 ~40 个路由契约搬进 `moodiary_router`（`DiaryType`-as-string）；给每个 feature `xRoutes()`；把 `router.dart` 缩成 ~40 行聚合器；**把 `app_lock_observer.dart` 挪到 `mobile/lib/app/`**。对所有 `location` 字符串做快照测试。逐 feature 迁移。 | 清 **15/27** baseline；是**每个** feature 抽取的前置。 | low–med |
| **2 — 安全叶子下沉** | `SyncPendingTracker`/`SyncDirtyTracker`/`SyncPendingState` → `moodiary_core`；`LockPinPad` → `moodiary_ui`；`getHighlightedExcerpt` → `moodiary_utils`。 | 无状态 badge；lock/sync 去风险。纯搬，无行为/schema 变。 | low |
| **3 — 共享 widget 下沉** | `diary_card`（导航经注入 `onTap`）、`category_color`、sync badge（现无状态）、`ShareCard` → `moodiary_ui`。 | 杀掉 `diary_card→app/router` + `calendar→diary` widget 边；desktop 渲染列表/卡零 feature import。 | low |
| **4 — 折叠** | 把 `feature/calendar` 折进 `feature/diary`；把 `share_page` 折进 diary（或 Diary-as-route-arg）。 | 杀掉 calendar↔diary 环 + share→diary 边；退两条 baseline。 | low |
| **5 — state + data 整合** | 建 **`moodiary_preferences`**（`AppSettings`/`Font`/`Cache` controller，`@riverpod`/`@freezed` codegen 开在**这里**，不在 core）。把 `EditorMigrationService` + `DashboardStats` 函数 + geo/weather（反转 `BuildContext`）→ `moodiary_data`。把 `getDiaryProvider` + category 读 provider → `moodiary_data`。 | desktop 从共享 settings 源建 `MaterialApp`；软化 `edit⇄diary`；复用 migration/stats/geo。 | med |
| **6 — 干净 feature 包** | 抽 **`moodiary_media`** 与 **`moodiary_editor_host`**。保持 media Riverpod provider 名不变，让 `root_shell` 继续解析。 | desktop 媒体库 + 接好线的编辑器（免重写 ~300 LOC）；去掉 `setting→edit` 预览边。 | med |
| **7 — sync 引擎（最险，最后）** | 抽 **`moodiary_sync`**（引擎 + `re_cipher` + `auto_sync_watcher` + 可选 controller）作**纯搬**；presentation 留 app 侧。在各 app 的 `service_di.dart` 重新注册 `SyncLogger.create`/`registerRemoteSync`/`AutoSyncWatcher.create`。验证一次真实 WebDAV/S3 往返 + 删除/tombstone 周期。 | desktop 复用同一套 sync —— 在 DI/view-state/nav 缝合都证明绿后才做。 | med |
| **8 — 延后项** | `moodiary_lock`（路由反转后变安全；可配置跳过位置）；可选 `moodiary_analyse`；可选 `moodiary_location` / `moodiary_di` 拆分。 | desktop 应用锁；最终扁平 feature 层。 | med |

**各方案争议的层归属裁决：**
- **`moodiary_sync` → feature，不是 core**（三方一致，且被 DAG 强制：它依赖 `moodiary_data`/`moodiary_core`，对 core 包是向上）。之所以有人想放 core，是因为 diary 读它的 tracker——已由 Phase 2 上提 `SyncPendingTracker` 解决。
- **settings state → 新 `moodiary_preferences`（core 层），不并进 `moodiary_core`**：把新的 `build.yaml` + `@riverpod`/`@freezed` codegen 隔离进一个**新鲜**包，而不是给全树最被依赖的包加 build_runner 步。边界清晰、爆炸半径最小。（若日后更在意包数量而非 core 的 build 稳定性，折进 `moodiary_core` 是机械替代，依赖相同。）
- **diary 分解 → 保守，不极大化**：domain-first 的 ~16 包切法是过度工程，**因为 desktop 从零重建 UI**——页面级 feature 不是像素可复用的。只抽真正跨 app 且能干净分离的（sync 引擎、media、editor-host、preferences state）；把非独立子视图（calendar、share）折回 diary。`category`/`search`/`settings`-UI 包等 desktop UX 设计后再议。

---

## 7. 风险与护栏

**DB / Isar 逐字节 schema（唯一不可逆风险）**：零迁移保证**仅当** `moodiary_models` 的 `@Collection` 类及其 `.g.dart`/`.freezed.dart` 永不再生成。每个 model 相关的搬动都是**纯文件位移**，绝不 `build_runner` 重跑。Phase 5/6 的 `@riverpod` provider 位移*会*跑 `build_runner`，但生成的是 **provider** 代码不是 Isar schema —— **确认那些 diff 里没有 model `.g.dart` 变化。**

**Build-green 不变量——每阶段后都验：**
```
melos bootstrap
dart tool/task.dart analyze        # 层检查 + flutter analyze
fvm flutter test
dart tool/task.dart run            # 冒烟
```

**Riverpod provider 身份漂移**：搬 `@riverpod` provider 会改其生成身份/路径；旧 import 造成的是**运行时 “provider not found”，不是编译错**。逐 feature 搬 + `build_runner` + `analyze`，并 grep 每个调用点：`getDiaryProvider`（7×）、`categoryControllerProvider`（9×）、media provider（由 `root_shell` 解析）。provider 名 + `keepAlive` 保持逐字节相同。

**Codegen 启用（Phase 5）**：给 `moodiary_preferences` 加 `flutter_riverpod` + `riverpod_generator`/`build_runner` + `build.yaml` 会 churn 共享的 root `pubspec.lock`。**一次性、隔离**落地，确认 `melos bootstrap` + 全量 `analyze` 绿后再叠更多搬动。留意 `cli_util` 式版本冲突（当年逼出 root `dependency_overrides` 的那类）。

**导航字符串是承重件**：搬动后的 `location` builder 里一个 typo 会静默破坏深链/锁屏恢复且无编译错。**对每条路由的 `location` 输出做迁移前后快照测试。**

**Sync di 重注册（Phase 7）**：抽取的失败点不是引擎，而是忘了在各 app 的 `service_di.dart` 里 `SyncLogger.create`/`registerRemoteSync`/`AutoSyncWatcher.create`。漏了 **sync 会静默停止且无报错**。以纯搬（零逻辑改）抽取；验一次真实远端往返 + tombstone 周期。

**foundation 纯度陷阱**：`moodiary_router` **绝不能**获得 `moodiary_models` 依赖（非法 foundation→core 边）。若有人为“简化”路由类而 import `DiaryType`，评审时驳回——字符串编码是设计的一部分。

**Ratchet 纪律**：`tool/layer_baseline.txt` **只能变短**（27 → …）。每阶段删掉自己那些行。除非刻意 `--update-baseline` 临时例外，否则不许变长；正解永远是翻转依赖方向。

**可逆性**：每阶段都是纯代码位移——git 可还原，无数据风险。排序保证行为敏感的 sync 引擎最后搬，落在最稳的地基上。

---

## 8. 明确不做 / 反模式

- **不抽 sync 的 *presentation***（`backup_sync_page`、`{s3,webdav}_form_sheet`、`sync_status_sheet`、`user_key_tile`）。desktop 自建 sync UX；这套 Material/bottom-sheet UI 不可复用，且抽它得破 app/router `SyncLogRoute` 依赖 **和** `moodiary_scan` `EncryptQrCode` 的 feature→feature 边——为 desktop 不用的代码买单。**只抽引擎。**
- **不搬 `merge/merge.dart`**。它迁移*旧 mobile* Isar 库（v2.4.8→2.8.0），为 Delta 反序列化拉 `flutter_quill`，而 desktop 是全新 app 无历史装机——永不会跑。纯 mobile。
- **不搬 `gen/{assets,fonts}.gen.dart`**。FlutterGen 从 mobile 自己的 `pubspec` 资产清单派生——天生 per-app；desktop 生成自己的。
- **不打包 `user` 或 `web_view`**。`user` 是占位（登录禁用卡 + 重置本地数据）；`web_view` 是 `url_launcher` stub。太琐碎。（重置数据日后可成 `moodiary_data` 的共享 op——那不是一个包。）
- **不把 `quill_embed`/`flutter_quill` 塞进 `moodiary_ui`/`core`/`data`**。会用沉重的冻结旧依赖污染共享包。若 desktop 真需只读 richText，隔离进独立 `moodiary_quill_view` feature 包——且**连它也延后**。
- **不把路由契约搬进各 owner feature**。会把今天借道 app 的边变成被禁的 feature→feature import。契约**向下**去 `moodiary_router`。
- **不完全拆分 `edit` 与 `diary`**。它们是一个编辑单元（双向环）。只经“读 provider 下沉到 data”软化方向。
- **不造 `AppNavigator` god-interface**，**不采 `go_router_builder`/`StatefulShellRoute`**（均已弃用；与层归属问题正交）。
- **不把 diary 分解成 8 个包**，不在有具体消费者前预造 `moodiary_di`/`moodiary_location`。过早的包增殖只会膨胀 `melos bootstrap` + FRB/editor post-hook，desktop UX 存在前一无所得。
- **不早抽 core 里的 `media_util`** —— 它触达 core 内部；在那些缝合就位前上提会倒转 DAG。延后。
- **别把“共享”等同于“端口即插”**：`moodiary_assistant` 是 iOS/Android 形状（`chat_bottom_container`/`flutter_chat_ui`，JitPack），`theme_util` 与 `flutter_quill`+Isar+KV 耦合——desktop 一旦消费任何领域/存储就会拖上沉重的 core。这没问题，只是它不是模块化任务。
