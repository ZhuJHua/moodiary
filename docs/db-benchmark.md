# 数据库性能基准(2.8.0 posting-list 倒排)

> 2026-07-13 · 分支 `refactor/2.8.0/new_arch` · Apple M4 Pro / macOS 26.5.1 / isar_plus 1.3.7(native 引擎)
> 测量对象为真实 `DiaryRepository` 代码路径(经 `forTesting` 注入独立 Isar 与替身分词器)。
> 绝对值为桌面级 CPU,手机上会更慢;**随规模的增长曲线**才是设计关注点。

## TL;DR

| 场景 | 1 千篇 | 2 万篇 | 随规模增长? |
|---|---|---|---|
| 自动保存(编辑期,2s 去抖) | 0.4ms | 0.3ms | **恒定** |
| 搜索(3 个中低频词,端到端) | 2.2ms | 17ms | 仅标题扫描线性 |
| 反链查询 | 0.3ms | 0.3ms | **恒定** |
| 按业务 id 取日记 | 0.14ms | 0.15ms | **恒定** |
| 关闭编辑器重索引(整篇改写) | 5.9ms | 35ms | 随命中词 df 增长 |
| 全库导入(JSON 恢复) | 0.4s | 16.5s | 线性(约 0.8ms/篇) |
| 全量重建索引(数据修复) | 0.2s | 4.7s | 线性 |

结论:**日常交互路径(保存/搜索/反链/取日记)全部与库规模脱钩或近似脱钩**;重量级操作
(导入/重建)为线性且落在秒级。2 万篇 ≈ 每天一篇写 55 年。

## 背景:为什么是 posting-list

实测证实 isar_plus 1.3.7 native 引擎的**读查询从不使用二级索引**——`@Index(hash: true)`
等值、`@Index()` 值索引等值、无索引等值三者耗时相同且随集合行数线性增长(160 万行时均
约 25–33ms);只有 `@Id` 主键 `get` 恒定约 0.12ms。而 `@Index` 在写入时仍要维护,是纯
写放大。因此「加索引」不可行,高频查询必须**以主键组织**:

- `SearchPosting`:`key = fastHash('{cut|cutForSearch}:词')` → 含该词的日记 isarId 列表
- `LinkPosting`:`key = fastHash(目标业务 id)` → 链接到它的源日记 isarId 列表
- `DiaryIndexSnapshot`:`key = diaryIsarId` → 该篇已入倒排的分词/双链快照,增删改一律
  按快照 diff 只触碰受影响的 posting 行(幂等);批量路径(`insertDiaries` /
  `deleteDiariesByIsarIds`)把整批变更按键聚合,同一行每批只读写一次

同批落地:`Diary` 删除零查询使用的 `yM`/`yMd` 索引(写入快约一倍);`maxSizeMiB`
128 → 4096(mdbx 硬上限,虚拟映射不占磁盘);`getDiaryByBusinessId` 改
`getAsync(fastHash(id))`。

## 方法论

- 数据形状:每篇 contentText 为 135 个按偏斜分布(Zipf 近似,词表 6000)采样的词,
  去重后经 cut + cutForSearch 双源共约 220 个 posting 键/篇,对应约 2000 字日记的
  分词量级;每篇正文含 2 个随机双链;分词器为空白切词替身(**不含真实 jieba 分词的
  Rust FFI 耗时**,导入/重建的线上耗时会高于表中值)。
- 计时:交互场景取 12–30 次的 median 与 p90;一次性操作(导入/排空/重建/批删)计总时长。
- 复现:见文末。基准代码在 `packages/core/moodiary_data/test/db_benchmark_test.dart`。

## 完整结果(新实现)

median(p90),单位 ms;一次性操作为总时长。

| 场景 | 1,000 篇 | 5,000 篇 | 20,000 篇 |
|---|---|---|---|
| 批量导入全库(`insertDiaries`,500/块) | 374 | 1,936 | 16,538 |
| 自动保存 defer(`updateADiary`) | 0.43 (0.62) | 0.38 (0.71) | 0.31 (0.64) |
| 单篇重索引(`reindexDiary`,整篇换词) | 5.9 (6.9) | 15.9 (16.8) | 34.7 (37.1) |
| 启动排空 18 篇积压(`drainReindexQueue`) | 108 | 319 | 743 |
| 搜索 3 个中低频词(`searchDiaries` 端到端) | 2.2 (3.1) | 4.7 (5.4) | 17.3 (21.5) |
| 搜索含 1 个高频词(命中约半库) | 5.9 (8.4) | 27.9 (31.8) | 102 (107) |
| 反链(`getBacklinks`) | 0.30 (0.41) | 0.32 (0.40) | 0.29 (0.34) |
| 首页分页 40 条(`getDiaryByCategory`) | 0.44 (0.70) | 1.1 (1.4) | 4.2 (5.0) |
| 按业务 id(`getDiaryByBusinessId`) | 0.14 (0.20) | 0.14 (0.23) | 0.15 (0.18) |
| 满库单篇插入(`insertADiary`) | 4.9 (5.4) | 10.3 (11.3) | 26.0 (29.7) |
| 批量硬删 100 篇(tombstone 路径) | 59 | 156 | 470 |
| 全量重建(`rebuildAllIndexes`,数据修复) | 204 | 964 | 4,708 |

