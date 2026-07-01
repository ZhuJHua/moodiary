# 桌面 / 移动端拆分重构计划

> 状态：**计划中（待执行）**　|　目标分支：`refactor/2.8.0/new_arch`　|　最后更新：2026-06-29

把当前「一个 `app/` 同时编译四端、运行时靠 `isMobilePlatform` 分流」的结构，重构为 **两个独立的 Flutter 应用 + 一组分层共享包** 的 monorepo：

- `mobile/`（由原 `app/` 重命名而来）：收敛为**纯移动端**（Android / iOS），持有 `android/`、`ios/`。
- `desktop/`：**从零重建**的桌面端（Windows / macOS），持有 `macos/`、`windows/`（当前桌面实现质量不佳，全部丢弃重写）。
- `packages/*`：分层共享包，**上层依赖下层，禁止反向依赖**，两个 app 都消费同一套底座。

---

## 1. 背景与现状

`app/`（pub 名 `moodiary`）一个包编译四端，纯靠运行时开关 `isMobilePlatform`（`app/lib/core/values/adaptive.dart:9`，= `Platform.isAndroid || Platform.isIOS`）分流。该开关驱动：

- **两套 go_router 树**：`router.dart:62` 的 `_mobileRoutes()`（详情路由是 StatefulShellRoute 顶层兄弟、全屏 push）vs `_desktopRoutes()`（内层 ShellRoute + 双 navigator key 做双栏 detailSlot）。
- **两个根 Shell**：`MobileRootShell`（底部导航）vs `DesktopRootShell`（NavigationRail + 双栏画布）。
- **多对「桌面变体」页面**：`DiaryPageDesktop` / `SettingPageDesktop` / `_DesktopMediaPage` / 助手双栏 / 浏览器式标签页（`DiaryTabStrip` + `DiaryTabs`）。
- **约 23 处** 散落在 11 个文件的 `isMobilePlatform` / `Platform.is*` 分支。

现有两个包是拆包模板：`packages/moodiary_rust`（foundation）、`packages/moodiary_editor`（product）—— 均 `resolution: workspace` + `lib/<name>.dart` barrel + `lib/src/` 内部 + **回调注入解耦**（editor 用 `seedResolver`/`mediaResolver`，从不 import app）。新包照搬此范式。

---

## 2. 已定决策（2026-06-29）

| 决策点 | 结论 |
|---|---|
| **目录命名** | 原 `app/` **重命名为 `mobile/`**（更能体现移动端身份）；`desktop/` 维持计划不变。 |
| **pub 包名** | 移动端 app 的 pub 名**仍为 `moodiary`**（只改目录、不改包名）——故 `package:moodiary/...` 所有 import **无需改动**，churn 最小；`mobile` 作为 pub 包名也不达意。桌面端新 app 取名 `moodiary_desktop`。 |
| **共享粒度** | 只共享**数据 + 基础件**（`moodiary_models` / `moodiary_data` / `moodiary_core` / `moodiary_ui` / `moodiary_editor` / `moodiary_rust`）；桌面 feature **页面全新写**。**不**抽 `moodiary_features` 共享页包。 |
| **数据层** | 拆成**两个包**：`moodiary_models`（foundation，纯模型）+ `moodiary_data`（infra，repository）。repository 改为构造注入 Isar + 端口。 |
| **解耦方式** | 共享包遵循 `moodiary_editor` 的注入范式（回调 / resolver，不 import app）。 |
| **起步** | 先做 **Phase R：把 `app/` 重命名为 `mobile/`**（第 4 节），再 **Phase 0：从 `mobile/` 剥离桌面端**（第 5 节），随后自底向上抽包，最后搭 `desktop/`。 |

---

## 3. 目标架构（包 DAG，下 → 上，无环）

```
foundation:  moodiary_rust(已有)   moodiary_utils      moodiary_models
                      └──────────────────┴──── ↓ ────────────┘
infra:                       moodiary_core ──→ moodiary_data
                                    └──────── ↓ ────────┘
product:     moodiary_editor(已有)   moodiary_ui
                      └────────────── ↓ ──────────┘
apps:        mobile/ (纯移动, pub=moodiary, android/ ios/)
             desktop/ (新写, pub=moodiary_desktop, macos/ windows/)
```

