# Isar → SQLite 迁移设计（2.8.0）

> 调研结论 + 目标 schema + 强制迁移方案。输入：15 张 collection 的全量盘点、`diary_repository.dart`（1436 行）搜索引擎拆解、9 个仓储的查询清单、启动/迁移/同步耦合面核查、sqlite3 生态与 FTS5 中文方案外部调研（2026-08-27 现查）。

## 0. 结论先行

**迁移成立，且全文搜索能大幅简化。** 现有搜索引擎的 4 张手写索引表（SearchPosting / SearchStats / LinkPosting / DiaryIndexSnapshot）+ ReindexQueue + 约 300 行 diff/幂等逻辑 + 手写 BM25，超过 70% 是为「isar_plus 读查询永不走二级索引」这一条引擎缺陷量身定做的 workaround，FTS5 + 真实二级索引能整体吃掉：

| 现状痛点 | SQLite 后 |
|---|---|
| 所有 `.where()` 过滤都是全表扫描（`@Index` 纯写放大） | 真索引 seek（首页分页、回收站、媒体库、日期区间、`sessionId` 过滤全部受益） |
| 4 张索引表 @20k 占 284.8MB（比 118.8MB 的数据还大） | FTS5 doclist 自带 varint+delta 压缩，官方口径词级索引 ≈ 语料 45%，预计降一个量级 |
| posting key 是 fastHash，词典不可逆 → 无前缀/模糊/短语 | `prefix='2'` 前缀索引；`detail=full` 原生短语与 NEAR（现状结构性缺失的能力） |
| 手写 BM25F + Dart 主 isolate 打分（高频词 @20k 111ms） | `MATCH ... ORDER BY rank`，打分在引擎内，`bm25(fts, w...)` 列加权一比一替代 |
| 分词跨 FFI → 写行与写索引无法同事务 → ReindexQueue + 条件出队 + 启动排空 | **先分词后开事务**：sqlite3 是我们自己驱动的同步 API，行 + FTS 同一个事务原子落库，**ReindexQueue 整个退休** |
| schema 按位置下标寻址、只能追加；mdbx 4GiB 上限；持久化 getter 暗坑 | 按表名寻址 + `user_version` 标准迁移；无容量上限；无隐式列 |

> ⚠️ 外部调研代理对 FTS5 给出过「维持现状」的保守结论，但其前提是**Isar 继续当唯一真源、FTS5 只做外挂索引**（那样确实要付跨引擎双写一致性的代价）。本方案是整库迁移，正文就在 SQLite 里，该成本不存在——预分词 contentless FTS5 是干净的正解。

必须保留的只有：Rust jieba 分词（FTS5 内建 tokenizer 无中文分词）、双链的领域规则（自链/悬空边/linked-only 等，纯 Dart）、`DiaryContent` 派生、同步语义（墓碑/LWW/fromSync）、自建领域事件总线。

## 1. 依赖选型（核查结果，2026-08-27；同日追加 §1.5 的 drift 拍板）

- **`sqlite3: 3.5.2`**（simolus3）：同步 FFI 绑定。3.x 起**自带 `hook/build.dart` 走 Native Assets 编译打包 SQLite**——与 `moodiary_rust` 同一套基建，Flutter 3.47 已 stable。默认编译选项**启用 FTS5**、RTREE、math、session；带 SLSA L3 attestation + SBOM。
  - **不需要 `sqlite3_flutter_libs`**（0.6.0 起空壳/废弃）、**不需要 `sqlite3_native_assets`**（discontinued，能力已被 sqlite3 自身吸收）。
- **`sqlite3_connection_pool: 0.2.9`**（同作者）：Rust 库维护全局连接池 + Dart native-assets hook，异步调用短生命周期 isolate 执行、结果集移动不复制；`updatedTables` 池级广播流补上「update hook 只见本连接写」的 C API 硬限制。推荐形态：1 写连接 + N 只读连接（`query_only=1`），WAL。
  - **风险**：包只有 6 个月历史（2026-02 首 commit），仍在活跃迭代。对策见 §5：仓储只面向自家 `AppDatabase` 门面，池可替换。
- 版本按仓规**精确钉死**，不用 `^`。
- **两份 SQLite 共存警告**：将来若在 Rust 侧碰 SQLite（如自定义 tokenizer、sqlite-vec），**禁止** rusqlite `bundled`——必须 `libsqlite3-sys` 的 `loadable_extension` feature 走宿主函数表，否则注册到自己那份 SQLite 上（症状：看似成功但永不生效/段错误）。本期不需要。

