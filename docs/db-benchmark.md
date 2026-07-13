# 数据库性能基准(2.8.0 posting-list 倒排 + BM25)

> 2026-07-13 · 分支 `refactor/2.8.0/new_arch` · Apple M4 Pro / macOS 26.5.1 / isar_plus 1.3.7(native 引擎)
> 测量对象为真实 `DiaryRepository` 代码路径(经 `forTesting` 注入独立 Isar 与替身分词器)。
> 绝对值为桌面级 CPU,手机上会更慢;**随规模的增长曲线**才是设计关注点。

## TL;DR

| 场景 | 1 千篇 | 2 万篇 | 随规模增长? |
|---|---|---|---|
| 自动保存(编辑期,2s 去抖) | 0.4ms | 0.4ms | **恒定** |
| 搜索(3 个中低频词,BM25 端到端) | 2.1ms | 10.6ms | 仅随命中数 O(df) |
| 反链查询 | 0.3ms | 0.2ms | **恒定** |
| 按业务 id 取日记 | 0.13ms | 0.29ms | **恒定** |
| 关闭编辑器重索引(整篇改写) | 7.9ms | 54ms | 随命中词 df 增长 |
| 全库批量导入(`insertDiaries`) | 0.4s | 22.7s | 线性(约 1.1ms/篇) |
| 全量重建索引(数据修复) | 0.4s | 8.1s | 线性 |

结论:**日常交互路径(保存/搜索/反链/取日记)全部与库规模脱钩或只随命中数增长**;
重量级操作(导入/重建)为线性且落在秒级。2 万篇 ≈ 每天一篇写 55 年。

## 背景:为什么是 posting-list

实测证实 isar_plus 1.3.7 native 引擎的**读查询从不使用二级索引**——`@Index(hash: true)`
等值、`@Index()` 值索引等值、无索引等值三者耗时相同且随集合行数线性增长(160 万行时均
约 25–33ms);只有 `@Id` 主键 `get` 恒定约 0.12ms。而 `@Index` 在写入时仍要维护,是纯
写放大。因此「加索引」不可行,高频查询必须**以主键组织**:

- `SearchPosting`:`key = fastHash('{cut|cutForSearch|title}:词')` → 含该词的日记
  isarId 列表 + 平行词频数组(BM25 的 TF;行长即 DF)。标题作为第三命名空间进倒排
  (细粒度分词),搜索管线里没有任何全表扫描。
- `LinkPosting`:`key = fastHash(目标业务 id)` → 链接到它的源日记 isarId 列表
- `DiaryIndexSnapshot`:`key = diaryIsarId` → 该篇已入倒排的分词 + 词频 + 标题 + 双链
  快照。增删改一律按快照 diff 只触碰受影响的 posting 行(词频变化也视为变更,幂等);
  批量路径(`insertDiaries` / `deleteDiariesByIsarIds`)把整批变更按键聚合,同一行每批
  只读写一次。
- `SearchStats`:统计单例(N、正文非空篇数、正文总字符),与倒排同事务增量维护,供
  IDF 与 avgdl(avgdl 只对正文非空的日记平均,纯媒体日记不摊薄均长)。
- 不变量:**已索引 ⇔ 日记存在且未删(墓碑不入倒排)**,增量路径(insert/update/软删/
  硬删/同步 tombstone)与全量重建遵循同一规则。

**相关性打分(BM25 字段加权)**:`score = Σ 源权重 × IDF × TF·(k1+1)/(TF + k1·norm)`,
k1=1.2;正文精确源(cut)×1.0、正文细粒度源(cutForSearch)×0.5、标题源 ×1.5;正文源按
contentText 字符数做长度归一(b=0.4,|d| 取自候选集物化后的对象,零额外读),标题源不
归一。IDF 用 `ln(1+(N−df+0.5)/(df+0.5))`,词频缺失按 1 容错(升级期自愈)。

同批落地:`Diary` 删除零查询使用的 `yM`/`yMd` 索引(写入快约一倍);`maxSizeMiB`
128 → 4096(mdbx 硬上限,虚拟映射不占磁盘);`getDiaryByBusinessId` 改
`getAsync(fastHash(id))`;编辑器 skip/defer 判定纳入标题(标题变更也会重索引)。

