import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_stats_controller.g.dart';

/// 同步状态页的「本地 / 远端数据概览」快照。
class SyncStats {
  /// 本地活跃日记数（不含草稿、待推 tombstone 的已删日记）。
  final int localDiaries;

  /// 本地活跃分类数（不含已软删）。
  final int localCategories;

  /// 远端来自 manifest 非 tombstone 条目计数，媒体为清单并集。
  /// null = 未能获取（原因见 [remoteError]）。
  final int? remoteDiaries;
  final int? remoteCategories;
  final int? remoteMedia;
  final String? remoteError;

  const SyncStats({
    required this.localDiaries,
    required this.localCategories,
    this.remoteDiaries,
    this.remoteCategories,
    this.remoteMedia,
    this.remoteError,
  });
}

/// 拉取一次本地 + 远端数据概览。远端只读 `manifest.json`（一次往返），失败不抛出、
/// 以 [SyncStats.remoteError] 呈现，本地数量始终可用。
@riverpod
Future<SyncStats> syncStats(Ref ref) async {
  final diaries = await DiaryRepository.get().getAllDiaries();
  final localDiaries = diaries.where((d) => !d.deleted).length;
  final localCategories =
      (await CategoryRepository.get().getAllCategories().run())
          .getOrElse((_) => const <Category>[])
          .length;

  int? remoteDiaries;
  int? remoteCategories;
  int? remoteMedia;
  String? remoteError;

  final backend = IRemoteSyncBackend.get();
  if (!backend.isReady) {
    remoteError = '尚未配置同步后端';
  } else {
    try {
      final bytes = await backend.readObject(SyncKeys.manifestPath);
      if (bytes == null) {
        // 远端为空（尚未上传过备份）也是有效状态。
        remoteDiaries = 0;
        remoteCategories = 0;
        remoteMedia = 0;
      } else {
        final decoded = await (await SyncCipher.current()).decode(bytes);
        if (decoded is! Map<String, dynamic>) {
          remoteError = '远端 manifest 格式异常';
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
    remoteDiaries: remoteDiaries,
    remoteCategories: remoteCategories,
    remoteMedia: remoteMedia,
    remoteError: remoteError,
  );
}
