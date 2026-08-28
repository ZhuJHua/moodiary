# 本地 RAG 设计（llamadart + sqlite-vec）

> 调研结论 + 目标 schema + 嵌入管线 + 助手工具接线。输入：助手 agent 架构盘点（rig 0.42 / 工具桥 / facade 闸门）、rig-sqlite 与 sqlite3.dart hook 生态现查、llamadart 源码级核查（hook 校验 / user_defines / embedding API）、sqlite-vec 与 sqlite_vector 对比（2026-08-28 现查）。取代 2026-07 的旧 RAG 设计稿方向（candle + Isar blob 暴力余弦——DB 已迁 SQLite、推理框架改选 llamadart，该稿的分块/工具/重嵌策略仍沿用）。

## 0. 结论先行

**方案 = llamadart（llama.cpp，CPU compact）做嵌入 + sqlite-vec（vec0 虚拟表）存查向量 + `semanticSearchDiaries` 显式工具接入助手。** 全链路在 Dart 侧：

```
bge-small-zh-v1.5 GGUF (Q8_0, 26MB, 运行时下载)
        │  llamadart embedBatch（cpu compact，预计 +4~6MB/ABI）
        ▼
drift 主库：diary_chunks（关系真源）+ vec0 虚拟表（KNN）
        │  异步补嵌队列（embed_queue，写日记入队、关编辑器/启动排空）
        ▼
semanticSearchDiaries 工具（与 queryDiaries 同一条 Dart 工具桥）
```

- **Rust 零改动**：不碰 rig、不碰 facade 闸门、不碰单 .so。rig 的接入点就是「新增一个工具定义」，与现有 15 个工具完全同构。
- **rig-sqlite 明确否决**：强制 `rusqlite bundled` = 第二份 SQLite，直接撞 `docs/sqlite-migration.md` §1 的共存禁令；还要求 Rust 侧开库、自持表 schema，破坏「Rust 完全不碰数据库」的分工。收益仅省两个方法的胶水，不值。
- **candle 方案（stash@{4}）不用于 RAG**：用户拍板换 llamadart。stash 里可借鉴的只剩模型下载服务的思路（hf-mirror + 进度 + 校验）；whisper/情感分类将来若捞，另议运行时。
- **sqlite_vector（sqlite.ai 的 pub 包）否决**：Elastic License 2.0 双许可与本仓 AGPL-3.0 分发有合规灰区；hook 里预编译二进制**无任何校验**（本机有 proc-macro1 前科，供应链标准从严）。功能上它的「普通 BLOB 列 + 全扫函数」形态确实更贴 drift，但两条硬伤足够出局。
- 向量表是**纯派生数据**：不进备份/同步/LocalArchive，重装重建，模型切换整表重灌。sqlite-vec 0.1.x alpha 的存储格式风险由此吃下。

## 1. 依赖选型（核查结果，2026-08-28）

### 1.1 llamadart 0.8.x（MIT，认证 publisher leehack.com）

- **API**：`LlamaEngine(LlamaBackend())` → `loadModel(path, ModelParams(...))` → `embedBatch(texts, normalize: true)`。官方自带 embedding 示例与 OpenAI 兼容 server 示例；llama.cpp 原生支持 BERT 系 embedding GGUF。
- **原生库交付**：build hook 首次构建时从 `leehack/llamadart-native` GitHub release 下载，**每个产物的 sha256 钉死在 hook 源码里**，校验失败即重下/报错。`llamadart_native_path` user-define 支持指向本地自编产物（供应链逃生口）。
- **体积可配**：默认 Android 打 `['cpu','vulkan']` 后端 + `cpu_profile: full`（armv8.0→armv9.2 共 7 个 CPU 变体 + 57MB 的 vulkan，arm64 完整包 37MB 压缩）。嵌入负载 GPU 无收益，**收敛为 cpu-only；cpu_profile 用 full**（2026-08-28 用户拍板：7 个变体 ≈ 72MB 原始 / ~19MB 压缩，换新芯片的 DOTPROD/I8MM/SVE 内核——变体是同一 arm64 下按 CPU 特性分级的优化内核，运行时挑最优，baseline 兜底所有设备，无兼容性含义）。compact（单 baseline 变体）≈ 18.5MB 原始 / ~6MB 压缩，留作将来的体积杠杆。**两个已踩实的键形坑（2026-08-28）**：
  1. `hooks.user_defines` 只认 **workspace 根 pubspec.yaml**（flutter_tools 取 package_config.json 同级的 `../pubspec.yaml`），放 `mobile/pubspec.yaml` 静默无效——首次打包因此带上了整套 GPU 后端；
  2. `llamadart_native_backends` 必须**按平台键**给（`platforms:` 或直接平台键），平铺 `{backends:, cpu_profile:}` 会被解析成 null 落回默认。

  根 pubspec 的正确写法：

  ```yaml
  hooks:
    user_defines:
      llamadart:
        llamadart_native_runtimes: llama_cpp   # 只要 llama.cpp 家族，不拉 LiteRT-LM
        llamadart_native_backends:
          platforms:
            android:
              backends: [cpu]
              cpu_profile: full   # 2026-08-28 用户拍板：7 个 CPU 变体全带（+~52MB 原始），换新芯片上 DOTPROD/I8MM/SVE 内核
            windows: { backends: [cpu] }
            linux: { backends: [cpu] }
  ```

  （Apple 端不走 backends 配置，Metal 编在主库里天然带着。）
