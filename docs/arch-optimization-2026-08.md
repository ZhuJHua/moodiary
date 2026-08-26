# 架构优化方案（2026-08）

> 依据：2026-08-26 整仓架构审查（7 维度并行深读 + 逐条对抗核验，60+ 条发现，核验后确认约 25 条）。
> 本文档是执行清单：按阶段推进，完成一项勾一项。证据均为 file:line 级、核验时真实读过。

## 总评与原则

骨架健康，不动大结构：四层 DAG 实测零违规、DI 纪律全仓一致、IFilePicker「端口在 core、
实现在 app 组合根」是多实现的正确样板。确认的问题集中在四类：**错误处理默认值、
启动健壮性、少数漏抽的端口、可测试性基建**。

执行原则（核验环节的裁定，违背它们的建议已在审查中被否决）：

1. **不做投机抽象**：桌面形态未定的东西（app_shared 包、barrel 导页面、tab 深链、
   StartupHooks）一律等 desktop 立项再动——这类搬迁无复利，现在搬和届时搬成本相同。
2. **不撞已拍板决策**：仓储不进 get_it 容器（静态单例是刻意的）；启动编排归 main 不归
   容器；@PostConstruct 不用；feature 互不引用。
3. **改法取核验修正版**：多条原始建议被怀疑者证伪或找到了更省的改法，以下写的都是
   修正后的版本。

---

## P0 — 正确性问题（全部小时级）——✅ 已全部完成并验收（2026-08-26）

### 0.1 riverpod 3 默认重试未评估：异常被指数重试 10 次 ≈ 38 秒
- [x] 完成（2026-08-26）
- **问题**：riverpod 3 默认对非 `Error`/`ProviderException` 的异常做指数退避重试
  （10 次，200ms→6400ms）。全仓 27 个 provider 均未配置 `retry`。
  `edit_controller.dart:54` 抛 `Exception('Diary not found')` → 用户看到 **38 秒空白页**
  （diary_page.dart:502 的 loading 是 `SizedBox.shrink()`）才报错；重试期间读的是
  getDiary 缓存，10 次全是空转。`DatabaseException implements Exception` 同样不免疫，
  首页首屏任何库错误同样被静默重试。
- **改法**：
  1. `mobile/lib/main.dart` 的 `ProviderScope` 显式传 `retry:`——最多 2 次、300/600ms，
     `DatabaseException` 不重试（库错误重试无意义）。一行覆盖全仓，策略成为可读事实。
  2. `edit_controller.dart:54` 改抛 `StateError`（Error 子类，天然不重试——它是预期内
     业务分支）。
  3. 顺手：diary_page 错误态目前显示 `Error: $e` 文本，可见即可，不在本项扩展。

### 0.2 启动序列无失败兜底：任一步抛出 = 永久停在启动图
- [x] 完成（2026-08-26）
- **问题**：`main.dart` 裸 `await _initSystem()`，无 try/catch。确凿抛出链：
  `RemoteSyncRegistry.get().reload()` → `secure_options.dart:19` 读 SecureKV，Keystore
  故障抛 PlatformException 直穿。`themeFuture`/`localeFuture` 创建与 await 之间隔着
  `await syncBackendFuture`，失败会双重上报。同类风险 `app_lock_pin.dart:66-76` 已有
  fail-open 先例，未推广。
- **改法**（按成本排序）：
  1. `reload()` 加 catch + `logger.e`，fail-open（`hasBackend == false` 是受支持状态，
     watcher 两处入口都有守卫，已核验安全）。
  2. `themeFuture` catch 回落默认 `buildTheme()`；`localeFuture` catch 留 base 语种。
  3. `main()` 包 try/catch，失败 runApp 零依赖兜底页 `BootFailurePage`
     （裸 MaterialApp + 硬编码中英文——slang/主题/容器此刻可能正是坏的那环）。
     页面只保「错误详情 + 日志路径」；「重置数据」做尽力而为的第二按钮并自带
     try/catch（`resetAllData()` 第一句就碰 Isar/KV，装配失败时它自己会抛）。

### 0.3 CI 从不设 ISAR_TEST_DYLIB：真库测试恒 skip
- [x] 完成（2026-08-26）
- **问题**：`.github/workflows/quality.yml` 无任何 env；`diary_index_test` /
  `version_migrator_test` / `db_benchmark_test` 未设变量即整组跳过。倒排索引正确性与
  2.8.0 迁移语义在 CI **零覆盖**（记忆里「迁移零测试」的真身：测试写了但 CI 不跑）。
  而 dylib 就在 pub 包里：`isar_plus_flutter_libs-1.3.9/linux/libisar_plus.so`。