### 1.5 类型安全层拍板：drift（typed_sql 出局，连带删掉 sqlite3_connection_pool）

用户授权引入类型安全 SQL 工具后的现查对比（2026-08-27）：

| | **drift 2.34.3 / drift_dev 2.34.5** | **typed_sql 0.1.13** |
|---|---|---|
| 依赖相容 | analyzer `[13.0,15.0)`∩build_runner 2.16 的 `≥13.3` ✓；`sqlite3: ^3.0.0` 与钉的 3.5.2 ✓；drift/drift_dev 必须成对升级 | **硬阻断**：`sqlite3: ^2.9.0` 与 3.5.2 在 pub 解析层互斥 |
| FTS5 | `.drift` 文件写原生 `CREATE VIRTUAL TABLE`；contentless（`content=''`）有 sqlparser 源码级支持、`contentless_delete=1` 静默透传；手动 rowid 插入有回归测试（#754）；bm25()/rank 一等类型推导。已知摩擦仅一条：`'delete-all'` 类命令语句在 `.drift` 里报虚假 lint（#3322，open）→ 放 Dart 侧 `customStatement` 即可 | 无虚表支持、无面向用户的裸 SQL 通道 |
| 连接注入 | 官方 backends API（DelegatedDatabase）可骑第三方池，但无现成参考、事务租约要自己抠；**自带 `NativeDatabase.createInBackground(readPool: N)` 就是「1 写 N 读 WAL 后台 isolate」**，与本设计同构 | 自带朴素池（硬编码 10 连接），不接受注入 |
| 迁移 | `schemaVersion` 就是 `PRAGMA user_version`；onCreate/onUpgrade 里跑手写 DDL 官方认可 | 自己不管迁移，官方示例外挂 Go 生态的 Atlas |
| 定位 | 10 年成熟度，与 sqlite3 同作者 | google/dart-neats 孵化仓，自述实验性、会破坏性变更，非官方产品 |

**结论**：drift，且用它的「`.drift` 文件手写 SQL + 生成器做类型推导」形态——schema DDL 与具名查询都写真 SQL（保住 §2 的全部设计），换来编译期的列名/类型/参数校验；Table DSL 与 stream query 不用（stream 不用无代价，领域事件总线保留）。

**连带决定：`sqlite3_connection_pool` 删除。** drift 走自带 executor 后它是冗余的第二套池，而它恰是整条依赖链里最年轻的（6 个月）；P0 对它的实测结论仍适用于 sqlite3 层本身（宿主 code asset、FTS5 能力、体积）。`AppDatabase` 门面被 drift 的 database 类取代。

**分层修订**：drift schema 认识全部领域词，SQLite 栈整体落在 **`moodiary_data`**（feature_base），storage 回归 KV-only——比原设计「DDL 在 models、执行在 storage」少一层注入；models 保持纯 freezed 域模型、零存储依赖。assistant（feature 层）经 moodiary_data 拿数据库句柄，与其仓储直连 Isar 的旧惯例同构。

## 2. 目标 schema

### 2.1 通用规则

- **统一 uuid v7 `TEXT PRIMARY KEY`，不再区分「业务主键 / 物理主键」**（2026-08-27 用户拍板：那个区分是 Isar 字符串主键性能差逼出来的，SQLite 没这个问题）。唯一的整数键残留是 `diaries.rid`（rowid 别名）：**FTS5 的行地址必须是整数 rowid**（引擎硬约束），它只做 FTS 胶水——不出仓储、不被任何子表引用。7 张 String 主键表在 Isar 侧从无唯一约束（唯一性只是 fastHash 覆盖写的副作用），SQLite 补上真约束。
- `DateTime` 一律 `INTEGER` 存 **UTC 微秒**（与 Isar 物理编码一致，迁移无损；UI 侧照旧 `toLocal()`；SQL 里按本地时间分桶要 `'unixepoch','localtime'` 换算或继续 Dart 分桶）。
- Isar 的 Int64 哨兵（`-2^63` = null）与 `double.nan`（`aspect` 的 null）**迁移读取时必须还原成真 `NULL`**。
- 6 处「持久化 getter 列」全部**不建列**，回归 Dart 计算：`Font.fontFamily/fontType`、`Category.level`、`LlmProvider.isPreset/protocol`、`SyncTombstone.isDiary/entityId`、`MediaInfo.mediaType`。
- fastHash / `isarId` **整体退休**（含「三表共享哈希空间」的隐式契约）。扩散面 15 个文件：事件改带业务 id（`DiaryEvent.deleted(String id)`），图谱节点、回收站多选、manager 页、压测 tile 跟随改。
- API Key 安全边界原样保留：`llm_providers` **无 api_key 列**，仍在 SecureKV（`llm_key_<id>`）。

