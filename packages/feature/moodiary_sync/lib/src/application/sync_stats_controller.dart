import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_stats_controller.g.dart';

class SyncStats {
  final int localDiaries;

  final int localCategories;

  final int localMedia;

  final int? remoteDiaries;
  final int? remoteCategories;
  final int? remoteMedia;
  final String? remoteError;

  const SyncStats({
    required this.localDiaries,
    required this.localCategories,
    required this.localMedia,
    this.remoteDiaries,
    this.remoteCategories,
    this.remoteMedia,
    this.remoteError,
  });
}

@riverpod
Future<SyncStats> syncStats(Ref ref) async {
  final diaries = await getIt<DiaryRepository>().getAllDiaries();
  final localDiaries = diaries.length;
  final localCategories =
      (await getIt<CategoryRepository>().getAllCategories()).length;
  final localMedia = {
    for (final d in diaries)
      for (final e in collectDiaryMediaEntries(d))
        SyncKeys.mediaRef(e.$1, e.$2),
  }.length;

  int? remoteDiaries;
  int? remoteCategories;
  int? remoteMedia;
  String? remoteError;

  final backend = getIt<IRemoteSyncBackend>();
  if (!await backend.isReady()) {
    remoteError = l10n.sync.errNoBackend;
  } else {
    try {
      final bytes = await backend.readObject(SyncKeys.manifestPath);
      if (bytes == null) {
        remoteDiaries = 0;
        remoteCategories = 0;
        remoteMedia = 0;
      } else {
        final decoded = await (await SyncCipher.current()).decode(bytes);
        if (decoded is! Map<String, dynamic>) {
          remoteError = l10n.sync.errManifestBroken;
        } else {
          final manifest = SyncManifest.fromJson(decoded);
          int countByPrefix(String prefix) => manifest.entries.entries
              .where((e) => e.key.startsWith(prefix) && !e.value.deleted)
              .length;
          remoteDiaries = countByPrefix(SyncKeys.diaryPrefix);
          remoteCategories = countByPrefix(SyncKeys.categoryPrefix);
          remoteMedia = manifest.referencedMedia().length;
        }
      }
    } on SyncException catch (e) {
      remoteError = e.message;
    } catch (e) {
      remoteError = e.toString();
    }
  }

  return SyncStats(
    localDiaries: localDiaries,
    localCategories: localCategories,
    localMedia: localMedia,
    remoteDiaries: remoteDiaries,
    remoteCategories: remoteCategories,
    remoteMedia: remoteMedia,
    remoteError: remoteError,
  );
}
