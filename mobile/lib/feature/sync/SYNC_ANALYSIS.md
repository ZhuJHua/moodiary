# 增量同步架构说明与待办

> 最近全面复查：2026-06-23（对抗式数据丢失审计 + 引擎级测试落地）。
> 本文档只记录**当前架构、必须遵守的设计契约、仍开放的问题**；
> 已修复的 bug 与已落地的优化不再保留（见 git 历史）。

## 一、架构概览

```
SyncController (Riverpod)        UI 状态机 idle → syncing → success/error
AutoSyncWatcher                  单开关 autoSync：变更去抖 5s 后 push + 定时轮询 syncAll（间隔可配，默认 30s）
        │
IRemoteSyncBackend               后端抽象（webdav / s3，DI 单注册，可插拔）
        │  pushAll / pullAll / syncAll
IncrementalSyncEngine            增量引擎（按操作构造）
        │  ├─ _lock (synchronized)        进程内互斥：push/pull/re-cipher 同时只跑一个
        │  ├─ RemoteLease (sync.lock)     跨设备互斥：租约 + TTL + 续租 + deviceId 接管
        │  ├─ _GatedBackend (Pool)        网络请求并发上限（KV syncConcurrency，默认 8）
        │  ├─ _mediaGate (Pool)           媒体「读+加解密+传输」流水线并发上限（限内存）
        │  └─ SyncCipher                  AES-256-GCM（userKey 配置即加密），操作内复用实例
        │
SyncManifest (v4)                远端清单：结构化条目 + 媒体清单 + 毫秒时间戳
TombstoneTracker                 多后端 tombstone 覆盖跟踪（KV）
CloudReCipher                    远端整体换密钥（与 push/pull 同级双重互斥）
SyncLogger                       事件流（UI 实时）+ 按天 jsonl 滚动日志
```

**远端布局**：`manifest.json` + `sync.lock` + `diary/<id>.json` +
`category/<id>.json` + `media/<type>/<filename>`。

**同步流程**（`sync()` = 同一临界区内先 pull 后 push）：
- **pull**：读 manifest → 条目级 `_runPooled` 并发；每条按毫秒时间戳 LWW，
  写入本地前**重读**当前版本做最终比较（防长 pull 期间用户编辑被覆盖）；
  tombstone 软删本地（媒体连删）；下载日记后连带下载缺失媒体；
  对 LWW 跳过的条目也补拉缺失媒体（媒体下载失败可在后续 pull 自愈）。
- **push**：读 manifest → 构建「远端已有媒体」集合（全条目媒体清单并集）→
  条目级并发：媒体先传（集合命中零往返跳过 / 集合外 stat 兜底）→ 写 JSON →
  更新内存 manifest 条目（携带**确认存在**的媒体清单）→ 清理不再引用的旧媒体
  （diff 取自旧条目清单，删除前检查全局引用）→ 结尾一次写回 manifest →
  清理「已覆盖全部云后端」的 tombstone 日记。

## 二、设计契约（改代码必须遵守）

1. **后端错误语义**：`readObject` **仅** 404/NoSuchKey 返回 `null`、
   `deleteObject` 仅 404 静默成功；其它错误（网络/认证/5xx）必须抛
   `SyncException`。吞错会让 push 把 manifest 从零重建、丢失远端独有条目。
   Rust 层（`webdav.rs` / `s3.rs`）负责 404 的结构化判定，Dart 后端层不吞错。
   **同理 `_readManifest`**：bytes 存在但解码出**非 JSON 对象**（被外部覆盖成
   array/null/字符串、半截写入 —— `jsonDecode` 不抛错但结果不是 Map）必须抛
   `SyncException`，**绝不能返回 `null`**，否则 push 同样会用本地重建 manifest、
   丢掉仅远端有的条目（有回归测试钉住）。`SyncManifest.fromJson` 对损坏的
   `entries` 字段（存在但非对象）、非 int 的 `version` 同样抛 `SyncException`，
   不静默当空清单 / 不抛裸 TypeError。