### 2.2 diaries（核心表）

`position` / `weather` 现状是「定长 `List<String>` 元组、下标即字段」（`[纬度,经度,地名]`、`[图标码,温度,描述]`），3+ 处 UI 各自重复 `length >= 3` 防御解析。SQLite 侧**拆列**，「没有」从空数组变成 `NULL`：

```sql
CREATE TABLE diaries (
  rid           INTEGER PRIMARY KEY,   -- rowid 别名，FTS5 对齐用；不显式建列则 VACUUM 会挪 rowid
  id            TEXT NOT NULL UNIQUE,  -- uuid v7，业务主键
  category_id   TEXT,                  -- null = 未分类
  title         TEXT NOT NULL,
  content       TEXT NOT NULL,
  content_text  TEXT NOT NULL,
  time          INTEGER NOT NULL,      -- UTC micros
  last_modified INTEGER NOT NULL,
  show          INTEGER NOT NULL,      -- 回收站 = 0
  mood          REAL NOT NULL,
  type          TEXT NOT NULL,         -- markdown | richText | tiptap
  aspect        REAL,
  latitude      REAL,                  -- 三列同生同灭；旧 [lat,lng,name]
  longitude     REAL,
  place_name    TEXT,
  weather_icon  TEXT,                  -- 和风图标码；三列同生同灭
  weather_temp  TEXT,
  weather_text  TEXT
);
CREATE INDEX idx_diaries_show_time     ON diaries(show, time DESC, id DESC);
CREATE INDEX idx_diaries_show_cat_time ON diaries(show, category_id, time DESC, id DESC);
CREATE INDEX idx_diaries_show_lastmod  ON diaries(show, last_modified DESC, id DESC);
```

- Dart 模型同步升级成值对象：`DiaryPosition({lat, lng, name})?`、`DiaryWeather({icon, temp, text})?` 替换两个 `List<String>`。同步无历史兼容包袱，JSON 形状可以一起改；`markdown_writer` 的 frontmatter、地图页、两种卡片、详情页的下标解析全部换成字段访问。
- 排序第二键从 `isarId DESC` 换成 `id DESC`（uuid v7 按创建时刻有序）——**必须保留第二键**：`LoadMoreMixin` 的 offset 游标与 `applyDiaryEvent` 内存增量依赖「`ORDER BY` 与 Dart `Comparator` 逐字段一致」这条隐性契约，迁移测试要显式覆盖。
- 首页分页、月份计数（`GROUP BY`）、分类计数、回收站、日期区间全部变成索引查询 + SQL 聚合。

### 2.3 diaries 的三张子表（集合语义的字段）

`imageName/audioName/videoName`（正文派生缓存，序 = 正文出现序）与 `tags` 是真集合，拆子表；媒体库过滤与孤儿清理从全表扫描变成索引查询：

```sql
CREATE TABLE diary_media (
  diary_id  TEXT NOT NULL REFERENCES diaries(id) ON DELETE CASCADE,
  kind      TEXT NOT NULL,             -- image | audio | video
  seq       INTEGER NOT NULL,          -- 正文出现顺序
  file_name TEXT NOT NULL,
  PRIMARY KEY (diary_id, kind, seq)
);
CREATE INDEX idx_diary_media_kind ON diary_media(kind, diary_id);
CREATE INDEX idx_diary_media_file ON diary_media(file_name);

CREATE TABLE diary_tags (
  diary_id TEXT NOT NULL REFERENCES diaries(id) ON DELETE CASCADE,
  seq       INTEGER NOT NULL,
  tag       TEXT NOT NULL,
  PRIMARY KEY (diary_id, seq)
);
CREATE INDEX idx_diary_tags_tag ON diary_tags(tag);
```

- Dart 侧 `Diary` 模型的三个 `List<String>` 字段保留（仓储读时装配，页级批量 `WHERE diary_id IN (...)`，无 N+1）；`withDerivedMedia` 派生链与 `updateADiary` 的媒体一致性 assert 原样保留。
- `getMediaSourceDiaries(type:)` → `EXISTS` 子查询；`collectReferencedMedia()` → `SELECT DISTINCT file_name`（不再全库物化正文）；dashboard 标签数 → `COUNT(DISTINCT tag)`；顺带解锁将来的按标签筛选。

### 2.4 双链：diary_links（替 LinkPosting + snapshot.linkToIds 两张表）

