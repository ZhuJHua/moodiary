import 'dart:io';

import 'package:drift/drift.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 2.8.0 引擎搬迁：旧 Isar 全库 → SQLite（drift）。启动强制迁移页的阶段一，
/// 排在正文格式迁移（EditorMigrationService）之前。
///
/// 原子性与可重入（**不走 tmp + rename**——moodiary.db 在启动期已被 drift 的
/// 后台 isolate 打开，rename 覆盖打开中的文件后旧句柄仍指向旧 inode，是静默坑）：
/// - 旧 Isar 全程只读，任何一步失败数据零损失；
/// - 新库以 [MoodiaryDatabase.clearAll] 起步、分批事务拷入；[MoodiaryKVs.dbEngineMigrated]
///   只在逐表对账通过后置位——中途被杀，下次启动标记仍未置位，整库重来（幂等）；
/// - 搬迁成功后旧库改名 `default.isar.pre-sqlite.bak` 留底（重置数据时删除）。
///
/// FTS 与双链索引在拷贝时经 [DiaryRepository.insertDiaries] 内联建成（分词批量
/// 过桥），无需单独回填；事件带 `fromSync`，AutoSyncWatcher 不会把搬迁当本地变更。
class EngineMigrationService {
  const EngineMigrationService._();

  static const String legacyFileName = 'default.isar';
  static const String legacyBackupFileName = 'default.isar.pre-sqlite.bak';

  /// 启动闸门：旧库仍在且搬迁标记未置位。由组合根在 KV 就绪后 [refresh] 置位，
  /// 迁移页完成阶段一后清零。
  static bool requiresMigration = false;

  static String get _legacyPath =>
      AppFiles.getRealPath('database', legacyFileName);

  static Future<void> refresh() async {
    requiresMigration =
        MoodiaryKVs.dbEngineMigrated.get() != true &&
        await File(_legacyPath).exists();
  }