## 方法论

- 数据形状:每篇 contentText 为 135 个按偏斜分布(Zipf 近似,词表 6000)采样的词,
  去重后经 cut + cutForSearch 双源共约 220 个 posting 键/篇,对应约 2000 字日记的
  分词量级;每篇正文含 2 个随机双链;分词器为空白切词替身(**不含真实 jieba 分词的
  Rust FFI 耗时**,导入/重建的线上耗时会高于表中值)。
- 计时:交互场景取 12–30 次的 median 与 p90;一次性操作(导入/排空/重建/批删)计总时长。
- 复现:见文末。基准代码在 `packages/core/moodiary_data/test/db_benchmark_test.dart`。

## 完整结果

median(p90),单位 ms;一次性操作为总时长。

| 场景 | 1,000 篇 | 5,000 篇 | 20,000 篇 |
|---|---|---|---|
| 批量导入全库(`insertDiaries`,500/块) | 429 | 2,633 | 22,667 |
| 自动保存 defer(`updateADiary`) | 0.36 (0.51) | 0.34 (0.59) | 0.39 (0.79) |
| 单篇重索引(`reindexDiary`,整篇换词) | 7.9 (15.5) | 19.5 (21.0) | 54.1 (62.2) |
| 启动排空 18 篇积压(`drainReindexQueue`) | 151 | 341 | 1,088 |
| 搜索 3 个中低频词(BM25 端到端) | 2.1 (2.4) | 3.3 (4.0) | 10.6 (11.2) |
| 搜索含 1 个高频词(命中约半库) | 6.7 (8.8) | 28.0 (29.3) | 110.9 (131.0) |
| 反链(`getBacklinks`) | 0.25 (0.30) | 0.28 (0.33) | 0.23 (0.32) |
| 首页分页 40 条(`getDiaryByCategory`) | 0.45 (0.48) | 1.0 (1.1) | 5.6 (8.4) |
| 按业务 id(`getDiaryByBusinessId`) | 0.13 (0.15) | 0.13 (0.16) | 0.29 (0.80) |
| 满库单篇插入(`insertADiary`) | 5.7 (6.3) | 11.9 (13.1) | 38.2 (41.5) |
| 批量硬删 100 篇(tombstone 路径) | 81 | 194 | 756 |
| 全量重建(`rebuildAllIndexes`,数据修复) | 411 | 1,452 | 8,101 |

磁盘占用(`getSize(includeIndexes: true)`):

| 集合 | 1,000 篇 | 5,000 篇 | 20,000 篇 |
|---|---|---|---|
| Diary 本体¹ | 6.2 MB | 29.8 MB | 118.8 MB |
| SearchPosting(含词频数组) | 6.6 MB | 33.3 MB | 127.3 MB |
| LinkPosting | 0.1 MB | 0.3 MB | 1.0 MB |
| DiaryIndexSnapshot | 7.8 MB | 39.1 MB | 156.5 MB |
| **索引侧合计** | **14.5 MB** | **72.7 MB** | **284.8 MB** |

¹ 合成正文约 1.4KB/篇;真实 2000 字日记的 Diary 本体约为表中 3–4 倍,索引侧不受影响。

**BM25 + 标题倒排的写路径代价**(相对无词频版本,@20k):重索引 35→54ms、单篇插入
26→38ms、导入 16.5→22.7s、posting 磁盘约翻倍——换来搜索端到端 17.3→10.6ms(消灭
标题全表扫描)与真正的相关性排序。写路径全部在后台 isolate,不阻塞 UI。

## 与旧实现(行式倒排 + 计数加权)对比

旧实现数据来自同分布的镜像基准(逐行 `DiarySearchIndex`,`@Index(hash)` token,查询走
`where().tokenEqualTo` + `titleContains` 全表扫描)。口径差异:旧搜索值仅含倒排查询部
分,新值为端到端(BM25 + 标题命名空间 + 结果物化),对比对旧实现有利,实际差距更大。