磁盘占用(`getSize(includeIndexes: true)`):

| 集合 | 1,000 篇 | 5,000 篇 | 20,000 篇 |
|---|---|---|---|
| Diary 本体¹ | 6.2 MB | 29.8 MB | 118.8 MB |
| SearchPosting | 3.5 MB | 16.1 MB | 64.9 MB |
| LinkPosting | 0.1 MB | 0.3 MB | 1.0 MB |
| DiaryIndexSnapshot | 5.2 MB | 26.1 MB | 104.3 MB |
| **索引侧合计** | **8.8 MB** | **42.5 MB** | **170.2 MB** |

¹ 合成正文约 1.4KB/篇;真实 2000 字日记的 Diary 本体约为表中 3–4 倍,索引侧不受影响。

## 与旧实现(行式倒排)对比

旧实现数据来自同分布的镜像基准(逐行 `DiarySearchIndex`,`@Index(hash)` token,查询走
`where().tokenEqualTo`)。口径差异:旧搜索值仅含倒排查询部分,新值为端到端(含标题扫描
与结果物化),对比对旧实现有利,实际差距更大。

| 场景 | 旧(1k / 5k / 20k) | 新(1k / 5k / 20k) | 20k 提升 |
|---|---|---|---|
| 搜索 3 词 | 34.8 / 172.6 / 687.7 ms | 2.2 / 4.7 / 17.3 ms | **约 40×** |
| 单篇重索引 | 10.9 / 32.0 / 98.5 ms | 5.9 / 15.9 / 34.7 ms | 约 2.8× |
| 自动保存 defer | 0.57 / 0.61 / – ms | 0.43 / 0.38 / 0.31 ms | 约 2×(删 yM/yMd) |
| 按业务 id | 0.14 / 0.38 / 线性 ms | 0.14 / 0.14 / 0.15 ms | 恒定化 |
| 顺序导入 8 千篇(含共享高频词)² | 约 41 s | 0.73 s | **约 56×** |
| 索引磁盘 @5k | 101.5 MB | 42.5 MB | 约 2.4× |

² 审查阶段实测:逐篇 `insertADiary` 对高频词 posting 行有 O(N²) 整行重写,由批量聚合
入口 `insertDiaries` 消除;JSON 导入已切换,云同步保持逐篇(网络耗时占绝对主导,每篇
50–300ms vs 写入约 7ms,且引擎的 LWW/媒体语义不宜为此重构)。

另:128MiB 的旧默认容量上限在 5 千篇时(旧索引 101.5MB + 日记本体)已接近爆库;现上限
4096MiB,2 万篇总占用约 290MB(真实正文更长时约 600MB),余量充足。

## 已知边界与后续方向

1. **含高频词的查询**(命中约半库):耗时随命中篇数线性(20k 时约 102ms),主要是
   命中集物化与排序,旧实现同样存在且更慢。若成为痛点,可在查询侧跳过 df 超阈值的词,
   或对 posting 行做 df 截断(牺牲极高频词的召回,它们本身几乎无区分度)。
2. **标题匹配**:`titleContains` 仍是全表扫描(每查询词一次),是「中低频词搜索」里
   唯一的线性分量(20k 时约占 12ms)。可改为一次标题投影扫描 + 内存多词匹配。
3. **单篇插入**随规模缓慢增长(20k 时 26ms):新篇的每个词都要整行重写对应 posting,
   高频词行大。单篇插入是低频操作(手写新日记),当前不值得优化。
4. **快照体积**:`DiaryIndexSnapshot` 存原始词串(20k 时 104MB),若改存 64 位键值
   (`List<int>`)可省约 75%,代价是丢失可读性与重算灵活性。体积成为问题时再做。
5. 表中不含真实 jieba 分词(Rust FFI)耗时:导入/重建的线上总时长以分词为主,但那部分
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