- **门槛（2026-08-28 均已拍板落地）**：
  1. **iOS 部署目标 15.0 → 16.4** ✅（llamadart 硬要求，用户拍板）。
  2. **iOS 完全迁 SPM、CocoaPods 整体移除** ✅：核查时项目已处共存模式（SPM 默认开启），26 个 iOS 插件全部无 pod 依赖（25 个带 Package.swift；path_provider_foundation 2.6.0 已是纯 Dart FFI），Podfile.lock 只剩 Flutter 占位 pod——Podfile/Pods/pbxproj 的 [CP] phase 与 Pods 引用全部删除，`flutter build ios` 纯 SPM 链路验证通过。顺带清掉了 permission_handler 时代遗留的 PERMISSION_* 死配置。
- **风险**：0.8.x、单维护者（46 likes / 6.7k 周下载）。对策：engine 只在 `moodiary_ml` 包内出现，业务面向 `EmbeddingEngine` 窄接口，可换底。
- 版本按仓规**精确钉死**。

### 1.2 sqlite-vec 0.1.x（asg017，MIT/Apache 双许可）

- **接法 = 自建 loadable 扩展，不重编 SQLite**：现有 `sqlite3: 3.5.2` 预编译库照用。新建 foundation 叶子包 `moodiary_sqlite_vec`：
  - **vendor 进仓**：release 的 amalgamation（`sqlite-vec.c` + `sqlite-vec.h` + `sqlite3ext.h`），版本钉死、diff 可审——从源码编，规避预编译信任问题；
  - `hook/build.dart` 用 `native_toolchain_c` 编成 loadable 扩展（**不定义 `SQLITE_CORE`**，产物几百 KB）注册为 code asset；
  - 暴露 `loadSqliteVec()` = `sqlite3.ensureExtensionLoaded(SqliteExtension.inLibrary(lib, 'sqlite3_vec_init'))`，走 `sqlite3_auto_extension`，之后 drift 的每个连接（含 readPool 与后台 isolate）自动带上 vec0。
- **调用时序**：`MoodiaryDatabase.open()` 内、`createInBackground` 之前调用（moodiary_data 依赖该叶子包）。测试侧 `flutter test` 同样经 hook 拿到扩展，FTS5 能力闸门测试旁边加一个 vec0 能力闸门测试（`vec_version()`、建表、KNN、按 rowid 删）。
- **drift 摩擦（接受）**：drift_dev 不认识 `vec0`——建表进 `MoodiaryDatabase` 迁移的 `customStatement`，KNN 查询走 `customSelect`；schema 真源 `.drift` 文件覆盖不到这一张表（与 FTS5 的 rank 配置同类，已有先例）。
- **alpha 风险（接受）**：v1.0 前存储格式可能破坏性变更。向量表纯派生、可全量重建，升级 = 重建，无迁移负担。近期已专门修过 Android 16KB page。

### 1.3 嵌入模型（2026-08-28 扩为四档清单）

内置清单四档（均 Q8_0 GGUF、llama.cpp 官方支持架构；**前缀与上下文是模型契约，随 spec 走**，engine 不再硬编码 bge 前缀）：