- **moodiary_utils**：纯 Dart 工具 + 枚举 + TipTap/markdown 转换器（无依赖）
- **moodiary_models**：9 个 Isar `@Collection` + Freezed DTO + 领域事件（依赖 utils, rust）。⚠️ 重新 codegen 时 `.g.dart` 的 Id 顺序必须**字节级稳定**，否则触发破坏性 DB 迁移
- **moodiary_core**：DI/init、存储（Isar/KV/Secure）、网络、theme/values、平台服务（依赖 models, utils, rust）
- **moodiary_data**：4 个 repository + `DiaryContentUtil`（repo 改构造注入 Isar + 端口）
- **moodiary_ui**：`component/basic/*` + 通用 `common/*`（排除 desktop_background / two-pane / quill_embed）
- **mobile / desktop**：各自只留 router 树 + shell + DI 组合 + 注入闭包；`isMobilePlatform` 退化为每 app 的编译期常量后消失

无环性：所有边严格向下（apps → product → infra → foundation），无包反依赖 app；`service_di.dart`（引用 feature 实现）留在**每个 app** 的组合层，故无 `app → feature → app` 环。

---

## 4. Phase R — 把 `app/` 重命名为 `mobile/`（机械步骤，单个原子提交）

> 目标：纯目录改名 + 工具链/CI 路径同步，**不改任何 Dart 代码内容、不改 pub 包名**。改完 `melos bootstrap` + `analyze` + `test` 全绿即可。
> 顺序：放在 **Phase 0 之前**最自然（后续所有引用即用 `mobile/`）；但本步与 Phase 0 内容正交，亦可推迟到最后做——文件内容不变，Phase 0 的行号不受影响。

**改名本体**
- `git mv app mobile`（保留历史）。`mobile/` 下的 `android/ ios/ macos/ windows/ lib/ test/ assets/ res/ splitMap/ pubspec.yaml analysis_options.yaml build.yaml l10n.yaml devtools_options.yaml .metadata .gitignore` 全部随之移动，均用相对路径、**无需改内容**。
- `mobile/pubspec.yaml`：`name: moodiary` **保持不变**。

**根 `pubspec.yaml`**
- `workspace:` 成员 `- app` → `- mobile`
- 描述文案（line 2）「the Flutter app is in app/」→「in mobile/」（line 48 注释顺手更新措辞，非必需）

**`tool/task.dart`**
- `_flutter` / `_dartApp`：`cwd: 'app'` → `cwd: 'mobile'`（line 32、34，及 line 29 注释）

**`tool/check_layers.dart`**
- `Directory('app/lib')` → `Directory('mobile/lib')`（line 53）；报错文案 line 55 同改
- ⚠️ **不要动**：line 25 的 `package:moodiary/` 正则（包名未变）、line 19 的 `['app']`（那是 `lib/app/` 组合层，不是目录名）

**CI（`.github/workflows/`）**
- `flutter-ci.yml`：`working-directory: app` → `mobile`（line 39、43、50）
- `build.yml`：`working-directory: app`（line 63、76、134、138）；`app/android/...`（line 68、72、73）→ `mobile/android/...`；产物路径 `app/build/app/outputs/flutter-apk/app-release.apk`（line 83）→ `mobile/build/app/outputs/...`（注意：仅最前面的 `app/` 是目录名，`build/app/outputs` 是 Flutter 安卓模块输出，保持 `app`）

**IDE 文件（gitignored，自动重生）**
- `melos bootstrap` 会重新生成 `melos_*.iml` 与 `.idea/modules.xml`（原 `app/melos_moodiary.iml` → `mobile/melos_moodiary.iml`）。无需手改。

**验证**：`dart pub get`（或 `melos bootstrap`）→ `dart tool/task.dart analyze` → `fvm flutter test`
**Commit**：`refactor(workspace): rename app/ to mobile/`

> 说明：本计划下文 Phase 0 的所有路径均以**改名后**的 `mobile/` 书写；行号引自当前代码树，改名不改文件内容故行号不变。若选择把 Phase R 推迟到最后，则 Phase 0 期间把下文 `mobile/` 读作 `app/` 即可。

---

## 5. Phase 0 — 从 mobile 剥离桌面端（详细落地步骤）

> 目标：把 `mobile/` 收敛为纯移动端，只**删除**桌面代码、把平台分支**塌缩到移动端那一支**，保证每个提交后 `analyze` + `test` 仍通过。本阶段**不**新建包、不搭桌面壳。
> 行号已核对当前代码树（抽样复核 `adaptive.dart:9` / `kv.dart:52` / `router.dart:62` / `baseline:20` 命中）；标「确认行号」处执行时再核。

### 5.0 开始前 / 存档

存档目录（纯 scratchpad，不进 git，供日后 `desktop/` 重建复用）：
`<scratchpad>/desktop-stash/`（执行时 `mkdir -p`）

