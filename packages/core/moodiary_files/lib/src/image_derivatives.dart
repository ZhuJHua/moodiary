import 'dart:async';
import 'dart:io';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';

import 'app_files.dart';

/// 缩略图档位（宽度，物理像素）。只留两档：全仓展示点都落在这两个尺寸里 ——
/// s 给网格 / 日历 / 首页多图格，m 给编辑器正文 / 首页单图 / 看图页占位帧。
/// 第三档省不下解码，只多一份盘。
enum ImageTier {
  s(512),
  m(1280);

  final int width;

  const ImageTier(this.width);

  /// 随布局变化的容器按显示宽（物理像素）取档：向上取，比最大档还宽也只给最大档 ——
  /// 列表里永远不解原图，平板一整行宽也是 m。缓存键因此只在跨档时才变。
  static ImageTier fit(int width) {
    for (final tier in values) {
      if (width <= tier.width) return tier;
    }
    return values.last;
  }
}

/// 图片派生物：原图一个字节不动，展示端只碰派生物。
///
/// 缩略图（[resolve] / [warm]）：原图现在是全分辨率原件，网格里直接解它是「图一多就卡」
/// 的根子（一屏十几格，每格全量熵解码），也是内存炸点（12MP 一张 48MB 位图）。按
/// [ImageTier] 由 Rust 一次解码链式缩出 WebP 落盘。
///
/// 历史 `.heic`（旧版本按源格式原样落盘）这里**不做**任何转码：Rust 解不了它，展示端
/// 拿到的就是原路径、照旧破图，直到用户在「设置 → 数据 → 图片优化」里一次性转成 JPG
/// （`ImageOptimizer`）。曾经做过「取用时偷偷转一份展示副本」，去掉了 —— 两套并存时
/// 正文里的名字与磁盘上的格式各说各话，只留一条用户可见的路。
///
/// 全部落在 `image/thumb/`（support 目录，不是 cache）：从全分辨率原件重算一次太贵，
/// 不能让系统清缓存清掉。**不同步、不进备份**，谁拿到原图谁自己算；删图连带删
/// （[deleteFor]），漏网的由孤儿扫描兜底（[stale]）。
class ImageDerivatives {
  ImageDerivatives._();

  static const _thumbQuality = 78;

  /// 生成闸门 `Pool(1)`：原图是全分辨率原件，Rust `image` 的 JPEG 解码没有 DCT
  /// 缩放，48MP 一张解出来 144MB —— 两张并行就够低端 Android 被杀。
  static final _gate = Pool(1);

  /// 在飞的生成任务，按产物路径去重：同一张图的网格格子与看图页会同时开口。
  static final _inflight = <String, Future<String>>{};

  /// 生成不出来（或不值得生成：源图不比档位宽）的产物路径。命中直接回退，不重试。
  static final _unavailable = <String>{};

  static String _base(String imagePath) => basenameWithoutExtension(imagePath);

  /// 档位文件路径：`image/thumb/<uuid>_<width>.webp`。
  static String tierPath(String imagePath, ImageTier tier) =>
      join(AppFiles.imageThumbDir, '${_base(imagePath)}_${tier.width}.webp');

  /// 一张图的全部派生物文件名（相对 thumb 目录）。删图与孤儿扫描共用这一份清单。
  static List<String> derivativeNamesOf(String imageName) {
    final base = basenameWithoutExtension(imageName);
    return [for (final tier in ImageTier.values) '${base}_${tier.width}.webp'];
  }

  /// 某档位的可解码路径。档位文件在就直接给；源图不比档位宽给原图（它本来就小）；
  /// 缺则就地生成 —— 从最近的更大档位缩，不碰原图；生成失败（含 HEIC）回退原路径。
  static Future<String> resolve(
    String imagePath, {
    required ImageTier tier,
  }) async {
    final src = imagePath;
    if (_isHeif(src)) return src;
    final out = tierPath(imagePath, tier);
    if (_unavailable.contains(out)) return src;
    if (await File(out).exists()) return out;
    return _once(out, () async {
      try {
        final (srcWidth, _) = await ImageSizeManager().getSizeAsync(src);
        if (srcWidth <= tier.width) {
          _unavailable.add(out);
          return src;
        }
        var from = src;
        for (final larger in ImageTier.values.reversed) {
          if (larger.width <= tier.width) break;
          final candidate = tierPath(imagePath, larger);
          if (await File(candidate).exists()) {
            from = candidate;
            break;
          }
        }
        await _gate.withResource(
          () => rust.ImageCompressor.makeThumbnails(
            filePath: from,
            targets: [rust.ThumbnailTarget(width: tier.width, outputPath: out)],
            quality: _thumbQuality,
          ),
        );
        if (await File(out).exists()) return out;
      } catch (e) {
        logger.d('thumbnail failed: $imagePath/${tier.name} ($e)');
      }
      _unavailable.add(out);
      return src;
    });
  }

  /// 预热：把所有还缺的档位一次解码链式生成。导入完成、同步拉图完成后 fire-and-forget；
  /// 没跑完就被杀也没关系，[resolve] 会按需补。
  static Future<void> warm(String imagePath) async {
    final key = '$imagePath#warm';
    if (_inflight.containsKey(key)) return;
    await _once(key, () async {
      try {
        final src = imagePath;
        if (_isHeif(src)) return '';
        final (srcWidth, _) = await ImageSizeManager().getSizeAsync(src);
        final targets = <rust.ThumbnailTarget>[];
        for (final tier in ImageTier.values) {
          final out = tierPath(imagePath, tier);
          if (srcWidth <= tier.width) {
            _unavailable.add(out);
            continue;
          }
          if (_unavailable.contains(out) || await File(out).exists()) continue;
          targets.add(rust.ThumbnailTarget(width: tier.width, outputPath: out));
        }
        if (targets.isEmpty) return '';
        await _gate.withResource(
          () => rust.ImageCompressor.makeThumbnails(
            filePath: src,
            targets: targets,
            quality: _thumbQuality,
          ),
        );
      } catch (e) {
        logger.d('thumbnail warm failed: $imagePath ($e)');
      }
      return '';
    });
  }

  /// 删图连带删派生物。
  static Future<void> deleteFor(String imageName) async {
    for (final name in derivativeNamesOf(imageName)) {
      final path = join(AppFiles.imageThumbDir, name);
      _unavailable.remove(path);
      try {
        await File(path).delete();
      } on PathNotFoundException {
        // 没生成过。
      } catch (e) {
        logger.d('delete derivative failed: $path ($e)');
      }
    }
  }

  /// thumb 目录里源图已不存在的派生物（绝对路径）。[imageNames] 为 image 目录现存
  /// 文件名。派生物名里不带源图后缀，按去后缀的 uuid 对账。
  static Future<List<String>> stale(Iterable<String> imageNames) async {
    final dir = Directory(AppFiles.imageThumbDir);
    if (!await dir.exists()) return const [];
    final alive = {for (final n in imageNames) basenameWithoutExtension(n)};
    final out = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      final sep = name.lastIndexOf('_');
      if (sep <= 0) continue;
      if (!alive.contains(name.substring(0, sep))) out.add(entity.path);
    }
    return out;
  }

  static bool _isHeif(String path) {
    final ext = extension(path).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }

  static Future<String> _once(String key, Future<String> Function() build) {
    final running = _inflight[key];
    if (running != null) return running;
    final future = build();
    _inflight[key] = future;
    unawaited(future.whenComplete(() => _inflight.remove(key)));
    return future;
  }
}
