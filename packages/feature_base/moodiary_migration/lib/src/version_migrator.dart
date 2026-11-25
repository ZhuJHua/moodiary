import 'package:flutter/foundation.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:pub_semver/pub_semver.dart';

class VersionMigrator {
  static Future<void> run({IKVStorage? storage}) async {
    if (MmkvKVStorage.legacyMigrationPending) return;
    final packageInfo = await AppInfo.getPackageInfo();
    await apply(
      storage: storage,
      currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }

  @visibleForTesting
  static Future<void> apply({
    required String currentVersion,
    IKVStorage? storage,
  }) async {
    final kv = storage ?? getIt<IKVStorage>();
    final appVersion = kv.get<String>(MoodiaryKVs.appVersion.name);
    if (appVersion != null) {
      await merge(lastAppVersion: appVersion, storage: kv);
    }
    if (appVersion == null) {
      kv.set(MoodiaryKVs.searchIndexBackfilled.name, true);
      kv.set(MoodiaryKVs.contentSchemaV2.name, true);
    }
    if (kDebugMode || appVersion == null || appVersion != currentVersion) {
      kv.set(MoodiaryKVs.appVersion.name, currentVersion);
    }
  }

  @visibleForTesting
  static bool versionBelow(String lastAppVersion, String gate) {
    final parsed = Version.parse(lastAppVersion);
    final normalized = Version(parsed.major, parsed.minor, parsed.patch);
    return normalized < Version.parse(gate);
  }

  static Future<void> merge({
    required String lastAppVersion,
    IKVStorage? storage,
  }) async {
    late final kv = storage ?? getIt<IKVStorage>();
    bool below(String version) => versionBelow(lastAppVersion, version);

    if (below('2.6.3')) {
      await MediaManager.regenerateMissingThumbnails();
    }

    if (below('2.7.3')) {
      kv.set(MoodiaryKVs.customFont.name, '');
    }

    if (below('2.8.0')) {
      kv.set(MoodiaryKVs.autoSync.name, false);
    }

    if (below('2.8.2') &&
        (kv.get<String>(MoodiaryKVs.assistantReasoningEffort.name) ??
                MoodiaryKVs.assistantReasoningEffort.defaultValue) ==
            '') {
      kv.set(MoodiaryKVs.assistantReasoningEffort.name, 'none');
    }

    if (below('2.9.1')) {
      await _purgeMoodLlmModel(storage);
    }
  }
}

Future<void> _purgeMoodLlmModel(IKVStorage? storage) async {
  for (final name in const [
    'qwen3-0.6b-int8.onnx',
    'qwen3-0.6b-int8.tokenizer.json',
    'qwen3-0.6b-int8.onnx.part',
    'qwen3-0.6b-int8.tokenizer.json.part',
  ]) {
    try {
      await AppFiles.deleteFile(AppFiles.getRealPath('model', name));
    } catch (e, s) {
      logger.e('purge mood model failed: $name', error: e, stackTrace: s);
    }
  }
  try {
    (storage ?? getIt<IKVStorage>()).remove('moodLlmModelId');
  } catch (e, s) {
    logger.e('remove mood model key failed', error: e, stackTrace: s);
  }
}