```sql
CREATE TABLE diary_links (
  src_id TEXT NOT NULL REFERENCES diaries(id) ON DELETE CASCADE,
  dst_id TEXT NOT NULL,                -- 允许悬空（目标可能不存在/后创建），无外键
  PRIMARY KEY (src_id, dst_id)
);
CREATE INDEX idx_diary_links_dst ON diary_links(dst_id);
```

- 反链：`JOIN diaries s ON s.rid = src_rid WHERE dst_id = ? AND s.show = 1 ORDER BY s.time DESC`（过滤与排序下推，替掉 Dart 内存过滤）。
- `buildLinkGraph` 唯一的全表快照扫描 → 两列 JOIN，不再把全部词表载进内存。`buildEgoGraph` 保留 Dart BFS（每层一条 `IN` 查询）；自链丢弃、悬空边丢弃、`centerIndex==0` 排序契约、`maxNodes` 确定性截断等领域规则原样留在 Dart。

### 2.5 全文搜索：预分词 contentless FTS5

**方案 = Rust jieba 预分词 + `content='' , contentless_delete=1`**（外部调研矩阵的 B 方案；trigram 对中文是伪解——双字词 MATCH 直接零行，明确否决）：

```sql
CREATE VIRTUAL TABLE diary_fts USING fts5(
  title_tok,                            -- 标题 cut_for_search 分词，空格拼接
  body_tok,                             -- 正文 cut_for_search 分词，空格拼接
  content='', contentless_delete=1,     -- 3.43+；按 rowid 删，无需保留旧词文本
  tokenize='unicode61',
  prefix='2',                           -- 两字前缀索引；'3' 不值得
  detail=full,                          -- 短语/NEAR 是新增能力，不降档
  columnsize=1                          -- contentless 下 bm25 需要
);
INSERT INTO diary_fts(diary_fts, rank) VALUES('rank', 'bm25(1.5, 1.0)');  -- title 加权，替手写 BM25F
```

- **rowid = diaries.rid**，行 + FTS 同事务写（先 `await` 分词，再 `BEGIN`）。
- 索引侧 `cut_for_search`（高召回，含全词与子词），查询侧 `cut`（高精度）——jieba 的标准非对称用法，两组切分现成。**不再存双命名空间**（cut 0.5 权重那档的信息量由 FTS 的真实 TF/IDF 接管），索引体积减半。查询保持现状的 OR 召回语义（`"t1" OR "t2"`），`ORDER BY rank`（注意 bm25 越小越相关，升序）；同分 tie-break `time DESC`。
- **顺手修真缺陷**：Rust `tokenize_one` 末尾两个 `HashSet` 去重导致生产 TF 恒为 1（BM25 词频项退化成常数、测试替身与生产语义分叉）——去掉去重，FTS5 才能算出真实词频。
- **高亮继续自做**（Dart `indexOf` / 多词 Aho-Corasick）：contentless 表 `highlight()/snippet()` 恒 NULL，且这不是退化——现状同样拿不到 offset。顺手修大小写敏感与 stem 词形失配。
- 全量重建（`rebuildAllIndexes` / 词典升级后）：`INSERT INTO diary_fts(diary_fts) VALUES('delete-all')` + 批量分词重灌（`'rebuild'` 命令 contentless 不可用）。
- **退休名单**：SearchPosting、SearchStats、DiaryIndexSnapshot、ReindexQueue 四张表；`_applyIndexesBatch/_clearIndexesBatch/_mutateSearchPostings/_mutateLinkPostings/_snapshotSearchTf/_bumpStats` 全部 diff/幂等逻辑；`drainReindexQueue` 的四个触发点（启动兜底、详情页 dispose、同步收尾 `settleIndexes` 的 30% 阈值分支、rebuild 收尾条件清账）；`versionAtRead` 条件出队。编辑器自动保存直接 inline 索引（单篇分词毫秒级，FFI 本就不占 UI 线程）。
- 测试：分词仍在 Dart/Rust 侧外部完成，`installFakeRustLib(fakeTokenize)` 注入点**原样可用**，30+ 真库用例的替身策略不受影响；`db_benchmark_test.dart` 十个场景当迁移前后 A/B 基准（`docs/db-benchmark.md` 有 1k/5k/20k 对照数）。

### 2.6 其余各表