- **整文件 cp（删除前）**：
  - `mobile/lib/component/common/resizable_two_pane_layout.dart`（1-147）—— 自包含双栏拖拽分隔器：刻意不用 LayoutBuilder（`Row`+`Expanded(flex)`，resize 只触发 layout 不重建子树）；拖拽用绝对 global X 算比例避免增量累积/闭包过期；ratio 夹 `[minRatio,maxRatio]`；仅 drag end 经 `onRatioChanged` 持久化。
  - `mobile/lib/feature/diary/application/diary_tabs_controller.dart`（1-51）
  - `mobile/lib/component/common/desktop_background.dart`（1-62，已死代码）
- **notes.md 记设计要点**：
  - **DiaryTabs ↔ diaryEvents 自动关闭**（`diary_tabs_controller.dart:25-37`）：`build()` 订阅 `DiaryRepository.get().diaryEvents`、dispose 取消；`_onDiaryEvent` 仅在 `DiaryUpdated && !event.diary.show`（软删除）时关闭对应 tab，**故意忽略** `DiaryDeleted`（只在回收站触发）。DiaryTabs **不持有**选中态，active tab 由 `DiaryPageDesktop` 从路由 location 派生。
  - Windows 默认字体 `Microsoft Yahei UI`（`theme_util.dart:220`）。
  - macOS TouchID 启动自动触发（`lock_page.dart:50`）。
  - 桌面数据重置后 `exit(0)`（`reset_data_tile.dart:81`）。
  - 桌面双栏/路由约定：`_desktopRoutes()` 双栏嵌套 ShellRoute + 每分支 navigatorKey + `_emptyDetailRoute`+NoTransitionPage；detail 用 `.go` 替换右栏 + detail 页 `appBar:null`（移动端 `.push` + `AppBar()`）；`desktopBodyRatio` 默认 0.4 夹 25%-55%。

### 5.x 提交分组（G1→G10）

**排序原理**：先砍路由桌面树 → 桌面页/组件失去调用方；再逐特性塌缩分支；`isMobilePlatform` 旗标 + `desktopBodyRatio` **最后删**（全部引用塌缩完才删）。删「桌面专属整文件」必须与其唯一消费方**同组**，否则悬空 import。每组提交前跑 `dart tool/task.dart analyze` + `fvm flutter test`。

#### G1 — 路由收敛为移动端单树（含 router 测试，强制同组）

`mobile/lib/app/router/router.dart`（自下而上按行号删）：
- 删 `_desktopRoutes()`（注释+函数体 `281-329`）
- 删 `_emptyDetailRoute`（`91-95`）
- 删 `buildRoutesForPlatform`（@visibleForTesting，`69-72`）
- 删 `_diaryNavigatorKey` / `_settingNavigatorKey`（`51-54`，及上方注释 `48-49`）
- 删 `import core/values/adaptive.dart`（`4`）
- 塌缩 `62`：`routes: isMobilePlatform ? _mobileRoutes() : _desktopRoutes(),` → `routes: _mobileRoutes(),`
- 修剪 show 子句：`12` 去 `DiaryPageDesktop`、`19` 去 `DesktopRootShell`、`36` 去 `SettingPageDesktop`
- **保留**：`_mobileRoutes()`(242-279)、`_leafRoute`(76-89)、`_diaryLeafRoutes`(97-108)、`_settingLeafRoutes`(113-185)、`_globalRoutes`(188-239)、`moodiaryNavigationKey`(50)；`route_base.dart` 不改

`mobile/test/app/router/router_test.dart`（同组——删 `buildRoutesForPlatform` 会破坏其编译）：
- 删 desktop 用例 `20-28`
- 改写 mobile 用例 `10-18`：推荐在 router.dart 暴露 `@visibleForTesting List<RouteBase> buildMobileRoutes() => _mobileRoutes();` 作测试入口
- encoding contract 组 `33-91` 不动

验证 → Commit：`refactor(router): collapse router to mobile-only tree`

#### G2 — 删根壳桌面端 + DiaryPageDesktop + 5 个桌面专属文件

`mobile/lib/app/shell/root_shell.dart`（先删 body 再删 import）：
- 删 `_railDestinations`(40-64)、`DesktopRootShell`+doc(85-127)、import `3`(theme_util)/`4`(diary_type)/`5`(home_fab)/`6`(draft_prompt)
- 保留 `_selectTab`(10-12)、`_navDestinations`(14-38)、`MobileRootShell`(67-83)、import 1/2/7/8