2. **LWW 全程比毫秒整数**：`ManifestEntry.timeMs` 是纯 int；引擎所有比较
   两侧都取 `lastModified.millisecondsSinceEpoch`。**禁止**改回 DateTime
   `isAfter` 对象比较 —— 本地 lastModified（Isar 按微秒存）的微秒尾数会让
   「本地 > 远端」恒成立、每次 push 全量重传（有回归测试钉住）。
   **删除路径同样走 LWW（日记与分类都要）**：push tombstone 前若远端仍是普通条目
   且 `remoteEntry.timeMs >= 本地删除时间` → 跳过删除（不标记 pushed / 不安排硬删）。
   旧删除不得抹掉远端更新内容（多半来自别的设备），与普通更新路径对称；
   下次 pull 会按 LWW 把更新的远端版本拉回、本地复活（日记 / 分类各有回归测试钉住）。
   对称地，**pull 下载写库失败必须计入 `failed`**（日记写抛异常被 catch；分类写
   经仓库映射成 `false`，须显式 `else failed++`）—— 否则谎报成功、错误推进 lastSyncTime。
3. **manifest v4 版本守卫**：`version != 4` 一律抛 `SyncException`（含更高
   版本 —— 静默丢条目会诱发 manifest 重建式数据丢失）；单条损坏的 entry
   只丢弃该条。开发期无历史兼容负担，格式变更直接改、不留兼容路径。
4. **媒体清单只记确认存在的引用**：`ManifestEntry.media` 来自
   `_pushDiaryMedia` 的返回值（集合命中 / stat 命中 / 上传成功）；本地缺失
   而跳过的引用**不得**写入，否则谎报存在、该文件永远失去补传机会。
5. **上传顺序**：媒体 → diary JSON → （内存条目更新）→ 结尾 manifest。
   保证 manifest 引用到的对象一定存在（媒体集合的正确性依赖此顺序）。
   **pull 软删的写入顺序对称**：`updateADiary(tombstone)` **先于**
   `_deleteLocalMedia`，且重读紧接写入、其间无 await —— 缩小「长 pull 期间
   并发编辑落库」与「写 tombstone」之间的竞态窗口（残余见已知限制）。
   **push 破坏性操作全部后置**：删远端 diary/category JSON、删远端孤儿媒体、
   硬删本地 tombstone 日记 —— 一律推迟到「manifest 写入 + 回读校验」成功之后
   执行（`deferredObjectDeletes` / `deferredMediaDeletes` / `tombstonedIsarIds`）。
   循环内只改内存 `updated.entries` 与 `remoteMedia` 簿记。见契约 9。
9. **manifest 写后回读校验（跨设备 CAS，不依赖服务器条件写）**：每次 push 写回
   manifest 时带一个唯一 `writeToken`（`SyncManifest.writeToken`），写完立即**回读**
   并比对 token；不一致 = 另一台设备绕过租约并发覆盖了 manifest，本次 push 抛
   `SyncException` 中止。因为所有破坏性远端删除 + 本地硬删都排在校验之后（契约 5），
   中止时**远端与本地数据都原封不动**，下次同步读到对方 manifest 按 LWW 收敛 ——
   把「租约失效 → 双写互相覆盖 → 丢日记」从永久丢数据降级为可重试。`CloudReCipher`
   的 manifest 写同样回读校验。有回归测试钉住（注入并发覆盖→断言零破坏）。
10. **syncStart 必配 syncEnd**：一次操作发了 `syncStart` 后，无论正常结束还是中途
    抛错（网络错误 / manifest 损坏 / 回读校验失败），都必须发出一个 `syncEnd`。
    `_exclusive` 在 catch 里补发兜底。否则 `AutoSyncWatcher` 监听这对事件的 `_syncing`
    闸门会卡在 true，自动同步静默失效到重启（有回归测试钉住）。
6. **锁层级**：进程内 `_lock` 在外、`RemoteLease` 在内；锁文件 `sync.lock`
   是**明文**（密钥不同的设备也要能读）。释放前必须先等掉在飞的续租写
   （`pendingRenew`），否则续租晚于删除落盘会复活孤儿锁。