```sql
CREATE TABLE categories (
  id TEXT PRIMARY KEY, name TEXT NOT NULL,
  last_modified INTEGER NOT NULL, parent_id TEXT, color INTEGER
);

CREATE TABLE fonts (                    -- family 冲突覆盖的旧行为顺带修掉
  font_family TEXT PRIMARY KEY, font_file_name TEXT NOT NULL,
  wght_axis_json TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE tombstones (
  key TEXT PRIMARY KEY,                 -- 'd:<id>' | 'c:<id>' | 'm:<fileName>'
  time_ms INTEGER NOT NULL,             -- 保持毫秒（对应远端 manifest 的 t）
  pushed_backends_json TEXT NOT NULL DEFAULT '[]'
);
CREATE INDEX idx_tombstones_time ON tombstones(time_ms);   -- purgeExpired

CREATE TABLE media_infos (
  file_name TEXT PRIMARY KEY, name TEXT,
  duration_ms INTEGER, last_modified INTEGER NOT NULL
);

CREATE TABLE llm_providers (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
  base_url TEXT NOT NULL, default_model TEXT NOT NULL,
  created_at INTEGER NOT NULL, sort_order INTEGER NOT NULL,
  preset_id TEXT NOT NULL DEFAULT '',
  models_json TEXT NOT NULL DEFAULT '[]',
  tool_call INTEGER NOT NULL DEFAULT 0, reasoning INTEGER NOT NULL DEFAULT 0,
  attachment INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE chat_sessions (
  id TEXT PRIMARY KEY, title TEXT NOT NULL DEFAULT '',
  provider_id TEXT NOT NULL, model TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  reasoning_effort TEXT NOT NULL DEFAULT '',
  compacted_summary TEXT, compacted_up_to_message_id TEXT,
  compacted_at INTEGER, compacted_input_tokens_at_trigger INTEGER,
  agent_preset_id TEXT, persona_snapshot TEXT,
  tools_snapshot_json TEXT              -- NULL=不限 与 '[]'=全不挂 必须区分
);
CREATE INDEX idx_chat_sessions_updated ON chat_sessions(updated_at DESC);

CREATE TABLE chat_messages (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL
    REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL,
  reasoning TEXT, thinking_millis INTEGER, image_name TEXT,
  input_tokens INTEGER, output_tokens INTEGER, model TEXT
);
CREATE INDEX idx_chat_messages_session ON chat_messages(session_id, created_at);

CREATE TABLE assistant_tool_calls (     -- 原 @Embedded List，拆子表：done 流式翻转可单行 UPDATE
  message_id TEXT NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  seq INTEGER NOT NULL,                 -- 原 List 隐含顺序显式化
  call_id TEXT NOT NULL, name TEXT NOT NULL,
  args_json TEXT NOT NULL DEFAULT '',   -- 不透明 JSON 原样透传
  result TEXT NOT NULL DEFAULT '', done INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (message_id, seq)
);

CREATE TABLE memories (
  id TEXT PRIMARY KEY, category TEXT NOT NULL, text TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE agent_presets (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
  persona TEXT NOT NULL, tools_json TEXT,   -- NULL 与 '[]' 语义不同，同 tools_snapshot
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);
```

- 小集合字段（`toolsSnapshot/models/tools/pushedBackends/fontWghtAxisMap`）留 JSON 文本列——不参与查询、值域小，拆表是过度设计。**`NULL` vs `'[]'` 的语义区分要有测试钉住**。
- `deleteSession` 现状「先全表扫描拿消息 id 再批删」→ `ON DELETE CASCADE` 一句话；顺带解锁聊天消息分页（现状整会话一把梭，本期不改，索引已就位）。
- `MemoryEntry` 无向量字段（RAG 设计稿是未实现的未来方案），不预加 embedding 列；将来落地时另开关联表。

## 3. 并发模型与基建