`mobile/lib/feature/diary/presentation/diary_page.dart`（list，自下而上）：
- 删 `_DetailPlaceholder`(402-428)、`_PanelCard`(297-309)、`DiaryPageDesktop`+`_DiaryPageDesktopState`+doc(184-295)
- 删 import `14`(diary_tab_strip)/`13`(diary_tabs_controller)/`6`(border)/`3`(resizable_two_pane_layout)
- 保留 `DiaryListPageMobile`(175-182)、`_DiaryListView`(28-171)、`_CategorySectionView`/`_CategoryRow`/`_CategoryPendingRow`(311-400)、import 5/8

**整文件删除**（唯一消费方已在本组删除）：
- `mobile/lib/feature/diary/presentation/widget/home_fab.dart`
- `mobile/lib/component/common/resizable_two_pane_layout.dart`
- `mobile/lib/feature/diary/presentation/widget/diary_tab_strip.dart`
- `mobile/lib/feature/diary/application/diary_tabs_controller.dart` **＋** `diary_tabs_controller.g.dart` **＋** `diary_tabs_controller.freezed.dart`（三同删，避免孤儿 `part of`）
- `mobile/lib/component/common/desktop_background.dart`（零引用）

验证（重点查 `unused_import`/`unused_shown_name`）→ Commit：`refactor(shell,diary): remove desktop root shell, two-pane page & desktop widgets`

#### G3 — 设置特性塌缩 + 删 SettingPageDesktop

`mobile/lib/feature/setting/presentation/setting_page.dart`（自下而上）：
- 删 `SettingPageDesktop`+doc(86-133)、`_SettingDetailPlaceholder`(135-157)、`_SettingPanelCard`(55-70)
- 剥离 `selectedLocation` 高亮管线（桌面专属）：`_SettingSectionList` 字段(36)→const 构造；`_DataSection`(160)/`_DisplaySection`(227)/`_MoreSection`(341) 字段删→const 构造；删 9 处 `selected:` 实参（_DataSection 178/185/192-193/200/208-209、_DisplaySection 250-251/290、_MoreSection 366/386）
- 塌缩 `_openSetting`(26-32)→`route.push(context);`
- 删 import `8`(border)/`7`(adaptive)
- 保留 `SettingListPageMobile`(74-84)、`_SettingSectionList`(35-53)、各 `_*Section`

`mobile/lib/feature/setting/presentation/widget/reset_data_tile.dart`：
- `_performReset`(78-82) → 无条件 `await SystemNavigator.pop();`
- 删 import `1`(dart:io)（`SystemNavigator` 来自 flutter/services，保留）

验证 → Commit：`refactor(setting): drop desktop master-detail page & exit(0) reset path`

#### G4 — 媒体特性塌缩 + 删 _DesktopMediaPage

`mobile/lib/feature/media/presentation/media_page.dart`：
- 塌缩 `28-30` → `return const _MobileMediaPage();`
- 删桌面块 `117-218`（`_DesktopMediaPage`/`_DesktopMediaPageState`/`_TypeTile`）
- 删 import `13`(adaptive)；保留 `_MobileMediaPage` 及其余 helper、border/l10n import

验证 → Commit：`refactor(media): collapse media page to mobile single-pane`

#### G5 — 助手特性塌缩（删桌面双栏 + 侧栏 + 死 helper）

`mobile/lib/feature/assistant/presentation/assistant_page.dart`（**严格自下而上，顺序敏感**）：
1. 删 `_NavTile`(1238-1283)
2. 删 `_SessionSidebar`+doc(1000-1075)
3. `extraBottom`(764-766) → `0.0`
4. 删 `:578` `if (isMobilePlatform)` 守卫（`ChatBottomPanelContainer<_ToolPanel>` 变无条件）；塌缩 composer 三元 `564`→`_toggleToolPanel`、`565-567`→`Icons.add_rounded`、`568-570`→`assistantToolPanelTitle`
5. 删桌面 build 块 `627-656` + `final scheme`(620)；保留 `l10n`(621)、`chatArea`(623-625)、移动 Scaffold(658-665)
6. `_pickAndSendDiary` 内 `477-479` 去 `if (isMobilePlatform)` 包裹（方法本身保留，移动端 `_ToolPanelItem` 可达）
7. `_submit` `323` 去掉 `isMobilePlatform &&`
8. `_deleteSession`(209-213) 与 `_newChat`(195-207) **同删**（互相引用）
9. `didChangeDependencies`(105-114) 删 else 分支，保留移动体
10. 删 `_restoreLatestSession`(139-147)
11. 删 import `17`(border) 与 adaptive（确认行号）
- **保留**：`_loadSession`(160-173)、`_pickAndSendDiary`、`_SessionListView`(1112-1236)、`_panelController`、`_session`

