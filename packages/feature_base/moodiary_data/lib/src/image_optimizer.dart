import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'diary_derive.dart';
import 'diary_repository.dart';

class ImageOptimizer {
  ImageOptimizer._();

  static const _heifSuffixes = ['.heic', '.heif'];

  static Future<ImageOptimizeReport> run({
    void Function(int done, int total)? onProgress,
  }) async {
    final repo = getIt<DiaryRepository>();
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
      for (final old in renamed.keys) {
        try {
          await File(AppFiles.getRealPath('image', old)).delete();
        } on PathNotFoundException {
          // 已不在。
        }
      }
    }

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

  static Future<bool> _convert(String oldName, String newName) async {
    final src = AppFiles.getRealPath('image', oldName);
    final dst = AppFiles.getRealPath('image', newName);
    if (await File(dst).exists()) return true;
    if (!await File(src).exists()) return false;
    final part = AppFiles.getRealPath('image', 'heif-${uuidV7()}.jpg');
    try {
      final out = await getIt<IHeifDecoder>().convert(
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
  final int images;

  final int heicConverted;

  final int heicFailed;

  const ImageOptimizeReport({
    required this.images,
    required this.heicConverted,
    required this.heicFailed,
  });
}