- **`AppDatabase` 门面**（moodiary_storage，替 `IsarDatabase`）：开池（1 写 + N 读，`journal_mode=WAL`、`busy_timeout=5000`、`synchronous=NORMAL`、`foreign_keys=ON`、读连接 `query_only=1`）、执行注入的 DDL/迁移（`user_version` 版本化——storage 照旧不认识领域，DDL 真源放 `moodiary_models` 的 `schema.dart`，与 `moodiarySchemas` 注入哲学一致）、`clear()` 保持句柄有效（事务内逐表 `DELETE`，兜 `resetAllData` 的「句柄不失效」契约）。
- 依赖按 barrel 惯例由 storage 独家 own（`sqlite3` + `sqlite3_connection_pool` 不出现在 data/assistant 的 pubspec）；仓储只见 `AppDatabase` 的窄接口（`read/write/writeTransaction` 一类）。**池若不成熟，可在门面后换成「单写连接 + worker isolate」而不动 9 个仓储**。
- 事务：写走 writer lease 上手写 `BEGIN/COMMIT/ROLLBACK`（sqlite3 包无事务 API，`execute` 单语句）。**关键收益：分词等异步准备全部做完再开事务**，Isar 时代「事务回调必须同步 → 索引两段式」的结构性约束消失。
- **事件模型不变**：三条自建领域事件总线（携带 `fromSync`，Isar watcher 给不了）原样保留；助手侧「写后广播 + 全量重拉」原样保留。全仓唯一的 `watchObject`（详情页 `watchDiary`）改为订阅 `diaryEvents` 按 id 过滤——本就是唯一调用点。池的 `updatedTables` 流不启用（领域事件语义更强，避免双通知源）。
- 「事件驱动内存增量、不重查库」的三套补丁（`applyDiaryEvent` / `markMissedEvent` 补偿循环 / 200ms 去抖）动机（重查=全表扫描）消失，**本期原样保留**，将来可按需简化为直接重查。

## 4. 启动强制迁移（2.8.0 门内新增「引擎搬迁」阶段）

现有闸门是两套：`VersionMigrator`（版本号触发，try/catch 吞错重试）与 `/migration` 强制页（实时查询触发，redirect 拦截）。引擎搬迁**放进强制页，作为正文格式转换之前的新阶段**——它必须收敛才能继续用 App，性质与正文迁移一致，且需要进度 UI 与重试按钮：

**判据**（持久化，非内存标记）：`AppFiles` 下存在旧 `default.isar` 且 KV `dbEngineMigrated` 未置位（`EngineMigrationService.refresh()` 在 KV 就绪后探测）→ router redirect 到 `/migration`（放行名单不变：锁屏 + 迁移页自身）。全新安装两个条件都不满足，直接建空 SQLite，零开销。

**执行序**（P3 落地时对原稿的一处修订：**不走 tmp + rename**——`moodiary.db` 在启动期已被 drift 后台 isolate 打开，rename 覆盖打开中的文件后旧句柄仍指旧 inode，是静默坑。原子性改由「KV 标记只在对账通过后置位，未置位即整库重来」承担，旧 Isar 全程只读的零损失保证不变）：
1. `VersionMigrator` 既有 6 档照跑（把旧库规整到 2.8.0 的 Isar 形状；2.7.3 快照备份 `default.isar.v273bak` 先例保留）。
2. 迁移页阶段一「存储引擎搬迁」（`EngineMigrationService.migrate`，moodiary_migration）：
   - 以 **legacy `moodiarySchemas` 固定顺序**只读打开旧 Isar（⚠️ 顺序即地址，读侧也不能挑子集或重排；isar 解码层已把 Int64/NaN 哨兵透明还原为 null，无需手工处理）；
   - `clearAll()` 起步 → 分批（256）拷入**已打开的** SQLite：日记走 `insertDiaries(fromSync: true)`（行 + 子表 + FTS + 双链同事务，分词整批过桥；事件带 fromSync，watcher 不标脏）；position/weather 转值对象（`double.tryParse` 失败只丢定位并计数）；助手五张表 migration 够不着 feature 层仓储，直接走 drift 伴生类（会话→消息→工具调用的外键序；悬挂消息跳过并计数）；墓碑最后搬（防复活闸门误清）；
   - **对账**：逐表行数（消息按「跳过悬挂后应到」计），不平抛错、标记不置位；
   - `finalizeMigration()`：置 `dbEngineMigrated` + `searchIndexBackfilled`（FTS 已建满，升级用户不再看到重建提示）→ 旧库改名 `default.isar.pre-sqlite.bak`（改名失败不阻断，重置数据兜底清理）。
3. 阶段二 = 既有正文格式迁移（`hasLegacyFormatDiaries` 此时查的已是 SQLite），语义不动；页面完成阶段一后重新探测再进入阶段二。
4. `AutoSyncWatcher.start()` 照旧排在全部迁移之后（迁移写入不回声推云端）。

**失败兜底**：旧库全程只读，任何一步失败数据零损失；页面失败态 + 重试按钮（同正文迁移）。`resetAllData` 清单追加：`moodiary.db`（`clear()` 语义）、`moodiary.db.tmp`、`default.isar.pre-sqlite.bak`。备份 zip 旧格式检测（stat `database/default.isar`）不受影响；`errLegacyBackup` 照旧。

## 5. 分层与依赖收缩

改动面严格锁在 5 个包（presentation 层零 Isar 依赖已核实）：