| 模型 | 体积 | 维度 | 前缀契约 |
|---|---|---|---|
| bge-small-zh-v1.5 | 26MB | 512 | bge 中文指令前缀（query 侧） |
| bge-base-zh-v1.5 | 105MB | 768 | 同上 |
| bge-large-zh-v1.5 | 332MB | 1024 | 同上 |
| BGE-M3（gpustack GGUF） | 635MB | 1024 | **无前缀**（M3 明确不需要指令），ctx 1024 |
| EmbeddingGemma-300M（ggml-org 官方） | 334MB | 768 | `task: search result \| query: ` / `title: none \| text: `，ctx 1024 |

- **不进 APK**，运行时下载：hf-mirror.com 默认源（KV 可切官方），流式落盘 + 进度 + `.part` 半成品 + 下载后真加载探测校验。BYOM 导入（file_picker 任意 embedding GGUF）P4。
- 换模型 = 维度变 = 全量重嵌（§3.4）；**引擎在 backend 驻留模型与激活模型不一致时强制先卸载再载新**（切换正确性）。
- 设置页为模型选择 sheet：下载/切换/删除非激活模型文件/停用（停用清索引、保留模型文件）。

## 2. 目标 schema（全部纯派生，不进备份/同步）

```sql
-- 关系真源：chunk 归属与幂等判据（普通表，进 rag_tables.drift）
CREATE TABLE diary_chunks (
  rid        INTEGER PRIMARY KEY,          -- rowid 别名，与 vec 表对齐
  diary_id   TEXT NOT NULL,                -- 不做外键：删除路径显式清理（见 §3.3）
  seq        INTEGER NOT NULL,             -- chunk 在文内的序
  start_off  INTEGER NOT NULL,             -- 在 content_text 中的字符偏移（摘录回显用，不复制文本）
  len        INTEGER NOT NULL,
  text_hash  TEXT NOT NULL,                -- chunk 文本哈希，重嵌幂等判据
  UNIQUE (diary_id, seq)
);
CREATE INDEX idx_diary_chunks_diary ON diary_chunks(diary_id);

-- 向量：vec0 虚拟表（customStatement 建，rowid = diary_chunks.rid）
CREATE VIRTUAL TABLE vec_diary_chunks USING vec0(
  embedding float[512] distance_metric=cosine
);

-- 补嵌队列
CREATE TABLE embed_queue (
  diary_id    TEXT PRIMARY KEY,
  enqueued_at INTEGER NOT NULL             -- UTC micros
);
```

- **一真源一索引**：`diary_chunks` 管归属与幂等，`vec_diary_chunks` 只存向量，rowid 对齐（与 `diaries.rid ↔ diary_fts` 同构）。不用 vec0 的 metadata/partition 列——alpha 期把面积压到最小，过滤靠 JOIN 回主表。
- KNN 形态（customSelect）：

  ```sql
  SELECT c.diary_id, MIN(v.distance) AS best
  FROM vec_diary_chunks v
  JOIN diary_chunks c ON c.rid = v.rowid
  JOIN diaries d ON d.id = c.diary_id AND d.show = 1
  WHERE v.embedding MATCH :query AND k = :k
  GROUP BY c.diary_id ORDER BY best LIMIT :limit;
  ```

  分类/日期过滤是 KNN 后过滤，`k` 取 `limit * 4` 超采样（v1 简单口径；命中不足不补捞）。
- 模型登记走 KV（复用 MoodiaryKVs 五类型约束）：`embeddingModelId`（激活模型，空 = 功能未启用）、`embeddingDim`、`embeddingIndexStale`（bool，见 §3.4）。

## 3. 嵌入管线

### 3.1 分块

- 输入 `content_text`（已是纯文本派生），按空行切段、相邻段合并至 **≤400 字符**（bge 512 token 上限的保守 proxy），不重叠；标题非空时作为 chunk 0 单独嵌入。
- 全部在 Dart 侧完成（纯字符串操作，不过 FFI）。

### 3.2 写入路径：异步补嵌（不进写事务）

嵌入是几十 ms~秒级/篇的推理，**不能进「先分词后事务」的 inline 索引**。与 FTS 不同，向量缺失只降语义召回、不破坏一致性，所以异步是对的：

