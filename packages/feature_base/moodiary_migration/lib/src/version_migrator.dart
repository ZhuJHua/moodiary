import 'package:flutter/foundation.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:pub_semver/pub_semver.dart';

class VersionMigrator {
  static Future<void> run() async {
    if (MmkvKVStorage.legacyMigrationPending) return;
    final packageInfo = await AppInfo.getPackageInfo();
    await apply(
      currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }

  @visibleForTesting
  static Future<void> apply({required String currentVersion}) async {
    final appVersion = MoodiaryKVs.appVersion.get();
    if (appVersion != null) {
      await merge(lastAppVersion: appVersion);
    }
    if (appVersion == null) {
      MoodiaryKVs.searchIndexBackfilled.set(true);
      MoodiaryKVs.contentSchemaV2.set(true);
    }
    if (kDebugMode || appVersion == null || appVersion != currentVersion) {
      MoodiaryKVs.appVersion.set(currentVersion);
    }
  }

  @visibleForTesting
  static bool versionBelow(String lastAppVersion, String gate) {
    final parsed = Version.parse(lastAppVersion);
    final normalized = Version(parsed.major, parsed.minor, parsed.patch);
    return normalized < Version.parse(gate);
  }

  static Future<void> merge({required String lastAppVersion}) async {
    bool below(String version) => versionBelow(lastAppVersion, version);

    if (below('2.6.3')) {
      await MediaManager.regenerateMissingThumbnails();
    }

    if (below('2.7.3')) {
      MoodiaryKVs.customFont.set('');
    }

    if (below('2.8.0')) {
      MoodiaryKVs.autoSync.set(false);
    }

    if (below('2.8.2') && MoodiaryKVs.assistantReasoningEffort.get() == '') {
      MoodiaryKVs.assistantReasoningEffort.set('none');
    }

    if (below('2.9.1')) {
      await _purgeMoodLlmModel();
    }
  }
}

Future<void> _purgeMoodLlmModel() async {
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
    getIt<IKVStorage>().remove('moodLlmModelId');
  } catch (e, s) {
    logger.e('remove mood model key failed', error: e, stackTrace: s);
  }
}
