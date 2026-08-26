# moodiary_data — 仓储与状态边界约定

这个包同时装着仓储与跨 feature 的 controller，是「get_it / riverpod / 进程级单例」
三条通道的物理交汇点。四条准则 + 硬事实，新代码照此写，别再各自发明。

## 四条准则

1. **get_it = 需要换实现的接线**（端口、平台实现，如 IFilePicker）。
   **仓储刻意不进容器**：`XxxRepository.get()` 是进程级静态单例，直接持
   `IsarDatabase.get().isar`；平台差异由组合根在 `IsarDatabase.init(directory:,
   schemas:)` 一处吸收，desktop 重建时改的是 main，不是仓储。要替身：测试用
   `@visibleForTesting XxxRepository.forTesting(isar)`；消费侧真需要第二实现时在
   **消费侧**抽窄端口（只声明用到的几个方法 + 转发实现，样板见
   moodiary_sync 的 `sync_stores.dart`），不做全仓端口化。
2. **riverpod = 与界面生命周期挂钩的读模型**。provider 不 new 服务、不持有服务
   实例；仓储一律经 `repository_providers.dart` 的薄 provider 取用
   （`ref.watch(diaryRepositoryProvider)`）——那层薄 provider 是测试 override 的
   唯一抓手（`overrideWithValue(DiaryRepository.forTesting(isar))`）。
3. **进程级、跨页面、不随界面存亡的可变持有者**（RemoteSyncRegistry /
   SyncPendingTracker / SyncDirtyTracker / OpenDiaryRegistry / KVNotifier）留在
   容器外——既定决策。新代码经 provider 或构造参数暴露给 widget，不在 widget 里
   直接 `.instance.listenable`（存量不批量迁）。
4. **widget 的反应式通道以 `ref.watch` 为准**。跨包公开的 widget 不得命令式读
   全局 KV——那会把正确性挂在宿主怎么包（KeyedSubtree 换 key）这种写不进类型的
   契约上；要么走 provider，要么把值提成构造参数由宿主传入。

## 硬事实（错一条就是一类 bug）

- **codegen provider 默认 autoDispose**；keepAlive 是例外、必须写理由（现存两处
  都写了）。**手写 `NotifierProvider` 默认相反**（keepAlive），所以一律用 codegen。
- **riverpod 3 默认对非 `Error` 异常指数重试 10 次（约 38 秒）**。本仓已在
  `mobile/lib/main.dart` 的 `ProviderScope(retry:)` 收紧为最多 2 次、
  `Error`/`DatabaseException` 不重试。预期内的业务失败抛 `Error` 子类
  （如 `StateError`），别抛 `Exception`。
- provider 定义统一放各包 `application/`（或本包 src/ 顶层），不进 presentation。
- **错误约定：仓储抛异常，调用方按需 catch 且至少 `logger.e`**——别让库故障
  伪装成空列表。（TaskEither 已废弃：Left 从来没被任何消费端读过。）

## 事件通知的三种形态（按表选，别混）

- **大列表 / 要分页 / offset 必须与库对齐**（Diary/Category/MediaInfo）：类型化
  领域事件 + `applyXxxEvent` 内存增量，不重查库。订阅回调在 state 还是 loading 时
  收到事件必须置 missed 标记、首查后补一次重查（见 `LoadMoreMixin.markMissedEvent`），
  否则启动期 pull 的写入会静默丢。聚合类消费者对事件流要**去抖**（参考
  category_controller 的 200ms），isar_plus 读查询不走索引，每事件一次全表扫描。
- **小表**（ChatSession/LlmProvider 量级）：`Stream<void>` 信号 + 全量重查是合身
  的，别为它造事件类型与内存增量。
- **单对象跟随**：Isar `watchObject` 直出（见 `watchDiary` → getDiary provider）。

## 写路径纪律

- `updateADiary` 的 `IndexMode`：动了 content/title → `inline`（同事务写行+入队，
  再同步排空，崩溃自愈）；编辑期高频保存 → `defer`；**只动 show / mood / 分类等
  元数据 → `skip`**（索引只吃 content/title，show 过滤在查询期）。
- 批量入口（云 pull / 导入）用 `insertDiaries`，别循环 `insertADiary`——高频词
  posting 行会 O(N²) 重写。
- 用户编辑必须 bump `lastModified`；同步落库 / 迁移 / 修复等派生写入**不得** bump
  且事件带 `fromSync`（否则 LWW 丢编辑或凭空全量上传）。