| 场景 | 旧(1k / 5k / 20k) | 新(1k / 5k / 20k) | 20k 提升 |
|---|---|---|---|
| 搜索 3 词 | 34.8 / 172.6 / 687.7 ms | 2.1 / 3.3 / 10.6 ms | **约 65×** |
| 单篇重索引 | 10.9 / 32.0 / 98.5 ms | 7.9 / 19.5 / 54.1 ms | 约 1.8× |
| 自动保存 defer | 0.57 / 0.61 / – ms | 0.36 / 0.34 / 0.39 ms | 约 1.6×(删 yM/yMd) |
| 按业务 id | 0.14 / 0.38 / 线性 ms | 0.13 / 0.13 / 0.29 ms | 恒定化 |
| 顺序导入 8 千篇(含共享高频词)² | 约 41 s | 0.73 s(无词频版) | **约 56×** |
| 索引磁盘 @5k | 101.5 MB | 72.7 MB | 约 1.4× |

² 审查阶段实测:逐篇 `insertADiary` 对高频词 posting 行有 O(N²) 整行重写,由批量聚合
入口 `insertDiaries` 消除。JSON 本地导入导出功能因不完善(不含媒体资源)已整体移除,
`insertDiaries` 作为批量入口保留(真库测试覆盖,供未来恢复/局域网同步等场景);云同步
保持逐篇(网络耗时占绝对主导,每篇 50–300ms vs 写入约 12ms,且引擎的 LWW/媒体语义
不宜为此重构)。

另:128MiB 的旧默认容量上限在 5 千篇时(旧索引 101.5MB + 日记本体)已接近爆库;现上限
4096MiB,2 万篇总占用约 400MB(真实正文更长时约 700MB),余量充足。

## 已知边界与后续方向

1. **含高频词的查询**(命中约半库):耗时随命中篇数线性(20k 时约 111ms),主要是
   命中集物化与 BM25 打分,旧实现同样存在且更慢。若成为痛点,可在查询侧跳过 df 超阈
   值的词(它们 IDF 趋近 0、几乎不贡献排序),或对 posting 行做 df 截断。
2. **中低频词搜索随命中数增长**(O(df),20k 时 10.6ms):这是「返回更多结果」的固有
   成本,单结果成本恒定,不是库规模问题。
3. **标题匹配语义变化**:标题从 `titleContains` 子串匹配改为分词等值匹配(与正文一致)。
   单字部分词查询(如「苹」搜「苹果日记」)不再命中标题——正文侧从来如此,如需恢复可
   给标题加 n-gram 命名空间。
4. **单篇插入/重索引随规模缓增**(20k 时 38/54ms):新篇的每个词都要整行重写对应
   posting(含词频数组),高频词行大。均为后台低频操作,当前不值得优化。
5. **快照体积**:`DiaryIndexSnapshot` 20k 时 156MB,大头是 isar `List<String>`/`List<int>`
   的逐元素开销(约 3 倍放大)。把词表拼接为单 `String` 实测省约 50% 且信息无损;
   改存 64 位哈希键并不更小(中文词串比 8B int 短)且丢失重算能力。体积成为问题时做
   拼接编码,schema 变更走一次 `rebuildAllIndexes` 兜底。
6. 表中不含真实 jieba 分词(Rust FFI)耗时:导入/重建的线上总时长以分词为主,但那部分
   与索引设计无关且新旧一致。

## 复现

```bash
# 1. 取 libisar_plus 动态库(macOS,与 pubspec 中 isar_plus 版本一致)
curl -LO https://github.com/ahmtydn/isar_plus/releases/download/v1.3.7/isar_plus_core.xcframework.zip
unzip isar_plus_core.xcframework.zip
lipo isar_plus_core.xcframework/macos-arm64_x86_64/libisar_plus.a -thin arm64 -output libisar_arm64.a
clang -dynamiclib -arch arm64 -o libisar_plus.dylib -Wl,-all_load libisar_arm64.a \
  -framework Security -framework CoreFoundation -lc++

# 2. 跑基准(约 1 分钟;RUN_DB_BENCH 不设则自动跳过,不影响 CI)
cd packages/core/moodiary_data
ISAR_TEST_DYLIB=/absolute/path/libisar_plus.dylib RUN_DB_BENCH=1 \
  fvm flutter test test/db_benchmark_test.dart

# 3. 功能正确性测试(同一动态库)
ISAR_TEST_DYLIB=/absolute/path/libisar_plus.dylib fvm flutter test test/diary_index_test.dart
```