- **改法**：Test 步骤前加一步，版本精确 find + 写 `$GITHUB_ENV`，**find 为空 exit 1**
  （防升级 isar_plus 后静默退回全跳过）。先在本机用 darwin dylib 跑一遍这批用例确认绿
  （CI 是 --fail-fast，别让首跑翻车）。`RUN_DB_BENCH` 二级门控不动。
- **投入产出比全场最高。**

### 0.4 statObject 吞错返回空串：一次抖动 = 已上传媒体整体重传
- [x] 完成（2026-08-26）
- **问题**：契约（sync.dart:65-66）与两个实现（webdav_sync.dart:143-150、
  s3_sync.dart:164-171 均为 `catch (_) => ''`）让网络中断/401/5xx 与「不存在」同形，
  与同文件 readObject 的严厉契约自相矛盾。后果：engine:1242 判「远端已存在」失真 →
  媒体整体重传；auto_sync_watcher:188-194「远端不可达」catch 成死代码 → 不可达时
  反而白跑整轮同步（含租约往返）。
- **改法**（落地版比原案更稳）：吞错真身在 **Rust 侧**（两个 `stat_object` 对网络
  错误与非 2xx 全返回 `Ok("")`），修在 Rust——404→空串、其余 `Err`（签名不变，免
  FRB 重生成）；Dart 端口改 `Future<String?>`（null = 不存在，值为不透明记号不解析，
  避免 HTTP-date/ISO 解析这层新失败面），实现层错误包成 SyncException。engine:1242
  改判 null；**watcher 的 preStat 字符串格式保持**（`'$id|${stat ?? ''}'`），否则老
  用户 KV 缓存的 stat 全部失配、轮询短路永不命中。local_archive/测试替身同步换签名。

### 0.5 inline 索引模式双事务：崩溃后索引静默陈旧且不自愈
- [x] 完成（2026-08-26）
- **问题**：`updateADiary` 的 inline 分支（diary_repository.dart:468-476）先事务写行、
  发事件、跨 FFI 分词、**第二个事务**写倒排。两次提交间进程被杀 → 行新索引旧，且无
  ReindexQueue 行，启动自愈扫不到。defer 与批量路径都是单事务安全的，唯 inline 不是。
- **改法**：inline 改「同事务 put + 入队 → 发事件 → 同步 `reindexDiary`」
  （:479-495 已有幂等实现），崩在任何点队列行都在。
  顺带：软删/还原与助手改元数据没动正文却走 inline 整篇重分词——这些调用点传
  `IndexMode.skip`（前提核验：索引 diff 只依赖 content，show 过滤在查询期）。

### 0.6 「先订阅后加载」丢事件窗口 ×5 controller
- [x] 完成（2026-08-26）
- **问题**：五个 controller 统一模式：先 `listen(_applyChange)` 再 `init()`，而
  `_applyChange` 遇 `state.value == null`（首次加载中）静默丢弃。窗口=一次查询时长，
  启动时 pull 逐篇落库连发事件，撞上概率不低。后果：列表短暂陈旧（自愈靠 autoDispose
  重建）。
- **改法**（核验修正版，不做 pending 队列）：null 分支置 `_missed = true`；build 里
  `init()` 完成后 `if (_missed) { _missed = false; unawaited(refresh()); }`——丢事件
  退化为一次多余重查，天然覆盖分页 offset。LoadMore 系（Diary/RecycleBin/MediaDiaries）
  做进 LoadMoreMixin；CategoryController / MediaInfoController 内联同样三行。

### 0.7 iOS 上「重置数据后退出」是空操作
- [x] 完成（2026-08-26）
- **问题**：reset_data_tile.dart:52 `SystemNavigator.pop()` 在标准 Flutter iOS 应用上
  两条分支都不动作（SDK 文档核实）。此刻存储已清空、内存单例还指着旧状态，界面纹丝
  不动，后续任何读写未定义。
- **改法**：重置成功后 runApp 一个占满全屏、无返回路径的「数据已清空，请手动重启」
  终态页；Android 仍顺带调一次 pop 当快捷路径。bootstrap.dart:43-45 的契约注释改成
  「调用方必须立即接管界面」。**不做软重启**（_initSystem 不可重入，低频操作不值得）。