| 包 | 动作 |
|---|---|
| `moodiary_storage` | `IsarDatabase` → `AppDatabase`；独家 own `sqlite3`/`sqlite3_connection_pool` |
| `moodiary_models` | 全部 `@Collection`/`@Id`/`@Index`/`@Embedded` 注解与 `.g.dart` 删除，回归纯 freezed；`schemas.dart` → `schema.dart`（DDL + user_version 迁移表）；`schema_order_test` 退休；新增 `DiaryPosition`/`DiaryWeather` 值对象 |
| `moodiary_data` | 5 个仓储改 SQL；搜索/双链引擎按 §2.5/2.4 重写（预计净删千行级）；死代码 `getDiaryByID`/`getAllDiariesSorted` 不翻译 |
| `moodiary_assistant` | 4 个仓储改 SQL（`data/` 子目录，公开签名不变，presentation 零改动） |
| `moodiary_migration` | **isar_plus 的最后据点**：只读旧库的搬迁器 + 既有 6 档 + 孤儿清理；迁移窗口期过后整包依赖可删 |

`moodiary_sync` 零改动（四个窄端口 Store 全部转发仓储，已核实零 isar import）；备份/LAN/导出链路零改动。`tool/check_layers.dart` 不需要动（isar_plus 是第三方包，本就不在闸门视野）。

## 6. 风险与 spike 清单（P0 实测结果，2026-08-27）

前三项已在宿主（macOS，`flutter test`）实测通过，探针测试保留在 `packages/core/moodiary_storage/test/sqlite_{spike,pool_spike,app_database}_test.dart`：

1. **`sqlite3_connection_pool` 行为** ✅：`ConnectionLease.select/execute` 源码级确认走 `Isolate.run` 短生命周期 isolate（指针传址）；实测 200ms 重查询期间主 isolate 事件循环最大停顿 ~12ms（10ms 定时器基本无漂移）——**不卡 UI**。悬挂事务（lease 未 COMMIT 直接归还）自动回滚、池不卡死；`exclusiveAccess` + `user_version` 迁移可用；`query_only` 读连接拒写；WAL 下未提交写对读者不可见；`updatedTables` 跨连接聚合通知正常；FTS5 经池可用。门面隔离仍是硬要求（包只有 6 个月历史）。
2. **宿主测试拿库** ✅：`flutter test` 直接构建并加载 code asset，**零配置**——bundled SQLite 3.53.4（≥3.43，`contentless_delete` 可用），`ENABLE_FTS5` 编译确认。contentless FTS5 全链路（`prefix='2'`/`detail=full`/短语/bm25 列加权/真实词频/按 rowid 删/`delete-all`）全部通过。无需系统库回退；ISAR_TEST_DYLIB 之痛只剩迁移测试要背。
3. **体积（实测，量的是 GH Release 上将被 hook 下载进包的那份产物）**：
   | 库 | arm64 原始 | arm64 strip 后 | gzip 后（≈压缩 APK 内） |
   |---|---|---|---|
   | libsqlite3.so（3.5.2，默认下载的预编译产物） | 1789 KiB | 1692 KiB | ~842 KiB |
   | libsqlite3_connection_pool.so（0.2.9 预编译） | 43 KiB | — | ~21 KiB |
   | libisar_plus.so（1.3.9，对照） | 6134 KiB | — | — |

   **账要分两段**：2.8.0 迁移窗口期 isar_plus_flutter_libs 必须保留（读旧库的唯一途径），双引擎并存，**净增 ~1.7 MiB/ABI**（用户已确认可接受）；后续版本删掉 isar 依赖后**净省 ~4.3 MiB/ABI**。armv7 1829 KiB / x86_64 1766 KiB / iOS arm64 1630 KiB 同量级。
4. **BM25 语义偏移**（待真机验收）：FTS5 固定 k1=1.2/b=0.75、按词数归一（现状 b=0.4、按字符数）——排序会有可感知变化，验收时人工对比一轮检索质量，接受即止损（不建议为还原旧口径自算打分）。
5. **迁移压测**（待 P3）：用 `stress_test_tile` 灌 20k 假库走一遍完整搬迁，对 `docs/db-benchmark.md` 基线跑 A/B。
6. **stash 里的 server-mode 客户端**（`stash@{0}`）建在 Isar mirror 表上，rebase 时同步引擎侧要跟着换表——排期时记入，不是本期工作。
7. **真机验证** ✅（2026-08-27，Android 16 / arm64 实测）：moodiary_rust + sqlite3 双 native-assets hook 真实构建共存、启动零异常；`moodiary.db` WAL 模式、`user_version=1`、14 表 + FTS 虚表 + rank 配置全就位；端到端：真 jieba 分词落 FTS（词典可见「苹果/好吃/双链…」）、`MATCH` 命中 + 标题 1.5 权重排序正确（bm25 −1.112 vs −0.875）、编辑器双链落 `diary_links`。**迁移升级路径（旧 Isar → 强制页两阶段）真机验证仍待做**（用户拍板先验新逻辑；设备上留有 20MB 真实旧库的 beta.debug 包可作素材）。