验证 → Commit：`refactor(assistant): remove desktop two-pane sidebar layout`

#### G6 — 编辑特性塌缩

`mobile/lib/feature/edit/presentation/widget/editor_body.dart`：
- 塌缩 `369-372`：保留 `if (widget.editable && widget.type.isEditable)`，三元 → `_buildMobileToolbar(controller),`
- 删相机守卫单行 `240`、`270`（`if (Platform.isAndroid || Platform.isIOS)`）使 SimpleDialogOption 无条件
- 删 `_buildDesktopToolbar`(469-524)
- 删 import `10`(expand_button)/`20`(adaptive)；保留 `7`(flutter_quill)/`2`(dart:io)

`mobile/lib/feature/edit/presentation/widget/draft_prompt.dart`：
- 塌缩 `_openDiary`(20-24) → `route.push(context);`；删 import `2`(adaptive)

`mobile/lib/feature/edit/presentation/widget/moodiary_editor_view.dart`：
- 删相机守卫单行 `72`、`156`；保留 import `2`(dart:io，File 仍用)

验证 → Commit：`refactor(edit): collapse editor toolbar/camera branches to mobile`

#### G7 — 日记 detail / card / map 分支塌缩

- `mobile/lib/feature/diary/presentation/detail/diary_page.dart`：`260`→`appBar: AppBar(),`；`_openLinkedDiary`(316-320)→push；删 import `11`(adaptive)
- `mobile/lib/feature/diary/presentation/widget/diary_card.dart`：`_openDetail`(20-25)→push；删 import `12`(adaptive)
- `mobile/lib/feature/diary/presentation/map/map_page.dart`：`_openDiary`(107-113)→push；删 import `6`(adaptive)

验证 → Commit：`refactor(diary): collapse detail/card/map navigation to push`

#### G8 — Core 层局部分支塌缩（与 isMobilePlatform 解耦，可独立提交）

- `mobile/lib/core/values/adaptive.dart`：删 `_evaluateAndApply()` 桌面早返回守卫 `25-27`（**暂不删 flag**，line 9 仍用 Platform）
- `mobile/lib/core/utils/theme_util.dart`：删 `219-221` Windows 字体支；删 import `1`(dart:io)
- `mobile/lib/core/utils/auth_util.dart`：`11` → `biometricOnly: true`；删 import `1`(dart:io)
- `mobile/lib/core/utils/media_util.dart`：删 `_convertHeicToJpeg` 守卫 `284-287`、`saveToGallery` 守卫 `365-369`；保留 dart:io
- `mobile/lib/feature/lock/presentation/lock_page.dart`：`50` 去 `Platform.isMacOS`；保留 dart:io
- `mobile/lib/core/utils/package_util.dart`：**不改**（移动端无害死码，将迁共享包）

验证 → Commit：`refactor(core): collapse desktop platform branches in theme/auth/media/lock`

#### G9 — 删 isMobilePlatform 旗标 + desktopBodyRatio KV（最后做）

> 前置：G1/G3-G7 已塌缩全部 ~18 处 `isMobilePlatform` 引用；G2 已删 `desktopBodyRatio` 唯一读者（DiaryPageDesktop）。

- `mobile/lib/core/values/kv.dart`：删 `desktopBodyRatio` 枚举项+doc(`51-52`)
- `mobile/lib/core/values/adaptive.dart`：删 `isMobilePlatform`+doc(`7-9`)、import `1`(dart:io)

全量验证（grep 确认全仓无 `isMobilePlatform`/`desktopBodyRatio` 引用、无 unused_import）→ Commit：`refactor(core): remove isMobilePlatform flag & desktopBodyRatio KV`

#### G10 — 测试与基线收尾（ratchet 棘轮）

- 复核 `mobile/test/app/router/router_test.dart`：desktop 用例已删、mobile 用例改接新入口、encoding 组未动
- 全仓 grep 确认无桌面符号测试残留（`Desktop`/`TwoPane`/`TabStrip`/`DiaryTabs`/`isMobilePlatform`/`AdaptiveBackground`/`desktopBodyRatio`）—— sweep 确认仅 router_test 命中，无 golden/widget 桌面测试
- **收缩 `tool/layer_baseline.txt`**：唯一确定消失行 = `feature/diary/presentation/widget/diary_tab_strip.dart -> app`（文件已删）。其余因移动端共享代码仍触发，**保留不动**
- `dart run tool/check_layers.dart --update-baseline`，核对 diff **仅删该行、无新增**（新增即违反棘轮）