### 0.8 await 之后用 ref 无 mounted 守卫 ×4
- [x] 完成（2026-08-26）
- **问题**：`WidgetRef` 的 read/invalidate 在宿主 unmount 后**无条件抛 StateError**
  （非 debug assert）。四处未守卫：sync_key_guard.dart:106、
  user_key_change_flow.dart:110/:162、font_page.dart:128——同函数里 toast 都守了
  `context.mounted`，invalidate 没守，笔误性质。
- **改法**：照 media_page.dart:143 的既有写法补 `if (context.mounted)`；font_page 那处
  写 `if (!context.mounted) return;` 更顺。不做「函数不收 ref」的中期重构（收益低）。

### 0.9 迁移 sidecar 明文备份永不清理（隐私）
- [x] 完成（2026-08-26）
- **问题**（核验时挖出）：编辑器迁移的 `migration_backup/<id>.json` 存**每篇旧日记
  正文明文**，全仓无任何删除逻辑——用户不点「重置数据」就永久留在磁盘。
- **改法**：`EditorMigrationService` 增 `purgeBackups()`（用它自己的私有 `_backupType`，
  owner 化）；在启动闸门探测确认**已无旧格式日记**时调用（迁移未完成期间备份保留，
  安全网仍在）。顺手把 bootstrap.dart:58 手抄的 `'migration_backup'` 字面量换成调
  `purgeBackups()`，消掉一处跨包私有路径手抄。

**P0 验收**：`dart tool/task.dart analyze` 零新增；受影响包测试绿；
CI dylib 那条在本机先验证目标用例真跑通过。

---

## P1 — 架构收敛 ——✅ 已全部完成并验收（2026-08-26）

### A. 平台插件归位（真实的桌面阻塞清单，核验后只剩这些）
- [x] **utils↔platform 边界倒置**：biometric_auth / network_status / app_info 三文件
  连 5 个插件依赖从 foundation/moodiary_utils 搬进 core/moodiary_platform（外部读者仅
  5 处：lock×2、sync×2、mobile×1、migration×1）；platform 删除对 utils 的依赖，变成
  零 moodiary 依赖的 core 叶子。根 CLAUDE.md 的职责描述随之成立。约 3h。
- [x] **heif_converter 是全 core 唯一 android/ios-only 插件**：抽单方法窄端口
  `IHeifDecoder`（media_manager.dart 四处调用点改走端口），插件依赖移 mobile。
  **别走 Rust**——image crate 无 HEIF 解码器，引 libheif 撞体积纪律。约 3-4h。
  （gal / fc_native_video_thumbnail 支持桌面，留在 core，不抽。）
- [x] **mui 背着 video_player**（无 windows/linux）：video_player_port_impl /
  video_ambient_port_impl 两文件 + 三条插件依赖搬到 moodiary_components（唯一调用点
  在那）；同时把 `portFactory` 提成 MVideoPlayerPage 构造参数（否则桌面有 media_kit
  实现也塞不进去）。mui 回到零插件叶子。约 2-3h。
- [x] check_layers 加手维护常量表 `_mobileOnlyPlugins`：foundation/core/feature_base
  三层 pubspec 出现表中插件即红（例外名单带理由）。别扫 pub 缓存（CI 无缓存，脆）。

### B. 端口质量
- [x] **IRemoteSyncBackend 胖接口**拆 `RemoteObjectStore`（对象原语）+ SyncBackend
  （编排门面）；engine 只依赖前者；LocalArchiveBackend 四处 Unimplemented/Unsupported
  消失；isReady+engine 样板提成 mixin（notReadyError 抽象成员，webdav/s3 文案不同）。
  Registry 字段类型保持 IRemoteSyncBackend? 不变。小时级~1 天。
- [x] **IBackupArchive.import 返回写死中文串直进 toast**（英文界面出中文）：改返回
  `BackupImportResult` DTO（定义在 moodiary_data，别复用 SyncReport——那会让 data
  认识 sync 的类型）；export_page 照抄 lan_receive_page 的 `_summary()` 走 l10n，
  新增键后必跑 `dart tool/task.dart i18n`。SyncReport.toString() 注明「仅供日志」。
- [x] IFilePicker 删两个零调用死方法 takePhoto/recordVideo（相机入口走选择器网格，
  不经端口，删除安全）；「失败抛异常、取消返回 null」写进契约注释。
- [x] font_manager.pickFont() 改走 `IFilePicker.get()`（全仓选文件收敛到一个入口）。