- **入队**：`insertDiaries`/`updateADiary` 的写事务里顺手 `INSERT OR REPLACE INTO embed_queue`（同事务，一行，零成本）。`fromSync: true` 的写入同样入队（同步拉回的日记也要可语义检索）。
- **排空触发**：编辑器关闭、App 启动兜底、语义检索被调用且队列非空时先排空小批——三个触发点复刻已退休 ReindexQueue 的经验形状，但这次动机成立。
- **排空逻辑**（`EmbedIndexService.drain`，moodiary_data）：批量出队 → 逐篇分块 → 与 `diary_chunks.text_hash` 比对，只嵌变化的 chunk（`embedBatch` 整批过一次引擎）→ 删旧 chunk 行与向量、插新行与向量（同事务）→ 队列删行。任何一篇失败留队，下次触发重试。
- **引擎生命周期**：懒加载（首次 embed 时 `loadModel`），排空完成后 idle 60s 卸载（Q8 模型常驻 ~40MB RAM，不长期占用）。

### 3.3 删除与回收站

- 永久删除日记：`_clearIndexesBatch` 现有清理点追加「删 `diary_chunks` + 对应 `vec_diary_chunks` rowid + `embed_queue` 行」（同事务；先查 rid 列表再两表删）。
- 回收站（`show=0`）**不删向量**：KNN 的 JOIN 带 `d.show = 1`，恢复即生效，与 FTS 的处理一致。

### 3.4 模型切换 / 索引重建

- 切模型（含维度变化）：置 `embeddingIndexStale`，`DROP` 并按新维度重建 vec0 表、清 `diary_chunks`、全量 re-enqueue，设置页 banner「重建语义索引」——完整复刻 `searchIndexBackfilled`/`rebuildAllIndexes` 先例；数据修复 tile 同步加一项。
- sqlite-vec 升级若破坏存储格式：同一条重建路径兜底。

## 4. 助手接线

### 4.1 `semanticSearchDiaries` 工具（唯一新增面）

- 与现有 15 个工具同构：定义进 `assistant_defs.dart` 工具清单（读级、免确认）、实现进 `assistant_tools.dart`、经既有 `allowedTools` 快照闸门与 Dart 工具桥执行，**rig/Rust 零改动**。
- 入参：`query`（自然语句，必填）、`categoryId?`、`startDate?`/`endDate?`、`limit`（默认 5，上限 10）。
- 实现：`embedQuery(query)` → §2 的 KNN customSelect → 按日记聚合（最佳 chunk 距离）→ 复用 `_formatDiaryList` 的摘录形状，摘录取最佳 chunk 的 `start_off/len` 切片（语义命中的上下文比开头 N 字更有用）。
- **降级路径**：模型未激活 / 索引未建好时返回明确英文说明（"semantic index not ready, use queryDiaries instead"），模型自然回退关键词检索。工具描述里写清与 `queryDiaries` 的分工：关键词/精确过滤用 query，模糊语义（"那次很失落的旅行"）用 semantic。
- 工具变更四件套照仓规走：defs / ui（工具卡摘要行 i18n）/ l10n / prompt 目录层。

### 4.2 不做的

- **rig `dynamic_context` 被动 RAG 不做**：每轮模型调用都盲检索，费 token 且不可控；工具制让模型自己决定何时查、带什么过滤。将来若要「自动带出相关日记」再评估（VectorStoreIndexDyn 可用 Dart 回调实现，路是通的）。
- **混合检索（FTS ∪ 向量 + RRF）v1 不做**：两个工具并存已覆盖两类意图，融合排序等真实使用反馈再说。
- `memories` 长期记忆向量化：P3，同一套管线（单 chunk、同 vec 表加 kind 前缀或另开小表，届时定）。

## 5. 分层与依赖

| 包 | 动作 |
|---|---|
| `packages/foundation/moodiary_sqlite_vec`（新） | vendor sqlite-vec 源码 + hook 编 loadable 扩展 + `loadSqliteVec()`；零 moodiary 依赖的叶子包 |
| `packages/feature_base/moodiary_ml`（新，层内序 0，与 models 平级互不引） | 独家 own `llamadart`（barrel 惯例）；`EmbeddingEngine`（embedQuery/embedPassages/加载卸载）+ 模型下载/激活管理（依赖 core 的 http/files/storage） |
| `moodiary_data` | 依赖上两包；`rag_tables.drift` + vec0 customStatement；`EmbedIndexService`（队列/排空/重建）；KNN 查询；`_clearIndexesBatch` 追加清理；`_featureBaseOrder` 的 data 序号跟随 +1 |
| `moodiary_assistant` | `semanticSearchDiaries` 工具（defs/impl/ui/l10n） |
| `mobile` | pubspec 的 llamadart user_defines；设置页模型下载/重建入口挂接 |