  /// 执行搬迁。[onProgress] 以「条目」为单位（全部实体合计）。
  /// 失败上抛（页面显示重试）；对账不平抛 [StateError]。
  /// 可注入参数全部只为测试（注入独立内存库与 forTesting 仓储），生产走单例。
  static Future<EngineMigrationReport> migrate({
    void Function(int done, int total)? onProgress,
    MoodiaryDatabase? database,
    DiaryRepository? diaryRepository,
    CategoryRepository? categoryRepository,
    FontRepository? fontRepository,
    MediaInfoRepository? mediaInfoRepository,
    TombstoneRepository? tombstoneRepository,
    String? legacyDir,
  }) async {
    final watch = Stopwatch()..start();
    final db = database ?? MoodiaryDatabase.get();
    final diaryRepo = diaryRepository ?? DiaryRepository.get();
    final categoryRepo = categoryRepository ?? CategoryRepository.get();
    final fontRepo = fontRepository ?? FontRepository.get();
    final mediaInfoRepo = mediaInfoRepository ?? MediaInfoRepository.get();
    final tombstoneRepo = tombstoneRepository ?? TombstoneRepository.get();

    final dir = legacyDir ?? AppFiles.getRealPath('database', '');
    // Isar.open 是 open-or-create：旧库不在时它会造出一个**空库**，往下走就是拿
    // 「零行」去 clearAll 掉一个可能已有数据的 SQLite，且逐表对账 0==0 还会通过。
    // 唯一合法的「旧库不在」是搬迁早已完成（标记置位、闸门不再触发），走不到这里。
    final isar = legacy.openLegacyIsar(
      schemas: legacy.moodiarySchemas,
      dir: dir,
      inspector: false,
    );
    if (isar == null) {
      throw StateError('引擎搬迁中止：旧库 ${legacy.legacyDbFileName} 不存在');
    }
    try {
      // —— 只读盘点（索引类 collection 刻意不搬：FTS/双链在拷贝时重建）。—— //
      final diaryCount = await isar.diarys.where().countAsync();
      final categoryCount = await isar.categorys.where().countAsync();
      final fontCount = await isar.fonts.where().countAsync();
      final mediaInfoCount = await isar.mediaInfos.where().countAsync();
      final tombstoneCount = await isar.syncTombstones.where().countAsync();
      final providerCount = await isar.llmProviders.where().countAsync();
      final sessionCount = await isar.chatSessions.where().countAsync();
      final messageCount = await isar.chatMessages.where().countAsync();
      final memoryCount = await isar.memories.where().countAsync();
      final presetCount = await isar.agentPresets.where().countAsync();
      final total =
          diaryCount +
          categoryCount +
          fontCount +
          mediaInfoCount +
          tombstoneCount +
          providerCount +
          sessionCount +
          messageCount +
          memoryCount +
          presetCount;
      var done = 0;
      void tick(int n) {
        done += n;
        onProgress?.call(done, total);
      }

      var positionDropped = 0;
      var orphanMessagesDropped = 0;

      // —— 起步清空：标记未置位即整库重来，天然可重入。—— //
      // 清空前的最后一道闸：旧库一条日记都没有、而 SQLite 里已经有行，说明打开的
      // 根本不是用户那份旧库（典型成因是别处的 open-or-create 凭空造了个空库），
      // 此时 clearAll 会把已搬迁好的数据全部抹掉，而 0==0 的对账还会放行。
      final existingDiaries = await _rowCount(db, db.diaries);
      if (diaryCount == 0 && existingDiaries > 0) {
        throw StateError(
          '引擎搬迁中止：旧库为空而 SQLite 已有 $existingDiaries 篇日记，'
          '拒绝用空库覆盖',
        );
      }
      await db.clearAll();

      // 分类先于日记只是习惯（无外键约束）；日记分批走仓储：行 + 子表 + FTS +
      // 双链同事务，分词整批过桥。
      const batch = 256;
      for (var i = 0; i < categoryCount; i += batch) {
        final rows = await isar.categorys.where().findAllAsync(
          offset: i,
          limit: batch,
        );
        for (final c in rows) {
          await categoryRepo.insertACategory(
            Category(
              id: c.id,
              categoryName: c.categoryName,
              lastModified: c.lastModified,
              parentId: c.parentId,
              color: c.color,
            ),
            fromSync: true,
          );
        }
        tick(rows.length);
      }

      for (var i = 0; i < diaryCount; i += batch) {
        final rows = await isar.diarys.where().findAllAsync(
          offset: i,
          limit: batch,
        );
        final converted = <Diary>[];
        for (final d in rows) {
          final (position, dropped) = _position(d.position);
          if (dropped) positionDropped++;
          converted.add(
            Diary(
              id: d.id,
              categoryId: d.categoryId,
              title: d.title,
              content: d.content,
              contentText: d.contentText,
              time: d.time,
              lastModified: d.lastModified,
              show: d.show,
              mood: _mood(d.mood),
              weather: _weather(d.weather),
              imageName: d.imageName,
              audioName: d.audioName,
              videoName: d.videoName,
              tags: d.tags,
              position: position,
              type: d.type,
              aspect: d.aspect,
            ),
          );
        }
        await diaryRepo.insertDiaries(converted, fromSync: true);
        tick(rows.length);
      }

      for (final f in await isar.fonts.where().findAllAsync()) {
        await fontRepo.insertFont(
          Font(
            fontFileName: f.fontFileName,
            fontWghtAxisMap: f.fontWghtAxisMap,
          ),
        );
        tick(1);
      }

      for (var i = 0; i < mediaInfoCount; i += batch) {
        final rows = await isar.mediaInfos.where().findAllAsync(
          offset: i,
          limit: batch,
        );
        for (final m in rows) {
          await mediaInfoRepo.insertAMediaInfo(
            MediaInfo(
              fileName: m.fileName,
              name: m.name,
              durationMs: m.durationMs,
              lastModified: m.lastModified,
            ),
            fromSync: true,
          );
        }
        tick(rows.length);
      }

      // 墓碑最后搬：日记 / 分类 / 媒体的插入会顺手清「同 id 墓碑」（复活闸门），
      // 先搬墓碑会被后续插入误清。活着的实体与它的墓碑本就互斥，此序只是防御。
      final tombstones = await isar.syncTombstones.where().findAllAsync();
      await tombstoneRepo.putAll([
        for (final t in tombstones)
          SyncTombstone(
            key: t.key,
            timeMs: t.timeMs,
            pushedBackends: t.pushedBackends,
          ),
      ]);
      tick(tombstones.length);

      // —— 助手侧五张表：migration（feature_base）够不着 assistant（feature）的
      // 仓储，直接走 drift 伴生类；会话先于消息（外键），消息先于工具调用。—— //
      for (final p in await isar.llmProviders.where().findAllAsync()) {
        await db
            .into(db.llmProviders)
            .insertOnConflictUpdate(
              LlmProvidersCompanion.insert(
                id: p.id,
                name: p.name,
                type: p.type,
                baseUrl: p.baseUrl,
                defaultModel: p.defaultModel,
                createdAt: dbTime(p.createdAt),
                sortOrder: p.sortOrder,
                presetId: Value(p.presetId),
                modelsJson: Value(dbStringList(p.models)),
                toolCall: Value(p.toolCall ? 1 : 0),
                reasoning: Value(p.reasoning ? 1 : 0),
                attachment: Value(p.attachment ? 1 : 0),
              ),
            );
        tick(1);
      }

      final sessionIds = <String>{};
      for (var i = 0; i < sessionCount; i += batch) {
        final rows = await isar.chatSessions.where().findAllAsync(
          offset: i,
          limit: batch,
        );
        for (final s in rows) {
          sessionIds.add(s.id);
          await db
              .into(db.chatSessions)
              .insertOnConflictUpdate(
                ChatSessionsCompanion.insert(
                  id: s.id,
                  title: Value(s.title),
                  providerId: s.providerId,
                  model: s.model,
                  createdAt: dbTime(s.createdAt),
                  updatedAt: dbTime(s.updatedAt),
                  reasoningEffort: Value(s.reasoningEffort),
                  compactedSummary: Value(s.compactedSummary),
                  compactedUpToMessageId: Value(s.compactedUpToMessageId),
                  compactedAt: Value(dbTimeOrNull(s.compactedAt)),
                  compactedInputTokensAtTrigger: Value(
                    s.compactedInputTokensAtTrigger,
                  ),
                  agentPresetId: Value(s.agentPresetId),
                  personaSnapshot: Value(s.personaSnapshot),
                  toolsSnapshotJson: Value(dbStringListOrNull(s.toolsSnapshot)),
                ),
              );
        }
        tick(rows.length);
      }

      for (var i = 0; i < messageCount; i += batch) {
        final rows = await isar.chatMessages.where().findAllAsync(
          offset: i,
          limit: batch,
        );
        await db.transaction(() async {
          for (final m in rows) {
            // 悬挂消息（会话行已不在）跳过并计数：外键会拒绝它，且重试也救不回。
            if (!sessionIds.contains(m.sessionId)) {
              orphanMessagesDropped++;
              continue;
            }
            await db
                .into(db.chatMessages)
                .insertOnConflictUpdate(
                  ChatMessagesCompanion.insert(
                    id: m.id,
                    sessionId: m.sessionId,
                    role: m.role,
                    content: m.content,
                    createdAt: dbTime(m.createdAt),
                    reasoning: Value(m.reasoning),
                    thinkingMillis: Value(m.thinkingMillis),
                    imageName: Value(m.imageName),
                    inputTokens: Value(m.inputTokens),
                    outputTokens: Value(m.outputTokens),
                    model: Value(m.model),
                  ),
                );
            for (var seq = 0; seq < m.toolCalls.length; seq++) {
              final c = m.toolCalls[seq];
              await db
                  .into(db.assistantToolCalls)
                  .insertOnConflictUpdate(
                    AssistantToolCallsCompanion.insert(
                      messageId: m.id,
                      seq: seq,
                      callId: c.callId,
                      name: c.name,
                      argsJson: Value(c.argsJson),
                      result: Value(c.result),
                      done: Value(c.done ? 1 : 0),
                    ),
                  );
            }
          }
        });
        tick(rows.length);
      }

      for (final m in await isar.memories.where().findAllAsync()) {
        await db
            .into(db.memories)
            .insertOnConflictUpdate(
              MemoriesCompanion.insert(
                id: m.id,
                category: m.category,
                content: m.text,
                createdAt: dbTime(m.createdAt),
                updatedAt: dbTime(m.updatedAt),
              ),
            );
        tick(1);
      }

      for (final a in await isar.agentPresets.where().findAllAsync()) {
        await db
            .into(db.agentPresets)
            .insertOnConflictUpdate(
              AgentPresetsCompanion.insert(
                id: a.id,
                name: a.name,
                description: Value(a.description),
                persona: a.persona,
                toolsJson: Value(dbStringListOrNull(a.tools)),
                createdAt: dbTime(a.createdAt),
                updatedAt: dbTime(a.updatedAt),
              ),
            );
        tick(1);
      }

      // —— 对账：逐表行数（消息按「跳过悬挂后应到」计）。不平即失败，标记不置位。—— //
      Future<int> sqliteCount(TableInfo table) => _rowCount(db, table);

      final checks = <String, (int, int)>{
        'diaries': (diaryCount, await sqliteCount(db.diaries)),
        'categories': (categoryCount, await sqliteCount(db.categories)),
        'fonts': (fontCount, await sqliteCount(db.fonts)),
        'media_infos': (mediaInfoCount, await sqliteCount(db.mediaInfos)),
        'tombstones': (tombstoneCount, await sqliteCount(db.tombstones)),
        'llm_providers': (providerCount, await sqliteCount(db.llmProviders)),
        'chat_sessions': (sessionCount, await sqliteCount(db.chatSessions)),
        'chat_messages': (
          messageCount - orphanMessagesDropped,
          await sqliteCount(db.chatMessages),
        ),
        'memories': (memoryCount, await sqliteCount(db.memories)),
        'agent_presets': (presetCount, await sqliteCount(db.agentPresets)),
      };
      for (final MapEntry(key: table, value: (expected, actual))
          in checks.entries) {
        if (expected != actual) {
          throw StateError('引擎搬迁对账不平：$table 应 $expected 行，实 $actual 行');
        }
      }

      return EngineMigrationReport(
        diaries: diaryCount,
        entities: total,
        positionDropped: positionDropped,
        orphanMessagesDropped: orphanMessagesDropped,
        elapsed: watch.elapsed,
      );
    } finally {
      isar.close();
    }
  }