7. **tombstone 跟踪**：`deleted=true` 的日记要等 tombstone 覆盖**全部**已配置
   云后端才能从 Isar 硬删；pull 恢复 / 本地胜出时必须 `tracker.clear([id])`，
   否则旧记录会让二次删除提前硬删、日记从未覆盖的后端复活。
8. **re-cipher 媒体覆盖**：媒体集合 = manifest 并集 **+ diary JSON 补收**
   （`_collectMediaRefs`）。后者覆盖「中断 push 留下的已上传未进 manifest」
   的对象 —— 漏掉会让它们保持旧密钥，之后被 stat 兜底确认进新 manifest，
   从此永远解不开。

## 三、已知限制（接受的权衡）

- **租约残余窗口**：持有方进程挂起超过 TTL（5min）后恢复，无条件续租会
  夺回已被他人接管的锁，两端短暂并行。需要「挂起 >TTL 且恰与他人同步重叠」。
- **非原子条件 PUT 的服务器**：不支持 `If-None-Match: *` 的服务器上锁抢占
  靠「创建后抖动回读校验」兜底，竞态窗口约一个往返而非严格原子。
- **本地缺失媒体不会自动补传**：push 时本地文件缺失只告警跳过；文件之后
  恢复也要等该日记下次变更才会重新上传。
- **pull 软删 vs 并发编辑的残余竞态**：长 pull 软删某日记时，若用户恰在
  `_deleteLocalMedia`（写 tombstone 之后）期间提交了更新，编辑后的活跃记录会
  存活、但其中沿用旧文件名的媒体可能已被删 → 破图。彻底修复需 repo 提供
  按 `lastModified` 的 compare-and-swap 写入（当前 Isar `put` 无此语义）。
  已通过「先写记录后删媒体 + 紧邻重读」把窗口压到最小。

## 四、开放问题 / 待办

| 项 | 说明 | 优先级 |
|---|---|---|
| tombstone GC | manifest 的 tombstone 条目与 Isar 中已删 Category 永久累积，每次同步都要遍历。需先定保留策略（如 90 天）再做基于时间的清理 | 中 |
| 孤儿媒体 GC | 远端可能残留无引用媒体（中断 push / 清理失败）。需给两个 Rust 后端加列目录接口（PROPFIND / ListObjects）+ FRB 重新生成，作为独立维护操作实现 | 中 |
| pull 重复探测远端确实缺失的媒体 | BUG-5 修复的补拉机制对「远端真没有」的媒体每次 pull 都发一次 404 探测。pull 侧可用 `entry.media`（远端已知存在集合）预判，缺失的直接跳过 | 低 |
| pull 不校验对象身份 | 下载的 diary JSON 未校验 `diary.id == manifest key`，损坏/被篡改的远端对象可能错位覆盖本地。可在 insert 前加一行校验 | 低 |
| AutoSyncWatcher 回声 push | pull 写库触发领域事件 → 同步结束后自动调度一次 push（全 skip，但有租约 3-4 往返 + manifest 读的开销）。轮询 syncAll（间隔可配，默认 30s）拉到远端变更后必然触发一次空 push，故此项现在更高频，间隔越短越频繁。可让 watcher 区分 sync 引发的事件，或接受现状 | 低 |
| manifest 体积 | 媒体多的库 manifest 可达数百 KB 且加密后不可压缩。可在加密前加 gzip/zstd（格式加一个压缩标记位） | 低 |
| ~~租约「网络分区→续租夺回」永久丢数据~~（**已缓解**） | 已落地「manifest 写后回读校验」（契约 9）+「破坏性操作全部后置」（契约 5）：租约即便被绕过、两端并发写 manifest，回读校验会让被覆盖方抛错中止，且中止前没做任何远端删除 / 本地硬删 → **不再永久丢数据**，降级为可重试。**残余**：「写后回读」之间仍有约一个往返的窗口（A 写→A 回读到自己→B 才覆盖），此时 A 会继续提交，最坏留下一条「manifest 有条目但 JSON 已删」的悬挂条目（数据仍在某设备本地，非彻底丢失）。彻底闭合需真正的原子 CAS：manifest 写走 HTTP 条件写 `If-Match:<etag>`（reqwest_dav / minio 均已确认可加，复用现有 `create_exclusive` 的条件头机制），**但 etag 引号/弱校验/各家 S3 兼容性需对真实后端验证**，故留作后续硬化；另可加「续租前回读、owner 变了就置中止标志」减少并发发生率 | 低 |
| 取消配置某后端→提前硬删→复活 | `configuredCloudBackendIds()` 每次 push 从实时 KV 重算；删除某后端配置会把它移出「需覆盖集合」，使一条 tombstone 尚未送达该后端的日记被提前硬删；之后重新加回该后端，pull 会把它复活（非丢数据，是「死而复生」）。可记录删除时的「待覆盖后端」快照，或接受「取消配置=放弃该后端」语义 | 中 |
| re-cipher 部分失败仍换密钥 | `CloudReCipher._run` 逐项失败只计数不中断，结尾**无条件**写新密钥 manifest 并由调用方落库新密钥；失败对象仍停留旧密钥，之后用新密钥永远解不开。re-cipher 非原子是根因：即便中止，已转换对象在旧密钥下又解不开。需改成全有或全无 / 失败重试到 0 / 过渡期双密钥尝试 | 中 |
| re-cipher 漏改中断残留媒体 | 中断 push 残留「已传 diary JSON + 媒体、未进 manifest」的对象：re-cipher 的对象集合只来自 manifest 条目（`_collectMediaRefs` 也只扫 manifest 列出的日记），漏掉该残留媒体 → 停留旧密钥；之后 push 的 stat 兜底仅凭存在性把它确认进新 manifest → 永久解不开。需先做孤儿媒体 GC / 列目录能力（见上「孤儿媒体 GC」） | 低 |