验证 → Commit：`test,chore: drop desktop router test & shrink layer baseline`

### 5.y 收尾 / 验证（全部组完成后）

1. `dart tool/task.dart analyze`（layer check + flutter analyze，零 error / 零 unused_import）
2. `fvm flutter test`（全绿）
3. `dart run tool/check_layers.dart`（棘轮通过）
4. 烟测：`dart tool/task.dart editor` 后 `build-apk` / `build-ios`
5. 终检 grep：无 `isMobilePlatform`/`desktopBodyRatio`/`DiaryPageDesktop`/`SettingPageDesktop`/`DesktopRootShell`/`_DesktopMediaPage`/`_buildDesktopToolbar`/`DiaryTabStrip`/`ResizableTwoPaneLayout`/`AdaptiveBackground` 残留

### 5.z 风险与必须协调的依赖边

- **最大爆炸半径 / 最后删**：`isMobilePlatform` ~18 处跨 9 文件（router:62；assistant:105/323/477/564/565/568/578/627/764；detail/diary_page:260/316；map_page:109；diary_card:21；draft_prompt:20；editor_body:370；media_page:28；setting_page:27）。必须全部塌缩后才能 G9 删定义
- **`desktopBodyRatio` 硬阻塞**：唯一读者 DiaryPageDesktop → 先 G2 删页面才能 G9 删 KV
- **router show 子句(:12/:19/:36)+adaptive import(:4)**：桌面类一删即悬空，必须 G1 同组处理
- **整文件删 ↔ 消费方同组**：resizable/tab_strip/tabs_controller 与 DiaryPageDesktop 同 G2；home_fab 与 DesktopRootShell 同 G2
- **生成件三同删**：`diary_tabs_controller.{dart,g.dart,freezed.dart}`
- **dart:io 取舍**：adaptive/theme_util/auth_util **删** dart:io；media_util/editor_body/moodiary_editor_view/lock_page **保留**（File/Directory 他处仍用）
- **`unused_import` = CI 失败**：每文件「塌缩 + 删 import」必须同提交
- **棘轮单向**：baseline 只能缩不能增

### 5.w 不在 Phase 0 范围

- 不抽取/新建任何包（除 `moodiary_editor`/`moodiary_rust`）
- 不搭建 `desktop/` 骨架、不回填桌面 UI（仅存档到 scratchpad）
- 不重写 `CLAUDE.md`（将陈旧处：line 101 shell/rail、133-135 Adaptive Layout 段、87 adaptive 检测、170 编辑器 `platform` boot flag 说明——注意这是 webview 内 TipTap 工具栏定位的**独立机制**，与 app 侧 `isMobilePlatform` 无关）
- 可选化简（`showFab` 常量化、`_leafRoute` 去 `noTransition` 参、package_util 桌面臂）留待后续 simplify pass

---

## 6. 后续阶段概览（Phase 0 之后）

> 详细落地步骤待 Phase 0 完成后再展开；此处仅记方向与已知阻塞。下文路径均以 `mobile/` 为准。

- **Phase 1 — 解层级违规（抽包前置）**　**✅ 已执行（聚焦范围，2026-06-30，工作区未提交）**。
  分析结论：4 条 baseline core→data/merge 中，只有 `pref→merge` 是真正的跨层环；`isar/file_util/font_util→data` 本质是「模型暂居 `data/` 层」（core 用的是 model *类型/schema*，是合法的 core→models 下行依赖），Phase 2 抽 `moodiary_models` 时自动消除，无需手工反转。故 Phase 1 只做两个真环 + 顺手删死代码：
  - ✅ **core→merge**：`storage/kv/pref.dart` 的版本迁移块上移为 `MergeUtil.runVersionMigration()`，由 `main.dart` 在 `injectBasicService()` 后、主题/服务初始化前调用（保持「先迁移再读字体」时序，且比旧版更确定——旧版内联在 KV.init 与 Isar.init 并发有竞态）。baseline 该行已清除（38→37）。
  - ✅ **network→UI（隐藏环，非 baseline）**：`dio_http_client.dart` 改为构造注入 `onError` 回调（默认静默），`service_di.dart` 注入 `(m)=>toast.error(message:m)`；解除 core/network → core/utils(UI) 耦合。
  - ✅ 删除无调用的 `file_util.cleanUpOldMediaFiles`（死代码）。
  - ⏭ **延后到 Phase 2 抽 models 时自然消除**（非环，不必现在手工搬）：`isar.dart` schema 导入、`file_util.cleanFile` / `font_util.getAllFonts` 的 model 类型依赖、`theme_util.buildTheme()` 读 `IsarDatabase` 字体 + IsarDatabase Font CRUD（这组与 theme_util 字体注入相互耦合，留到 `moodiary_ui`/`moodiary_models` 抽取时一次性设计注入缝）。
  验证：`analyze` 0 issues + 0 新增越层（baseline 37）；149 测试全过。
