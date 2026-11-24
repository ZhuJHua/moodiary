import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late Directory support;

  setUpAll(() {
    support = Directory.systemTemp.createTempSync('version-migrator');
    PlatformService.get().applicationSupportPath = support.path;
  });

  tearDownAll(() => support.deleteSync(recursive: true));

  group('versionBelow 闸门语义', () {
    test('低版本在闸门之下', () {
      expect(VersionMigrator.versionBelow('2.7.3+73', '2.8.0'), isTrue);
      expect(VersionMigrator.versionBelow('2.4.7+50', '2.4.8'), isTrue);
    });

    test('同版本与更高版本不触发（含 build 元数据）', () {
      expect(VersionMigrator.versionBelow('2.8.0+94', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.8.1+1', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.8.0+999', '2.8.0'), isFalse);
    });

    test('pre-release 被剥掉：beta 渠道不得每次冷启动重跑迁移', () {
      expect(VersionMigrator.versionBelow('2.8.0-beta+94', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.7.3-beta+73', '2.8.0'), isTrue);
    });

    test('semver 比较而非字典序', () {
      expect(VersionMigrator.versionBelow('2.10.0+1', '2.9.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.9.0+1', '2.10.0'), isTrue);
    });
  });

  group('merge 在 2.9.1 及以上是纯 no-op', () {
    test('正式版与 beta 版都直接返回', () async {
      await VersionMigrator.merge(lastAppVersion: '2.9.1+120');
      await VersionMigrator.merge(lastAppVersion: '2.9.1-beta+120');
      await VersionMigrator.merge(lastAppVersion: '2.10.0+130');
    });
  });

  group('2.8.2：思考档位从空串变成显式关闭', () {
    late MemoryKVStorage kv;

    setUp(() {
      kv = MemoryKVStorage();
      getIt.registerSingleton<IKVStorage>(kv);
    });

    tearDown(getIt.reset);

    test('旧版写进去的空串变成 none', () async {
      kv.set<String>(MoodiaryKVs.assistantReasoningEffort.name, '');
      await VersionMigrator.merge(lastAppVersion: '2.8.1+95');
      expect(MoodiaryKVs.assistantReasoningEffort.get(), 'none');
    });

    test('显式档位与显式关闭原样保留', () async {
      kv.set<String>(MoodiaryKVs.assistantReasoningEffort.name, 'high');
      await VersionMigrator.merge(lastAppVersion: '2.8.1+95');
      expect(MoodiaryKVs.assistantReasoningEffort.get(), 'high');

      kv.set<String>(MoodiaryKVs.assistantReasoningEffort.name, 'none');
      await VersionMigrator.merge(lastAppVersion: '2.8.1+95');
      expect(MoodiaryKVs.assistantReasoningEffort.get(), 'none');
    });

    test('2.8.2 之后不再碰这个键', () async {
      kv.set<String>(MoodiaryKVs.assistantReasoningEffort.name, '');
      await VersionMigrator.merge(lastAppVersion: '2.8.2+96');
      expect(MoodiaryKVs.assistantReasoningEffort.get(), '');
    });
  });

  group('2.9.1：清理已下线的心情推荐模型', () {
    const moodFiles = [
      'qwen3-0.6b-int8.onnx',
      'qwen3-0.6b-int8.tokenizer.json',
      'qwen3-0.6b-int8.onnx.part',
      'qwen3-0.6b-int8.tokenizer.json.part',
    ];
    const embeddingFile = 'qwen3-embedding-0.6b-int8.onnx';
    late MemoryKVStorage kv;
    late Directory modelDir;

    File modelFile(String name) => File(AppFiles.getRealPath('model', name));

    setUp(() {
      kv = MemoryKVStorage();
      getIt.registerSingleton<IKVStorage>(kv);
      modelDir = Directory(AppFiles.getRealPath('model', ''))..createSync();
      for (final name in [...moodFiles, embeddingFile]) {
        modelFile(name).writeAsStringSync(name);
      }
      kv.set<String>('moodLlmModelId', 'qwen3-0.6b-int8');
    });

    tearDown(() async {
      await getIt.reset();
      if (modelDir.existsSync()) modelDir.deleteSync(recursive: true);
    });

    test('2.9.0 升级删除模型、分片和旧键，保留 embedding 模型', () async {
      await VersionMigrator.merge(lastAppVersion: '2.9.0+119');

      for (final name in moodFiles) {
        expect(modelFile(name).existsSync(), isFalse, reason: name);
      }
      expect(kv.data.containsKey('moodLlmModelId'), isFalse);
      expect(modelFile(embeddingFile).readAsStringSync(), embeddingFile);
    });

    test('模型目录不存在也能清理旧键，重复执行不报错', () async {
      modelDir.deleteSync(recursive: true);
      await VersionMigrator.merge(lastAppVersion: '2.9.0+119');
      await VersionMigrator.merge(lastAppVersion: '2.9.0+119');

      expect(kv.data.containsKey('moodLlmModelId'), isFalse);
      expect(modelDir.existsSync(), isFalse);
    });

    for (final version in ['2.9.1+120', '2.10.0+130']) {
      test('$version 保留模型文件和旧键', () async {
        await VersionMigrator.merge(lastAppVersion: version);

        for (final name in [...moodFiles, embeddingFile]) {
          expect(modelFile(name).readAsStringSync(), name);
        }
        expect(kv.get<String>('moodLlmModelId'), 'qwen3-0.6b-int8');
      });
    }
  });

  group('内容 schema v2 闸门', () {
    setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
    tearDown(getIt.reset);

    test(
      'older versions still reset the custom font and automatic sync',
      () async {
        MoodiaryKVs.appVersion.set('2.6.2');
        MoodiaryKVs.customFont.set('Old');
        MoodiaryKVs.autoSync.set(true);
        await VersionMigrator.apply(currentVersion: '2.10.0');
        expect(MoodiaryKVs.customFont.get(), '');
        expect(MoodiaryKVs.autoSync.get(), isFalse);
        expect(MoodiaryKVs.appVersion.get(), '2.10.0');
      },
    );

    test('全新安装直接视为已升级', () async {
      await VersionMigrator.apply(currentVersion: '2.9.0+120');
      expect(MoodiaryKVs.contentSchemaV2.get(), isTrue);
      expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);
      expect(MoodiaryKVs.appVersion.get(), '2.9.0+120');
    });

    test('老用户升级不动标志，留给迁移页', () async {
      MoodiaryKVs.appVersion.set('2.8.2+96');
      await VersionMigrator.apply(currentVersion: '2.9.0+120');
      expect(MoodiaryKVs.contentSchemaV2.get(), isFalse);
      expect(MoodiaryKVs.appVersion.get(), '2.9.0+120');
    });
  });
}