### C. DI / riverpod（边界本身是清的，补文档和两个接缝）
- [x] **moodiary_data/CLAUDE.md**（全场性价比最高的一小时，排在其它代码改动之前）：
  ① get_it = 需要换实现的接线；仓储是刻意的进程级静态单例，平台差异由
  `IsarDatabase.init(directory:, schemas:)` 在组合根吸收。
  ② riverpod = 界面生命周期的读模型；仓储经薄 `xxxRepositoryProvider` 取用。
  ③ 进程级持有者（Registry/Tracker/KVNotifier）留容器外，新代码经 provider 暴露。
  ④ widget 反应式通道以 `ref.watch` 为准；跨包公开 widget 不得命令式读全局 KV。
  硬事实：codegen 默认 autoDispose / 手写 NotifierProvider 默认相反 / riverpod 3
  默认重试（写明本仓 ProviderScope 策略）/ provider 统一放 application/。
  事件通知判据：大列表走类型化事件+内存增量；小表 Stream<void> 全量重查；单对象
  watchObject。
- [x] **仓储薄 provider 层**：`repository_providers.dart` 13 行
  `@Riverpod(keepAlive: true)`；controller 改 `ref.watch`（约 10 处）；测试
  `overrideWithValue(forTesting(...))`。**不进容器。** 另给其余 8 个仓储补
  `forTesting`，修 edit_controller.dart:34 错注释（「get_it 单例」→「进程级静态单例」）。
- [x] **`_assertRequiredBindings()`**：configureDependencies 后对 10 个必需绑定逐个
  isRegistered，debug assert / release logger.e——同时是 desktop 组合根的可执行清单。
  （throwOnMissingDependencies 开在根上是 no-op；要开开在 sync 等 micro-package 上。）
- [x] **riverpod_lint**：实测后**暂缓**（2026-08-26）——analyzer 13.3.0 上原生
  plugin 在 workspace 根加载但诊断不落到嵌套包，包内放置被根分析拒绝
  （plugins_in_inner_options），custom_lint 老形态止步 dev.17/analyzer 7。
  复查条件与哨兵写在 moodiary_lint/lib/analysis_options.yaml 顶部注释。
- [x] 测试接缝用 get_it scope：`pushNewScope` / `popScope` 替掉 view_mode_sheet_test
  与 sync_test_harness 的手工 unregister 三连。

### D. 数据层
- [x] **错误约定统一抛异常**：category/media_info 两仓储的 6 个 TaskEither 方法改回
  Future（DatabaseException 从未被任何消费端读过，全被 getOrElse 拍平——库故障伪装成
  空列表）；controller 补 try/catch + logger.e；fpdart 从 moodiary_data 删除。
- [x] **pull 逐篇 insertADiary 的 O(N²) 倒排**：insertDiaries 加 `IndexMode` 参数
  （defer = 同事务 putAll + 入队），engine pull 传 defer，结束按本轮量分流
  （>200 → rebuildAllIndexes，否则 drainReindexQueue）。**别攒批落库**——会拉长
  LWW 重读窗口，与引擎刻意保持的不变量相反。
- [x] 派生一致性收敛：`withDerivedMedia` / `touched` 两个纯函数 +
  `setVisibility(Diary, bool)` 收编软删三处重复 + `updateADiary` 头部 debug assert
  抓第四个写入方。（不做四入口大改——自动保存热路径不能多付一次全文解析。）
- [x] 小件：`getDiariesByDateRange({all})` 改名 `visibleOnly`（语义与名字相反）；
  DiaryEvent.deleted 补业务 id + watcher 补 clearDirty；timeline 事件订阅补 300ms
  去抖（pull 期每帧一次全表聚合）；timeline_view/feed_view 的 sort 改构造参数
  （命令式读 KV 靠宿主 KeyedSubtree 契约，桌面复用即静默错分桶）；
  dashboard 字数改读 DiaryIndexSnapshot.contentChars；PickedScope 改逐 id 主键 get；
  map 加 `getDiariesWithPosition()`。

### E. 测试基建
- [x] storage 出 `lib/testing.dart`：合并 5 份漂移的 InMemoryKV（以带故障注入的
  storage 版为准）。openTestIsar 别放这（storage 够不着 models）；要做放 moodiary_data
  侧 openTestDb()。
- [x] 4 个包各建 `test/support/pump.dart` 收 23 份手抄 widget 脚手架（delegates 漏抄
  即中文日期选择器崩的那个坑）；手抄压到 4 份后再议抽 test_kit 包。