- **Phase 2 — 自底向上抽包**（进行中，逐包 gate，未提交）：
  - ✅ **`moodiary_utils`（2026-06-30）**：15 个叶子工具（array/fast_hash/function_extensions/lru/password/send/image_size_manager/network/package/qr_crypto/markdown_util/markdown_to_tiptap/quill_to_tiptap/tiptap_content/auth）迁入 `packages/moodiary_utils/lib/src/`，barrel `lib/moodiary_utils.dart` 全量 export；依赖 `moodiary_rust` + 9 个外部 plugin（synchronized/image_size_getter/connectivity_plus/network_info_plus/device_info_plus/package_info_plus/dartx/markdown/local_auth）。21 个消费文件 import 改为 barrel（脚本重写 + 去重）；root `workspace:`+foundation category、`mobile/pubspec` 依赖均已加。验证：mobile analyze 0 issues（250 文件、0 新增越层）、包 analyze 0 issues、149 测试全过。
  - ✅ **`moodiary_models`（2026-06-30）**：33 个模型文件（12 源 + 21 生成）**整体搬、不重跑 build_runner** → schema 字节级不变（验证 149 测试含 Isar/sync 全过，无 DB 迁移风险）；54 个消费文件 import 改 barrel。**领域字段枚举随模型下沉**：`DiaryType`（diary 字段类型）、`AssistantProviderType`（llm_provider 字段类型）放进 `moodiary_models`（**不是 utils**——曾误放 utils 被用户纠正：util 是工具，领域枚举属模型层）；`DiaryTypeIcon`(font_awesome 扩展)→app `core/values/diary_type_icon.dart`、`AssistantTool`+系统提示词→app `core/values/assistant.dart`（非模型字段，留 app）。抽 models 顺带消除剩余 3 条 core→data baseline（isar/file_util/font_util 现为 core→moodiary_models，外部包不再被 check_layers 跟踪）→ baseline 37→34。
  - ✅ **`moodiary_lint`（2026-06-30，应用户要求）**：workspace 共享 lint/分析配置包；`lib/analysis_options.yaml`（include flutter_lints + 规则 + `invalid_annotation_target: ignore` + 生成文件排除）；flutter_lints 作常规依赖以传递。app/models/utils 均改为 `include: package:moodiary_lint/analysis_options.yaml` + dev_dep `moodiary_lint`（替换各自 flutter_lints）。app 保留平台目录 exclude。rust/editor 暂未接入（生成/既有代码，避免引入存量 lint 债）。
  - ✅ **`moodiary_l10n`（2026-06-30）**：抽 `moodiary_core` 时发现 **l10n 阻塞**——`colors`/`language`/`notice_util` 直接用 l10n、`theme_util`(56 处，最常用 core 文件)经 colors 间接用；分层上 `l10n → core`（l10n 在 core 之下），故先把 l10n 抽成 foundation 包。`gen-l10n` 产物（app_localizations*.dart）+ arb + l10n.yaml + `flutter:generate:true` 移入 `packages/moodiary_l10n`；`BuildContext.l10n` helper 折进 barrel；mobile 去掉 `generate:true` 与 l10n.yaml。30 处 `package:moodiary/l10n/*` → `package:moodiary_l10n/moodiary_l10n.dart`。验证：0 issues、149 测试过。
  - ✅ **`moodiary_core`（2026-06-30，infra）**：整个 `core/` 迁入 `packages/moodiary_core/lib/src/`（di/init/platform_service/storage[isar/kv/secure]/network/9 个 utils 含 theme_util+notice_util/12 个 values 含 colors+border），**仅 `core/values/diary_type_icon.dart`+`core/values/assistant.dart` 留 app**。intra-core import 改 `package:moodiary_core/src/...`；barrel 全量 export（30 个）；新增 melos `infra` category。127 处消费 import 改 barrel（负向先行断言保留 2 个 holdout）。两处需处理：① `expection.dart` 的 `SyncException` 与 sync 功能自带的重名——core 那个是死副本，删之（保留 Network/DatabaseException，category_repository 用）；② theme_util 用 dartx，补依赖。deps：l10n/models/rust/utils + get_it/isar/shared_preferences/secure_storage/dio/path*/mime/file_picker/image_picker/heif/gal/fc_thumbnail/dynamic_color/flutter_quill/flutter_smart_dialog/font_awesome/riverpod_annotation/dartx/logger/meta。验证：core 0 issues、mobile 0、183 文件 0 新增越层、149 测试过。
  - ✅ **`moodiary_data`（2026-06-30，infra）**：5 文件（4 repo + diary_content_util）迁入 `packages/moodiary_data/lib/src/`。**未做构造注入**——`data → core` 是 DAG 下行边，包依赖 `moodiary_core` 即可保持无环，故保留 `.get()` 单例（注入是纯度 nicety，非必需；省去触及所有调用点的高风险改动；两端 app 共用同一份带单例的 data 即可）。deps：core/models/rust/utils + isar_plus/fpdart/flutter_quill。29 处消费 import 改 barrel；归入 melos `infra` category；`mobile/lib/data/` 整目录已空、删除。验证：0 issues、178 文件 0 新增越层、149 测试过。
  - ✅ **`moodiary_ui`（2026-06-30，product）** ——**Phase 2 收官**。`component/basic/*`（除 lottie_modal）+ `component/common/*`（含 qr/、async_value、players、frosted_glass_overlay）迁入 `packages/moodiary_ui/lib/src/`。**两处留 app**：`component/basic/lottie_modal.dart`（引 app 的 `gen/assets`，且**零引用死代码**——避开 gen 阻塞）、`component/quill_embed/*`（legacy Quill，只 editor_body 用，避免把 flutter_quill 拖进共享 UI 包）。`frosted_glass_overlay` 直接读 moodiary_core 的 `MoodiaryKVs.backendPrivacy`（下行，无需注入）；`async_value` 整包绑 flutter_riverpod（不另设子包）。deps：core/l10n/utils + flutter_riverpod/dartx/modal_bottom_sheet/flutter_smart_dialog/easy_refresh/throttling/path/video_player/chewie/audioplayers/qr_flutter/mobile_scanner。归入 melos `product`。consumer 改 barrel（负向先行断言保留 quill_embed/lottie_modal 路径）。验证：0 issues、150 文件 0 新增越层、149 测试过。
    > **「假阳性」记录**：以为有 component→feature 越层，实为 README.md 文本命中。
  - **⚠️ Phase 2 待清尾（非阻塞）**：mobile_scanner（相机）在共享 ui 包里，桌面端接入时再议拆 qr；app 侧小 holdout（lottie_modal/quill_embed/assistant/diary_type_icon）可在 Phase 3 归位（diary_type_icon→ui、assistant→feature/assistant）。
