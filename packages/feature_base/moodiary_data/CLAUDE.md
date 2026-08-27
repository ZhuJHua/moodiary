# moodiary_data — 仓储与状态边界约定

这个包同时装着仓储与跨 feature 的 controller，是「get_it / riverpod / 进程级单例」
三条通道的物理交汇点。四条准则 + 硬事实，新代码照此写，别再各自发明。

## 四条准则

1. **get_it = 需要换实现的接线**（端口、平台实现，如 IFilePicker）。
   **仓储刻意不进容器**：`XxxRepository.get()` 是进程级静态单例，直接持
   `MoodiaryDatabase.get()`（drift；组合根在 `MoodiaryDatabase.open(path:)` 一处
   吸收平台差异）。schema 真源在 `src/db/schema.drift`，具名查询在 `src/db/*.drift`，
   改动后跑 build_runner。要替身：测试用 `XxxRepository.forTesting(
   MoodiaryDatabase.forTesting(NativeDatabase.memory(...)))`——记得 setup 里开
   `PRAGMA foreign_keys = ON`，级联删除靠它。消费侧真需要第二实现时在
   **消费侧**抽窄端口（只声明用到的几个方法 + 转发实现，样板见
   moodiary_sync 的 `sync_stores.dart`），不做全仓端口化。
2. **riverpod = 与界面生命周期挂钩的读模型**。provider 不 new 服务、不持有服务
   实例；仓储一律经 `repository_providers.dart` 的薄 provider 取用
   （`ref.watch(diaryRepositoryProvider)`）——那层薄 provider 是测试 override 的
   唯一抓手（`overrideWithValue(DiaryRepository.forTesting(db))`）。
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
- **SQL 关键字撞名会被 drift 静默吞列**：`key` 列必须写成 `"key"`；列名与
  `Table` 基类成员撞名（如 `text`）直接编译炸——memories 的正文列因此叫 `content`。
- **riverpod 3 默认对非 `Error` 异常指数重试 10 次（约 38 秒）**。本仓已在
  `mobile/lib/main.dart` 的 `ProviderScope(retry:)` 收紧为最多 2 次；
  `Error` 与 `ProviderException` 不重试。预期内的业务失败
  抛 `Error` 子类（如 `StateError`），别抛 `Exception`。
- provider 定义统一放各包 `application/`（或本包 src/ 顶层），不进 presentation。
- **错误约定：仓储抛异常，调用方按需 catch 且至少 `logger.e`**——别让库故障
  伪装成空列表。（TaskEither 已废弃：Left 从来没被任何消费端读过。）

## 事件通知的三种形态（按表选，别混）

- **大列表 / 要分页 / offset 必须与库对齐**（Diary/Category/MediaInfo）：类型化
  领域事件 + `applyXxxEvent` 内存增量，不重查库。订阅回调在 state 还是 loading 时
  收到事件必须置 missed 标记、首查后补一次重查（见 `LoadMoreMixin.markMissedEvent`），
  否则启动期 pull 的写入会静默丢。聚合类消费者的 200ms 去抖保留（如今重查是索引
  查询，去抖只是省聚合重算）。**分页对齐契约**：SQL 的 `ORDER BY ..., id DESC`
  与 `diarySortComparator` 的字段序必须逐字段一致（id = uuid v7，按创建时刻有序）。
- **小表**（ChatSession/LlmProvider 量级）：`Stream<void>` 信号 + 全量重查是合身
  的，别为它造事件类型与内存增量。
- **单对象跟随**：订阅 `diaryEvents` 按 id 过滤（getDiary provider；SQLite 无
  行级 watch，领域事件本就语义更强）。

## 写路径纪律

- `updateADiary` 的 `IndexMode`：动了 content/title → `inline`（分词先行，行 +
  FTS + 双链**同事务原子**落库——SQLite 时代没有两段式，也没有重索引队列）；
  **只动 show / mood / 分类等元数据 → `skip`**（索引只吃 content/title，show
  过滤在查询期）。
- 批量入口（云 pull / 导入）用 `insertDiaries`——整批一次分词（Rust 跨篇并行）+
  单事务落库。
- 用户编辑必须 bump `lastModified`；同步落库 / 迁移 / 修复等派生写入**不得** bump
  且事件带 `fromSync`（否则 LWW 丢编辑或凭空全量上传）。
