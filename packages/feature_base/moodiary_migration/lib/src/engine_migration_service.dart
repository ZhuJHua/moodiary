import 'dart:io';

import 'package:drift/drift.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class EngineMigrationService {
  const EngineMigrationService._();

  static const String legacyFileName = 'default.isar';
  static const String legacyBackupFileName = 'default.isar.pre-sqlite.bak';

  static bool requiresMigration = false;

  static String get _legacyPath =>
      AppFiles.getRealPath('database', legacyFileName);

  static Future<void> refresh() async {
    requiresMigration =
        MoodiaryKVs.dbEngineMigrated.get() != true &&
        await File(_legacyPath).exists();
  }

  static Future<EngineMigrationReport> migrate({
    void Function(int done, int total)? onProgress,
    MoodiaryDatabase? database,
    DiaryRepository? diaryRepository,
    CategoryRepository? categoryRepository,
    PlaceRepository? placeRepository,
    FontRepository? fontRepository,
    MediaInfoRepository? mediaInfoRepository,
    TombstoneRepository? tombstoneRepository,
    String? legacyDir,
  }) async {
    final watch = Stopwatch()..start();
    final db = database ?? getIt<MoodiaryDatabase>();
    final diaryRepo = diaryRepository ?? getIt<DiaryRepository>();
    final categoryRepo = categoryRepository ?? getIt<CategoryRepository>();
    final placeRepo = placeRepository ?? getIt<PlaceRepository>();
    final fontRepo = fontRepository ?? getIt<FontRepository>();
    final mediaInfoRepo = mediaInfoRepository ?? getIt<MediaInfoRepository>();
    final tombstoneRepo = tombstoneRepository ?? getIt<TombstoneRepository>();

    final dir = legacyDir ?? AppFiles.getRealPath('database', '');
    // Isar.open 是 open-or-create：旧库不在时会静默造出空库
    final isar = legacy.openLegacyIsar(
      schemas: legacy.moodiarySchemas,
      dir: dir,
      inspector: false,
    );
    if (isar == null) {
      throw StateError('引擎搬迁中止：旧库 ${legacy.legacyDbFileName} 不存在');
    }
    try {
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
      final placesByName = <String, Place>{};

      final existingDiaries = await _rowCount(db, db.diaries);
      if (diaryCount == 0 && existingDiaries > 0) {
        throw StateError(
          '引擎搬迁中止：旧库为空而 SQLite 已有 $existingDiaries 篇日记，'
          '拒绝用空库覆盖',
        );
      }
      await db.clearAll();

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
          final position = _position(d.position);
          String? placeId;
          if (position == null) {
            if (d.position.length >= 2) positionDropped++;
          } else {
            var place = placesByName[position.name];
            if (place == null) {
              place = Place.forName(
                position.name,
                latitude: position.latitude,
                longitude: position.longitude,
              );
              placesByName[position.name] = place;
              await placeRepo.insertAPlace(place, fromSync: true);
            }
            placeId = place.id;
          }
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
              placeId: placeId,
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

      // 墓碑必须最后搬：日记/分类/媒体插入会顺手清同 id 墓碑，先搬会被误清
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

      // 会话先于消息、消息先于工具调用插入（外键约束）
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

      Future<int> sqliteCount(TableInfo table) => _rowCount(db, table);

      final checks = <String, (int, int)>{
        'diaries': (diaryCount, await sqliteCount(db.diaries)),
        'categories': (categoryCount, await sqliteCount(db.categories)),
        'places': (placesByName.length, await sqliteCount(db.places)),
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

  static Future<void> finalizeMigration() async {
    MoodiaryKVs.dbEngineMigrated.set(true);
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
      logger.e('rename legacy isar failed', error: e, stackTrace: s);
    }
  }

  static ({double latitude, double longitude, String name})? _position(
    List<String> raw,
  ) {
    if (raw.length < 2) return null;
    final lat = double.tryParse(raw[0]);
    final lng = double.tryParse(raw[1]);
    if (lat == null || lng == null) return null;
    final name = raw.length >= 3 ? raw[2].trim() : '';
    return (
      latitude: lat,
      longitude: lng,
      name: name.isEmpty ? Place.coordinateName(lat, lng) : name,
    );
  }

  static DiaryWeather? _weather(List<String> raw) {
    if (raw.length < 3) return null;
    return DiaryWeather(icon: raw[0], temp: raw[1], text: raw[2]);
  }

  static DiaryMood _mood(double raw) => switch (raw) {
    < 0.5 => .negative,
    > 0.5 => .positive,
    _ => .neutral,
  };
}

Future<int> _rowCount(MoodiaryDatabase db, TableInfo table) async {
  final row = await (db.selectOnly(
    table,
  )..addColumns([countAll()])).getSingle();
  return row.read(countAll())!;
}

class EngineMigrationReport {
  final int diaries;

  final int entities;

  final int positionDropped;

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