- **Phase 3 — 搭建 `desktop/`**（✅ **骨架已搭、可运行**，2026-06-30：`flutter create --org cn.yooss --project-name moodiary_desktop --platforms=macos,windows desktop`；`resolution:workspace` + 入 root workspace；占位 `MoodiaryDesktopApp`（暂不依赖 native 较重的共享包以保证开箱即跑）；用共享 `moodiary_lint`；`flutter build macos --debug` 通过。**余下为实现**：搬 `mobile/macos`+`mobile/windows` 进 desktop 并改 bundle id、接共享包、重建 shell/页面、打包配置、task.dart 加 desktop 目标、check_layers 多根。）：`flutter create` 新 app 成员（pub 名 `moodiary_desktop`），把 `mobile/macos`+`mobile/windows` 搬入并修 bundle 标识，依赖共享包，重建 rail 壳 / master-detail / 标签页（从 scratchpad 移植 `ResizableTwoPaneLayout` 与 tab 事件逻辑）。`tool/task.dart` 加 `--app` 选择（mobile/desktop）、`tool/check_layers.dart` 支持多根 + 各包 import 前缀、拆分 launcher-icons/msix/splash（注意 `dependency_overrides` 必须留 root）

---

## 7. 待定问题（执行中再决）

- 模型+repo 已定两包；`moodiary_core` 是否进一步拆 `moodiary_infra`（存储/DI/端口）+ 更薄 core？端口（`SecureKeyStore`/`KvPointer`/`MediaPathResolver`）落哪
- `moodiary_ui` 是否整体绑定 Riverpod，还是把 `async_value.dart` 隔到 `moodiary_riverpod_ui`
- TipTap 文本转换器（`markdown_to_tiptap`/`quill_to_tiptap`/`tiptap_content`）落 `moodiary_utils` 还是并入 `moodiary_editor`
- QR：把生成器（共享）与扫描器（`mobile_scanner`，仅移动）拆开，避免桌面继承相机依赖
- `check_layers.dart` 是否扩展为跨包 DAG 强制，还是仅靠 pub 无环图