  /// 对账通过后的收尾：置标记 + 旧库改名留底。与 [migrate] 分开，测试可只验拷贝。
  static Future<void> finalizeMigration() async {
    MoodiaryKVs.dbEngineMigrated.set(true);
    // 搬迁把 FTS 与双链一并建满，升级用户不再需要「重建索引」提示。
    MoodiaryKVs.searchIndexBackfilled.set(true);
    requiresMigration = false;
    try {
      final file = File(_legacyPath);
      if (await file.exists()) {
        await file.rename(
          AppFiles.getRealPath('database', legacyBackupFileName),
        );
      }
      final lock = File('$_legacyPath.lock');
      if (await lock.exists()) await lock.delete();
    } catch (e, s) {
      // 改名失败不阻断（标记已置位，闸门不会再触发）；旧文件由重置数据兜底清理。
      logger.e('rename legacy isar failed', error: e, stackTrace: s);
    }
  }

  /// 旧 `[纬度, 经度, 地名]`（地名可缺）→ 值对象；数值解析失败按无定位并计数。
  static (DiaryPosition?, bool) _position(List<String> raw) {
    if (raw.length < 2) return (null, false);
    final lat = double.tryParse(raw[0]);
    final lng = double.tryParse(raw[1]);
    if (lat == null || lng == null) return (null, true);
    return (
      DiaryPosition(
        latitude: lat,
        longitude: lng,
        name: raw.length >= 3 ? raw[2] : '',
      ),
      false,
    );
  }