`tool/check_layers.dart`：`_featureBaseOrder` 插入 `moodiary_ml: 0`；其余闸门（rust facade、mui、层方向）零改动。

## 6. 风险与 spike 清单

1. ~~iOS 最低版本 15.0 → 16.4~~ ✅ 已拍板并落地（§1.1）。
2. ~~iOS SPM~~ ✅ 已完全迁移、CocoaPods 整体移除（§1.1）；llamadart 接入时真机再验四 hook 并存（moodiary_rust + sqlite3 + llamadart + moodiary_sqlite_vec）。
3. **P0 体积实测**：cpu+compact 配置下 Android arm64 APK 增量（user_defines 键形一并校准）；红线参照 sqlite 迁移的口径给出压缩后数字。
4. **P0 端到端 spike**：bge-small-zh Q8_0 经 llamadart `embedBatch` 出向量 → 与官方 sentence-transformers 结果余弦对齐（>0.99）；真机单 chunk 延迟与批量吞吐；模型加载耗时与 RAM。
5. **P0 vec0 经 drift spike**：hook 编译四平台产物、`ensureExtensionLoaded` 后 `createInBackground`（readPool + 后台 isolate）各连接 vec0 可用、KNN JOIN 形态跑通、宿主 `flutter test` 零配置拿到扩展。
6. **检索质量验收**（P2 后人工）：中文日记语料上 semantic vs keyword 各 10 组对比；超采样倍数（×4）与 chunk 上限（400 字符）按结果调。
7. **llamadart 跟进策略**：升级前看 llamadart-native tag 变更（llama.cpp 版本跳变可能改 GGUF 兼容性）；`llamadart_native_path` 留作供应链逃生口。
8. **GPU 后端体积账**（llamadart-native v0.3.0 实测，2026-08-28；当前拍板 CPU-only，GPU 留给将来的端侧 LLM）：
   | 平台 | GPU | 额外体积（原始 / 压缩） |
   |---|---|---|
   | iOS / macOS | Metal 编在主库里 | **0**（iOS 整包压缩 4.1MB、macOS 单 dylib 13MB，已验含 ggml_metal） |
   | Android | Vulkan | +57.3MB / +14.8MB；OpenCL（仅 Adreno）+12.8MB / +3.0MB |
   | Windows | Vulkan +54MB；CUDA 巨大（win-x64 整包 732MB） | |

   参照：Android `cpu+compact` ≈ 核心 9.9MB + 单 CPU 变体 8.6MB = 18.5MB 原始 / ~6MB 压缩。切换只是 `llamadart_native_backends.backends` 一行，运行时 `GpuBackend.auto` 自动挑。

## 7. 实施分期

1. ~~P0 spike~~（用户拍板跳过，直接实现；§6 的体积/端到端两项并入真机验证）。
2. **P1 存储与管线** ✅（2026-08-28）：`moodiary_sqlite_vec`（vendor 0.1.9 源码 + native_toolchain_c 编 loadable 扩展 + `loadSqliteVec()`，vec0 宿主测试 3/3）+ `moodiary_ml`（llamadart 引擎：懒加载/60s 空闲卸载/bge query 前缀；模型下载走新加的 `IHttpClient.downloadFile`——Rust 侧 `download_file` 流式落盘+进度+取消删半成品，`.part` 后缀 + 真加载探测校验）+ `rag_tables.drift`（schema v2，onUpgrade 建表）+ `EmbedIndexService`（入队制：写路径三处同事务插 `embed_queue`，硬删也入队由 drain 回收孤儿；hash 幂等跳过；stale 标记驱动全量重建；KNN JOIN 检索）。集成测试 11/11（确定性 one-hot 替身 embedder）。
3. **P2 工具与接线** ✅（同日）：`semanticSearchDiaries` 四件套 + 降级话术 + catalog 层检索分工指引；mobile：DI 挂载（第五个 micro-package）、启动排空 + diaryEvents 10s 去抖排空、服务页「语义检索」组（下载进度/启用/停用/重建）、llamadart user_defines（`llama_cpp` runtime + cpu compact）、`resetAllData` 清模型目录。全仓 analyze/层检查/`task.dart test`/cargo test 全绿。**真机端到端待验**（下载→激活→建索引→助手语义检索；体积增量顺带实测）。
4. **P3 记忆检索**：`memories` 向量化并入管线。
5. **P4 可选**：BYOM 导入、int8 量化存储（DB 减半）、混合检索 RRF、`dynamic_context` 自动召回评估。