## 五、测试

测试镜像 `lib/` 结构放在 `test/feature/sync/`。引擎通过端口（`sync_stores.dart`
的 `SyncDiaryStore`/`SyncCategoryStore`/`SyncMediaFiles`）+ 可注入 cipher/logger/
concurrency 解耦，单测全用内存假实现（`sync_test_harness.dart`），不碰 Isar /
文件系统 / Rust / 网络，确定性运行。生产实现只是转发到 repository / FileUtil，
行为不变。

- `data/model/manifest_test.dart`：v4 序列化往返、版本守卫（旧/新/缺失均拒绝）、
  损坏条目丢弃、媒体并集排除 tombstone、`copyForUpdate` 隔离、**毫秒 int LWW 回归**。
- `data/remote_lease_test.dart`：租约 payload 往返、损坏容错、过期判定边界。
- `data/remote_lease_protect_test.dart`（fake_async）：抢占→执行→释放、接管本机
  残留锁、清除过期外部锁、外部活锁竞争 4 次后抛错且不动他人锁、长同步续租。
- `data/incremental_engine_test.dart`：push/pull/sync 主流程、LWW（推/拉/相等跳过）、
  媒体「先传后写 JSON」「本地缺失只跳过不谎报」「真失败则不写 JSON」「旧媒体清理」、
  部分失败不推进 lastSyncTime、tombstone 软删 + 保留更新本地、取消、
  **多后端 tombstone「覆盖全部后端才硬删」**，以及四条回归（manifest 非对象不重建、
  软删先写记录后删媒体、过期删除不覆盖更新远端、**并发 manifest 覆盖→写后回读校验
  中止且零破坏**）。
- `data/tombstone_tracker_test.dart`、`data/codec_test.dart`（明文路径）、
  `data/sync_registry_test.dart`（多后端 configured 集合 / 切换重注册）、
  `data/sync_stores_test.dart`（用 `package:file` 的 `MemoryFileSystem` 测真正的
  `DiskSyncMediaFiles`）、`data/sync_test.dart`、`data/model/sync_provider_test.dart`、
  `data/model/sync_event_test.dart`。
- 加密的 AES-GCM 实现走 Rust，`flutter test` 跑不了 → 引擎测试一律明文 cipher；
  `CloudReCipher` 的改写主循环（需新旧异密钥）同样无法在纯 Dart 单测覆盖。
