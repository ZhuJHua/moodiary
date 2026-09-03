import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'diary_derive.dart';
import 'diary_repository.dart';

/// 「设置 → 数据 → 图片优化」：用户主动触发的一次性整理，两步。
///
/// 1. **历史 HEIC 转 JPG**：旧版本按源格式原样落盘的 `image-<uuid>.heic`，两端都
///    解不了。同 uuid 换后缀转成 JPG，正文里的引用一并改写，旧文件删掉。这是一次
///    **真实的用户编辑**（要 bump lastModified）：新名字得经同步推到其它设备，它们
///    拉到 jpg 后旧 heic 在那边成孤儿，由各自的「清理无用文件」回收。
/// 2. **补齐缩略图**：全部被引用的图片过一遍 [FastImageDerivatives.warm]，已有的档位
///    直接跳过，所以反复执行是幂等的。展示端只查不生成，存量图片在这一步之前一直
///    按原图解，所以这是老用户升级后该跑一次的入口。
///
/// 转不动的 HEIC（文件损坏）原样留着不改正文，计入 [ImageOptimizeReport.heicFailed]。
class ImageOptimizer {
  ImageOptimizer._();

  static const _heifSuffixes = ['.heic', '.heif'];

  static Future<ImageOptimizeReport> run({
    void Function(int done, int total)? onProgress,
  }) async {
    final repo = DiaryRepository.get();
    // 只装引用了 HEIC 的那几篇，不把全库正文物化。总数在开跑前就齐：转码数 + 被引用
    // 图片数（改名不改数）。
    final heicDiaries = await repo.getDiariesReferencingMedia(
      kind: .image,
      suffixes: _heifSuffixes,
    );
    final heicTotal = heicDiaries.fold(
      0,
      (n, d) => n + d.imageName.where(_isHeif).length,
    );
    final total =
        heicTotal + (await repo.collectReferencedMedia()).images.length;
    var done = 0;
    onProgress?.call(done, total);

    var converted = 0;
    var failed = 0;
    for (final diary in heicDiaries) {
      final renamed = <String, String>{};
      for (final old in diary.imageName.where(_isHeif)) {
        final next = '${old.substring(0, old.lastIndexOf('.'))}.jpg';
        if (await _convert(old, next)) {
          renamed[old] = next;
          converted++;
        } else {
          failed++;
        }
        onProgress?.call(++done, total);
      }
      if (renamed.isEmpty) continue;
      var content = diary.content;
      renamed.forEach((old, next) => content = content.replaceAll(old, next));
      await repo.updateADiary(
        newDiary: withDerivedMedia(touched(diary.copyWith(content: content))),
      );
      // 只删旧原件：新旧同 uuid，派生物按 uuid 命名，`deleteImage` 会把刚为新文件生成的
      // 派生物一起删掉。
      for (final old in renamed.keys) {
        try {
          await File(AppFiles.getRealPath('image', old)).delete();
        } on PathNotFoundException {
          // 已不在。
        }
      }
    }

    // 转码后重收一次：名字已经是 .jpg 了。
    final images = (await repo.collectReferencedMedia()).images;
    for (final name in images) {
      final path = AppFiles.getRealPath('image', name);
      if (await File(path).exists()) await FastImageDerivatives.warm(path);
      onProgress?.call(++done, total);
    }

    return ImageOptimizeReport(
      images: images.length,
      heicConverted: converted,
      heicFailed: failed,
    );
  }

  /// 转到临时名再 rename：中途被杀不会留半个 jpg 被当成有效图。已存在同名 jpg
  /// （上次跑到一半正文没改成）直接复用。
  static Future<bool> _convert(String oldName, String newName) async {
    final src = AppFiles.getRealPath('image', oldName);
    final dst = AppFiles.getRealPath('image', newName);
    if (await File(dst).exists()) return true;
    if (!await File(src).exists()) return false;
    final part = AppFiles.getRealPath('image', 'heif-${uuidV7()}.jpg');
    try {
      final out = await IHeifDecoder.get().convert(
        src,
        outputPath: part,
        format: 'jpg',
      );
      if (out == null) return false;
      await File(part).rename(dst);
      return true;
    } catch (e) {
      logger.d('HEIC -> JPG failed: $oldName ($e)');
      return false;
    } finally {
      try {
        await File(part).delete();
      } catch (_) {}
    }
  }

  static bool _isHeif(String name) {
    final lower = name.toLowerCase();
    return _heifSuffixes.any(lower.endsWith);
  }
}

class ImageOptimizeReport {
  /// 检查过的图片总数（转码后按引用计）。
  final int images;

  final int heicConverted;

  final int heicFailed;

  const ImageOptimizeReport({
    required this.images,
    required this.heicConverted,
    required this.heicFailed,
  });
}
