import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/media_refs.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_stats_controller.g.dart';

class SyncStats {
  final int localDiaries;

  final int localCategories;
  final int localTags;

  final int localMedia;

  final int? remoteDiaries;
  final int? remoteCategories;
  final int? remoteTags;
  final int? remoteMedia;
  final String? remoteError;

  const SyncStats({
    required this.localDiaries,
    required this.localCategories,
    required this.localTags,
    required this.localMedia,
    this.remoteDiaries,
    this.remoteCategories,
    this.remoteTags,
    this.remoteMedia,
    this.remoteError,
  });
}

@riverpod
Future<SyncStats> syncStats(Ref ref) async {
  final backend = ref.watch(activeSyncBackendProvider);
  final categories = ref.watch(categoryRepositoryProvider);
  final tags = ref.watch(tagRepositoryProvider);
  final diaries = await ref.watch(diaryRepositoryProvider).getAllDiaries();
  final localDiaries = diaries.length;
  final localCategories = (await categories.getAllCategoriesForSync()).length;
  final localTags = (await tags.getAllTags(includeDeleted: true)).length;
  final localMedia = {
    for (final d in diaries)
      for (final e in collectDiaryMediaEntries(d))
        SyncKeys.mediaRef(e.$1, e.$2),
  }.length;

  int? remoteDiaries;
  int? remoteCategories;
  int? remoteTags;
  int? remoteMedia;
  String? remoteError;

  if (!await backend.isReady()) {
    remoteError = l10n.sync.errNoBackend;
  } else {
    try {
      final bytes = await backend.readObject(SyncKeys.manifestPath);
      if (bytes == null) {
        remoteDiaries = 0;
        remoteCategories = 0;
        remoteTags = 0;
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
          remoteTags = countByPrefix(SyncKeys.tagPrefix);
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
    localTags: localTags,
    localMedia: localMedia,
    remoteDiaries: remoteDiaries,
    remoteCategories: remoteCategories,
    remoteTags: remoteTags,
    remoteMedia: remoteMedia,
    remoteError: remoteError,
  );
}
