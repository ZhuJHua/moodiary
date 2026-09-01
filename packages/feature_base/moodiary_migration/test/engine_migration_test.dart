// 引擎搬迁（旧 Isar → SQLite）集成测试：真开一个旧世界的 isar 库灌入代表性数据，
// 跑 EngineMigrationService.migrate 后在 SQLite 侧逐项验收。
//
// 需要 ISAR_TEST_DYLIB 指向 libisar_plus 动态库（获取方式见
// moodiary_migration/test/version_migrator_test.dart 文件头）。未设置时整组跳过。
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show countAll;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/foundation.dart' show TokenizeResult;
import 'package:moodiary_rust/testing.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

Future<TokenizeResult> fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

String tiptapDoc(String text, {List<String> linkTo = const []}) => jsonEncode({
  'type': 'doc',
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': text},
        for (final target in linkTo)
          {
            'type': 'diaryLink',
            'attrs': {'id': target},
          },
      ],
    },
  ],
});

legacy.Diary legacyDiary(
  String id,
  String text, {
  List<String> position = const [],
  List<String> weather = const [],
  List<String> linkTo = const [],
  List<String> images = const [],
  List<String> tags = const [],
  bool show = true,
  String type = 'tiptap',
}) => legacy.Diary(
  id: id,
  title: 'title-$id',
  content: tiptapDoc(text, linkTo: linkTo),
  contentText: text,
  time: DateTime.utc(2026, 1, 1, 8),
  lastModified: DateTime.utc(2026, 1, 2, 8),
  show: show,
  mood: 0.5,
  weather: weather,
  imageName: images,
  audioName: const [],
  videoName: const [],
  tags: tags,
  position: position,
  type: type,
);