  /// 旧 `[图标码, 温度, 描述]` → 值对象；不足三段视为无天气。
  static DiaryWeather? _weather(List<String> raw) {
    if (raw.length < 3) return null;
    return DiaryWeather(icon: raw[0], temp: raw[1], text: raw[2]);
  }

  /// 旧滑条浮点 → 三分类。0.5 是旧默认值（从未动过滑条）= 中性；
  /// 偏离中点即用户有意为之，按方向归到两端。
  static DiaryMood _mood(double raw) => switch (raw) {
    < 0.5 => .negative,
    > 0.5 => .positive,
    _ => .neutral,
  };
}

/// 单表行数。搬迁前的空库闸门与搬迁后的对账共用。
Future<int> _rowCount(MoodiaryDatabase db, TableInfo table) async {
  final row = await (db.selectOnly(
    table,
  )..addColumns([countAll()])).getSingle();
  return row.read(countAll())!;
}

class EngineMigrationReport {
  final int diaries;

  /// 全部实体条数（进度分母）。
  final int entities;

  /// 旧定位数据解析失败被丢弃的篇数（只丢定位，不丢日记）。
  final int positionDropped;

  /// 会话行缺失被跳过的悬挂消息数。
  final int orphanMessagesDropped;

  final Duration elapsed;

  const EngineMigrationReport({
    required this.diaries,
    required this.entities,
    required this.positionDropped,
    required this.orphanMessagesDropped,
    required this.elapsed,
  });
}