## 7. 实施分期

1. **P0 spike** ✅（2026-08-27）：§6 的 1/2/3 三项实测通过；`AppDatabase` 空壳落地（`moodiary_storage/lib/src/sqlite.dart`：openAsync 开池、注入式 `SqliteMigration` + `user_version` 逐档原子迁移、`BEGIN IMMEDIATE` 写事务、领域无关的保句柄 `clear()`——FTS 虚表走 `delete-all`、影子表跳过）；storage 包 38 用例全绿、全仓 analyze 干净。剩真机构建验证（§6.7）。
2. **P1 核心** ✅（2026-08-27，P2 与大部分 P4 因 models 联动被一并拉入）：
   - models 去 Isar 化（纯 freezed + `DiaryPosition`/`DiaryWeather` 值对象）；旧 15 张 collection 逐字节冻结进 `moodiary_migration/lib/src/legacy/`（isar_plus 唯一据点，连 isar_plus_flutter_libs 都已随迁），带 legacy schema 顺序闸门测试
   - `moodiary_data` 落 drift 全栈：`src/db/schema.drift`（14 表 + contentless FTS5）+ `diary.drift` 具名查询 + `MoodiaryDatabase`（createInBackground readPool=3、WAL/FK pragmas、user_version 迁移、保句柄 clearAll）；9 个仓储（5 data + 4 assistant）全部改写，公开签名不变
   - 搜索/双链引擎按 §2.5/2.4 重写：净删 ~800 行 diff/幂等/BM25 代码，ReindexQueue 及四个排空触发点（bootstrap/详情页 dispose/sync settleIndexes/rebuild 收尾）全部退休；IndexMode 收敛为 {inline, skip}
   - Rust 分词 HashSet 去重已删（真实 TF），text crate 11/11 + clippy 干净
   - isarId/fastHash 全仓退休；事件改业务 id；`watchDiary` 换事件流过滤；排序第二键 = id（uuid v7）
   - 新测试：`diary_repository_test`（30 用例：FTS 检索/词频/标题权重/过滤/双链/图谱/墓碑/分页对齐/修复）+ `small_repositories_test`（5 用例）+ FTS5 能力闸门；**全仓 analyze + 层检查 + `task.dart test` 全绿**；SQLite 用例零 dylib 门槛
   - 两处 drift 实战坑已记档：`key` 是 SQL 关键字会被**静默吞列**（必须 `"key"`）；列名撞 `Table` 基类成员（`text`）编译炸（memories 正文列改名 `content`）
3. **P3 搬迁** ✅（2026-08-27）：`EngineMigrationService`（migrate + finalizeMigration，测试可注入内存库与 forTesting 仓储）+ 强制页双阶段（引擎搬迁 → 正文格式，进度共用一条 UI，i18n 新增 migrationEngineStage）+ router 双闸 + `dbEngineMigrated` KV + resetAllData 清 .bak。真库测试 3 用例全绿（全实体+值转换+对账 / 可重入 / fromSync 零本地事件；macOS dylib 从 GH release `isar_plus_core.xcframework.zip` 取 macos 切片改名即用）。**20k 压测**（宿主 M 系，替身分词，正文 120 词合成句）：搬迁全程含 FTS+双链 **4.8s**，首页分页 2ms（深分页 <1ms）、搜索 top50 21ms、月份统计 47ms、整库 49MiB——旧引擎同量级对照：仅重建索引 8.1s、高频搜索 111ms、数据+索引 ≈400MB（正文更长，体积对比打折看，量级差是结构性的）。压测入口 `MOODIARY_BENCH_N=20000 fvm flutter test test/engine_migration_benchmark_test.dart`。
4. **P4 残余**：`docs/db-benchmark.md` 基准重写（用真机 + 真 jieba 重测）、**升级路径真机验证**（强制页两阶段：可用设备上 beta.debug 的真实旧库）、`server-mode` stash rebase 时换表。新逻辑真机验证已完成（§6.7）。