- [x] task.dart 加 `test-all`（与 CI 逐字一致，无 fvm 前缀）；melos script `test`
  指向它并改掉「运行全部测试」的误导 description；保留 `test-mobile`。
  --coverage 单开任务，别捎带（CI 无缓存、冷跑 11.5min）。
- [x] 迁移旧步骤补测试入口：merge 加 `databaseDir` 参数 + 三个具名 debug 静态
  （别做 stringly-typed debugStep）；优先 2.6.0（重写全部正文）与 2.7.3（清字体表）。
  排在 0.3 之后——CI 不跑 dylib 时新用例照样 skip。
- [x] 测试 schema 手抄两处改用真源（`schemas: moodiarySchemas` /
  `legacyMigrationSchemas`，两行）。
- [x] mobile/test 里 6 个包测试归回各自包（两份「同名」其实互补，合并改名别覆盖）；
  删空目录（空 test 目录截断 melos 扫描）。
- [x] lock 包补 lock_page 状态机 widget 测试（AppLockPin.verifier 注入 + pump 推
  Timer + lockType:'pause' 避路由）——:124-126 注释里那个真实缺陷该有回归测试。
  不先抽 LockAttemptPolicy（今天就能直接测）。

### F. 卫生（一次清完，约 1-2h）
- [x] 死依赖：moodiary_files 的 file_picker、moodiary_sync 的 share_plus、
  moodiary_media 的 mui、mobile 的 `isar_plus: any`（唯一非精确版本）、
  moodiary_diary 的 moodiary_di 挪 dev、moodiary_export 的三条 riverpod、
  storage dev_dependencies 四条反向 `any`（分层重构残留，从未被用）。
- [x] 两个 `*ForSync` 纯别名删除（dashboard 拿它做 UI 统计，命名已在误导）。
- [x] 9 个从未用 ref 的 Consumer 降级 Stateless/Stateful；moodiary_lock 的
  flutter_riverpod 依赖随之可删。
- [x] search_controller 手写 `_disposed` 改 `ref.mounted`。
- [x] 路由归位：6 条 app 私有设置路由搬进已存在的 setting_routes.dart + 改
  routes.dart:5「移动端应用的」注释（2h）；6 条 feature 私有路由照 assistant 写法
  搬回各包（可选）。**跨包的 DiaryRoute/ShareRoute/MediaRoute/LockRoute 等不动。**
- [x] 文档漂移：根 CLAUDE.md「20 packages」→ 27、补 moodiary_picker 条目；
  picker 的 pubspec description 与 barrel 注释对齐现状；agreement_page「实验室」→
  「服务」；main.dart:115-116 字面量改 `LockRoute.path` / `StartRoute.path`；
  `_resolveInitialLocation` 提 @visibleForTesting 补三例测试。
- [x] check_layers 性能：四趟全量递归遍历（36 万条目、followLinks:true、含 95G
  rust/target）收成一次遍历 + 排除表 + followLinks:false，6.3s → 毫秒级。
- [x] moodiary_logging 补 loggerFactory seam + debugReset，钉住 427aae3a 刚修的
  「configure 晚于首条日志」行为。
- [x] sync_logger 静默降级 catch 补一行 logger.w（降级行为保留，测试依赖它）。
- [x] AsyncValueExtension 错误态别把原始异常串怼给用户（error 参数 + l10n 占位 +
  重试；原始异常只进 logger）。

### G. moodiary_data 瘦身（核验后只剩这一件成立）
- [x] 4 个 assistant 专属仓储（agent_preset/chat/llm_provider/memory）搬进
  moodiary_assistant/lib/src/data/（补 isar_plus 精确版）；库注释写准入线
  「只被单个 feature 读的不进 data」。**Tombstone/CategoryController/
  MediaInfoController 不搬**（核验：搬了会更差——墓碑读写方会被切成两包，
  categoryById 是真跨包成员）。约 3h 含 build_runner。

---

## P2 — desktop 立项时再做（现在只记档）

- **DI 结论（写进 mobile/CLAUDE.md 三行，现在就写）**：desktop 建自己的
  `desktop/lib/app/di/di.dart`（同四个 externalPackageModulesBefore），只需补
  IHttpClient + IFilePicker 两条绑定；**不用 @Environment 分平台**（已读
  injectable_generator 源码：两 app 两份 config 天然隔离；environment 要求两端实现
  同包，会把 wechat picker 塞给桌面）；@Environment('test') 已评估否决
  （generateForDir 只扫 lib，替身在 test/ 下扫不到）。