void main() {
  final dylib = Platform.environment['ISAR_TEST_DYLIB'];
  if (dylib == null || dylib.isEmpty) {
    test(
      'engine migration (skipped)',
      () {},
      skip: '需要 ISAR_TEST_DYLIB 指向 libisar_plus 动态库，见文件头注释',
    );
    return;
  }

  late Directory dir;
  late MoodiaryDatabase db;

  setUpAll(() async {
    await Isar.initialize(dylib);
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('engine_migration_test');
    installFakeRustLib(fakeTokenize);
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// 旧世界种子库：覆盖全部实体与边角形状。
  void seedLegacy() {
    final isar = Isar.open(
      schemas: legacy.moodiarySchemas,
      directory: dir.path,
      inspector: false,
    );
    final now = DateTime.utc(2026, 5, 1);
    isar.write((isar) {
      isar.diarys.putAll([
        legacyDiary(
          'd-full',
          '苹果 香蕉',
          position: const ['24.48', '118.08', '厦门 环岛路'],
          weather: const ['100', '26', '晴'],
          images: const ['image-1.jpg'],
          tags: const ['旅行'],
        ),
        legacyDiary('d-linked', '链接 源', linkTo: const ['d-full']),
        legacyDiary('d-pos2', '老 定位', position: const ['1.5', '2.5']),
        legacyDiary('d-badpos', '坏 定位', position: const ['北纬', '东经', '某地']),
        legacyDiary('d-recycled', '回收站 里', show: false),
        legacyDiary('d-legacyfmt', '旧 格式', type: 'richText'),
      ]);
      isar.categorys.put(
        legacy.Category(id: 'c1', categoryName: '生活', lastModified: now),
      );
      isar.fonts.put(
        const legacy.Font(
          fontFileName: 'LXGW.ttf',
          fontWghtAxisMap: {'wght': 400},
        ),
      );
      isar.mediaInfos.put(
        legacy.MediaInfo(
          fileName: 'audio-1.m4a',
          name: '晨间录音',
          durationMs: 1234,
          lastModified: now,
        ),
      );
      isar.syncTombstones.put(
        legacy.SyncTombstone(
          key: 'd:deleted-diary',
          timeMs: now.millisecondsSinceEpoch,
          pushedBackends: const ['backend-a'],
        ),
      );
      isar.llmProviders.put(
        legacy.LlmProvider(
          id: 'p1',
          name: 'DeepSeek',
          type: 'openai-completions',
          baseUrl: 'https://api.example.com',
          defaultModel: 'deepseek-chat',
          createdAt: now,
          sortOrder: 0,
          presetId: 'deepseek',
          models: const ['deepseek-chat'],
        ),
      );
      isar.chatSessions.put(
        legacy.ChatSession(
          id: 's1',
          providerId: 'p1',
          model: 'deepseek-chat',
          createdAt: now,
          updatedAt: now,
          toolsSnapshot: const [],
        ),
      );
      isar.chatMessages.putAll([
        legacy.ChatMessage(
          id: 'm1',
          sessionId: 's1',
          role: 'assistant',
          content: '答案',
          createdAt: now,
          toolCalls: const [
            legacy.AssistantToolCall(
              callId: 'call-1',
              name: 'queryDiaries',
              argsJson: '{"q":"苹果"}',
              result: '找到 1 篇',
              done: true,
            ),
          ],
        ),
        legacy.ChatMessage(
          id: 'm-orphan',
          sessionId: 'ghost-session',
          role: 'user',
          content: '悬挂消息',
          createdAt: now,
        ),
      ]);
      isar.memories.put(
        legacy.MemoryEntry(
          id: 'mem1',
          category: 'fact',
          text: '住在厦门',
          createdAt: now,
          updatedAt: now,
        ),
      );
      isar.agentPresets.put(
        legacy.AgentPreset(
          id: 'ap1',
          name: '写作助手',
          persona: 'You are a writer.',
          tools: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    isar.close();
  }

  Future<EngineMigrationReport> migrate() => EngineMigrationService.migrate(
    database: db,
    diaryRepository: DiaryRepository.forTesting(db),
    categoryRepository: CategoryRepository.forTesting(db),
    fontRepository: FontRepository.forTesting(db),
    mediaInfoRepository: MediaInfoRepository.forTesting(db),
    tombstoneRepository: TombstoneRepository.forTesting(db),
    legacyDir: dir.path,
  );

  test('全实体搬迁 + 值转换 + 对账', () async {
    seedLegacy();
    final report = await migrate();

    expect(report.diaries, 6);
    expect(report.positionDropped, 1, reason: '坏定位只丢定位不丢日记');
    expect(report.orphanMessagesDropped, 1);

    final repo = DiaryRepository.forTesting(db);
    // 值对象转换
    final full = (await repo.getDiaryByBusinessId('d-full'))!;
    expect(full.position?.latitude, 24.48);
    expect(full.position?.name, '厦门 环岛路');
    expect(full.weather?.text, '晴');
    expect(full.imageName, ['image-1.jpg']);
    expect(full.tags, ['旅行']);
    expect(full.time, DateTime.utc(2026, 1, 1, 8));
    // 两元素旧定位：地名空串
    final pos2 = (await repo.getDiaryByBusinessId('d-pos2'))!;
    expect(pos2.position?.latitude, 1.5);
    expect(pos2.position?.name, '');
    // 坏定位丢弃
    expect((await repo.getDiaryByBusinessId('d-badpos'))!.position, isNull);
    // 回收站保留
    expect((await repo.getRecycleBinDiaries()).single.id, 'd-recycled');

    // FTS 与双链在搬迁中建成
    final hits = await repo.searchDiaries(
      cutTokens: const ['苹果'],
      cutForSearchTokens: const [],
    );
    expect(hits.map((d) => d.id), ['d-full']);
    expect((await repo.getBacklinks('d-full')).map((d) => d.id), ['d-linked']);

    // 旧格式日记原样搬入（等阶段二的正文格式迁移处理）
    expect(await repo.hasLegacyFormatDiaries(), isTrue);

    // 其余实体
    expect(
      (await CategoryRepository.forTesting(db).getAllCategories()).single.id,
      'c1',
    );
    expect(
      (await FontRepository.forTesting(db).getFontByFontFamily('LXGW'))!
          .fontWghtAxisMap,
      {'wght': 400},
    );
    final mediaInfo = await MediaInfoRepository.forTesting(db)
        .getMediaInfoByFileName('audio-1.m4a');
    expect(mediaInfo!.durationMs, 1234);
    final tombstone = await TombstoneRepository.forTesting(db)
        .getByKey('d:deleted-diary');
    expect(tombstone!.pushedBackends, ['backend-a']);

    final session = await (db.select(
      db.chatSessions,
    )..where((s) => s.id.equals('s1'))).getSingle();
    expect(session.toolsSnapshotJson, '[]', reason: '空列表 ≠ null（工具快照语义）');
    final calls = await db.select(db.assistantToolCalls).get();
    expect(calls.single.callId, 'call-1');
    expect(calls.single.done, 1);
    final messages = await db.select(db.chatMessages).get();
    expect(messages.map((m) => m.id), ['m1'], reason: '悬挂消息被跳过');
    final memory = await db.select(db.memories).get();
    expect(memory.single.content, '住在厦门');
    final preset = await db.select(db.agentPresets).get();
    expect(preset.single.toolsJson, isNull, reason: 'null = 全部工具');
  });

  test('可重入：中途重来（重复 migrate）结果一致', () async {
    seedLegacy();
    await migrate();
    final report = await migrate();
    expect(report.diaries, 6);
    final row = await (db.selectOnly(
      db.diaries,
    )..addColumns([countAll()])).getSingle();
    expect(row.read(countAll()), 6);
  });

  test('搬迁不产生本地变更事件（fromSync）', () async {
    seedLegacy();
    final repo = DiaryRepository.forTesting(db);
    final localChanges = <DiaryEvent>[];
    final sub = repo.diaryEvents.listen((e) {
      final fromSync = switch (e) {
        DiaryCreated(:final fromSync) ||
        DiaryUpdated(:final fromSync) ||
        DiaryDeleted(:final fromSync) => fromSync,
      };
      if (!fromSync) localChanges.add(e);
    });
    addTearDown(sub.cancel);
    await EngineMigrationService.migrate(
      database: db,
      diaryRepository: repo,
      categoryRepository: CategoryRepository.forTesting(db),
      fontRepository: FontRepository.forTesting(db),
      mediaInfoRepository: MediaInfoRepository.forTesting(db),
      tombstoneRepository: TombstoneRepository.forTesting(db),
      legacyDir: dir.path,
    );
    await pumpEventQueue();
    expect(localChanges, isEmpty, reason: '搬迁写入不得触发同步标脏/回声推送');
  });
}