- **check_layers 的 `_appDirs` 参数化**：5 处硬编码 `mobile/`，desktop 落地当天会
  同时漏检+误报——这条便宜（2h），可在 P1 顺手做。
- 推迟项：app_shared 包（桌面设置页信息架构未定，搬了是固化注定重写的形态）、
  feature barrel 导出页面重排、tab 可寻址（shellTabProvider 半小时版可顺手，query
  深链等真需求）、StartupHooks、PlatformService 抽 IAppPaths 端口（届时连
  mmkv.dart:54 的调用点一起）、IMediaExport（gal 只缺 Linux）、多窗口三 tracker
  接口化（方案未定，先把 open_diary_registry 注释里「桌面多窗」的过头承诺改掉）。

---

## 已否决项（对抗核验的裁定，别再提）

| 提议 | 否决理由 |
|---|---|
| 仓储进 get_it 容器 | 撞 injectable-di-migration 拍板；desktop 多窗口论证错误（分 isolate 下容器也是 static）；127 调用点换来的收益已有更便宜解法 |
| @Environment 分平台/测试 | 两 app 两份 config 天然隔离；test 替身在 lib 外扫不到 |
| 「媒体管线整体桌面阻塞」 | gal/fc_native/local_auth/connectivity/screen_brightness/volume_controller 均支持桌面；唯 heif_converter 与 video_player 例外 |
| HEIF 走 Rust image facade | image crate 无 HEIF 解码器；libheif = C 库 + HEVC 专利 + 体积 |
| export 转发绕过闸门 | depend_on_referenced_packages 挡住方向逃逸；只剩「转发未声明包」半条可加 |
| moodiary_data 是垃圾抽屉 | 只有 4 个 assistant 仓储成立；Tombstone/两 controller 搬了更差 |
| eager static final 碰一次永久坏 | Dart static final 失败不缓存，实测重新求值 |
| pull 攒批落库修 O(N²) | 拉长 LWW 重读窗口，与引擎不变量相反；用 defer+阈值 rebuild |
| _cleanLocalMedia 移出仓储交调用方 | 把「删行必删媒体」单点不变量摊给每个调用方 |
| 强迁移闸门加 KV 短路 | 有同步回灌口（watcher 不挡未迁移行，另一台 pull 回旧行后标记永久关闸）；且单标量过滤扫描本就十毫秒级 |
| ref.keepAlive 替 EditController 的 _latest | 押注帧末 dispose 时序，不比现状稳；_latest 还承担并发职责 |
| chat/llm 补类型化事件 | 小表全量重查是合身不是退化；缺的是成文判据（进 CLAUDE.md） |
| 兜底页放「重置数据」主按钮 | resetAllData 第一句碰 Isar/KV，装配失败时按钮自己会抛 |

## 执行顺序

1. **P0（本轮）**：0.8 → 0.1 → 0.2 → 0.7 → 0.6 → 0.5 → 0.9 → 0.4 → 0.3（先易后难，
   0.3 最后因为要本机先验证真库用例）。每项完成勾选并跑 analyze。
2. **P1**：C 的 CLAUDE.md 先写（防复发）→ F 卫生一把清 → A/B/D/E 按包分批。
3. **P2**：desktop 立项触发；其中 DI 三行记档与 _appDirs 参数化可提前。

---

## P1 执行补记（2026-08-26）

全部落地（9 个 commit），analyze 零告警、`task.dart test`（CI 口径 + dylib）全绿。与清单的偏差：

- **riverpod_lint 暂缓**（analyzer 13.3.0 上 workspace 根的 plugin 加载但不给嵌套包出
  诊断；复查条件见 moodiary_lint 的 analysis_options 注释）。
- **dashboard 字数投影未做**：改读 DiaryIndexSnapshot.contentChars 依赖「索引已回填」，
  升级用户（searchIndexBackfilled=false）会统计出 0——正确性风险大于收益，维持
  getAllDiaries；map 与 PickedScope 两处投影已做。
- **HEIF 端口比清单更进一步**：直接抽了 IHeifDecoder + heif_converter 移 mobile
  并入 `_assertRequiredBindings` 清单。
- pump 脚手架按「先 4 份再抽包」的第一步落地（diary/components 两份 +
  三个 delegates 手抄文件迁移；mui/mobile 各自内聚，未强迁）。
- 执行中发现并修复：MediaCleanupController 换 provider 取仓储会在 dispose 后炸
  （其注释明说 ref 会被回收）——保留静态取用并写明原因；search_controller 的
  `_repository` 在 tokenize await 后无守卫，补 `ref.mounted`。

