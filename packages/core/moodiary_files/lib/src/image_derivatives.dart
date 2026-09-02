import 'dart:async';
import 'dart:io';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
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
/// 缩略图按 [ImageTier] 由 Rust 一次解码链式缩出，落 `image/thumb/<uuid>_<w>.jpg`；带 alpha
/// 的源（贴纸类 PNG、透明 GIF）落 `.png` 保透明。后缀由内容定，展示端不探测：源是 `.jpg`
/// 只认 `.jpg`，其余先查 `.jpg` 再查 `.png`。
///
/// **生成分快慢两条路**：JPEG 源走 turbojpeg 按 1/N 缩放解码，12MP 约 20ms、48MP 峰值约
/// 2MB，可以并行、可以在展示端按需生成；其余格式走 image 全解（48MP 144MB），只由导入 /
/// 同步拉图的预热与「图片优化」生成，永远不在滚动路径上。
///
/// 历史 `.heic` 这里**不做**任何转码：Rust 解不了它，展示端拿到的就是原路径，直到用户在
/// 「设置 → 数据 → 图片优化」里一次性转成 JPG（`ImageOptimizer`）。
///
/// 全部落在 `image/thumb/`（support 目录，不是 cache）：从全分辨率原件重算一次太贵，
/// 不能让系统清缓存清掉。**不同步、不进备份**，谁拿到原图谁自己算；删图连带删
/// （[deleteFor]），漏网的由孤儿扫描兜底（[stale]）。
class ImageDerivatives {
  ImageDerivatives._();

  static const _thumbQuality = 82;

  /// 派生物只可能是这两种后缀；别的（开发期的 `.webp`）一律算 stale。
  static const _exts = ['.jpg', '.png'];

  /// JPEG 快路径：turbojpeg 缩放解码，峰值几 MB，可以并行。
  static final _jpegGate = Pool((Platform.numberOfProcessors ~/ 2).clamp(1, 4));

  /// 其余格式全解：48MP 一张 144MB，两张并行就够低端 Android 被杀。
  static final _heavyGate = Pool(1);

  /// 在飞的生成，按源图路径去重。
  static final _inflight = <String, Future<void>>{};

  /// 生成过一次仍不存在的档位（源图不比档位宽，Rust 跳过不写）。命中直接给原图，
  /// 不再进 Rust 读头。
  static final _absent = <String>{};

  static String _base(String imagePath) => basenameWithoutExtension(imagePath);

  /// 档位文件不带后缀的路径：`image/thumb/<uuid>_<width>`。
  static String tierStem(String imagePath, ImageTier tier) =>
      join(AppFiles.imageThumbDir, '${_base(imagePath)}_${tier.width}');

  /// 某档位可能存在的文件名（相对 thumb 目录），按优先级。源是 JPEG 的派生物只会是 `.jpg`。
  static List<String> candidateNames(String imageName, ImageTier tier) {
    final stem = '${basenameWithoutExtension(imageName)}_${tier.width}';
    if (_isJpeg(imageName)) return ['$stem.jpg'];
    return [for (final ext in _exts) '$stem$ext'];
  }

  static List<String> candidatePaths(String imagePath, ImageTier tier) => [
    for (final name in candidateNames(imagePath, tier))
      join(AppFiles.imageThumbDir, name),
  ];

  /// 一张图的全部派生物文件名（相对 thumb 目录），两种后缀都算。删图与孤儿扫描共用。
  static List<String> derivativeNamesOf(String imageName) {
    final base = basenameWithoutExtension(imageName);
    return [
      for (final tier in ImageTier.values)
        for (final ext in _exts) '${base}_${tier.width}$ext',
    ];
  }

  /// 某档位的可解码路径。要的档位在就给它；不在就往更大档找（m 顶 s 只多解几毫秒）；
  /// 都没有时，JPEG 源就地生成（快路径），其余给原图由 [MediaImage] 按档位宽夹住解。
  /// 这张图的预热若还在飞先等它 —— 刚导入的图正文立刻就要 m 档。
  static Future<String> resolve(
    String imagePath, {
    required ImageTier tier,
  }) async {
    final warming = _inflight[imagePath];
    if (warming != null) await warming;
    final hit = await _find(imagePath, tier);
    if (hit != null) return hit;
    if (!_isJpeg(imagePath) || _absent.contains(tierStem(imagePath, tier))) {
      return imagePath;
    }
    // 按需只生成要的这一档（网格只要 s：12MP 解 1/6 再编 512，二十来毫秒）；
    // 其余档位随后在同一闸门里排队补齐，不挡这一格。
    await _generate(imagePath, only: tier);
    unawaited(warm(imagePath));
    return await _find(imagePath, tier) ?? imagePath;
  }

  static Future<String?> _find(String imagePath, ImageTier tier) async {
    for (final candidate in ImageTier.values) {
      if (candidate.width < tier.width) continue;
      for (final path in candidatePaths(imagePath, candidate)) {
        if (await File(path).exists()) return path;
      }
    }
    return null;
  }

  /// 预热：把所有还缺的档位一次解码链式生成。同一张图在飞的复用；没跑完就被杀也
  /// 没关系，展示端会退回原图或按需补。
  static Future<void> warm(String imagePath) {
    final running = _inflight[imagePath];
    if (running != null) return running;
    final future = _generate(imagePath);
    _inflight[imagePath] = future;
    unawaited(future.whenComplete(() => _inflight.remove(imagePath)));
    return future;
  }

  /// 查档、生成全在闸门里：同步一次拉几千张时它们都挤在这里，不会几千个句柄同时
  /// 打开（iOS 的软上限只有 256）。[only] 给了就只生成这一档。源图不比档位宽的档位
  /// Rust 侧跳过不写，这里记进 [_absent]。
  static Future<void> _generate(String src, {ImageTier? only}) async {
    if (_isHeif(src)) return;
    final gate = _isJpeg(src) ? _jpegGate : _heavyGate;
    try {
      await gate.withResource(() async {
        final targets = <rust.ThumbnailTarget>[];
        for (final tier in ImageTier.values) {
          if (only != null && tier != only) continue;
          final stem = tierStem(src, tier);
          if (_absent.contains(stem)) continue;
          var present = false;
          for (final path in candidatePaths(src, tier)) {
            if (await File(path).exists()) {
              present = true;
              break;
            }
          }
          if (present) continue;
          targets.add(
            rust.ThumbnailTarget(width: tier.width, outputStem: stem),
          );
        }
        if (targets.isEmpty) return;
        final meta = await rust.ImageCompressor.makeThumbnails(
          filePath: src,
          targets: targets,
          quality: _thumbQuality,
        );
        for (final target in targets) {
          if (!await File('${target.outputStem}.${meta.ext}').exists()) {
            _absent.add(target.outputStem);
          }
        }
      });
    } catch (e) {
      logger.d('thumbnail generate failed: $src ($e)');
    }
  }

  /// 删图连带删派生物。
  static Future<void> deleteFor(String imageName) async {
    for (final tier in ImageTier.values) {
      _absent.remove(tierStem(imageName, tier));
    }
    for (final name in derivativeNamesOf(imageName)) {
      final path = join(AppFiles.imageThumbDir, name);
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
  /// 文件名。派生物名里不带源图后缀，按去后缀的 uuid 对账；写到一半的 `.part` 与
  /// 不认识的后缀一律算。
  static Future<List<String>> stale(Iterable<String> imageNames) async {
    final dir = Directory(AppFiles.imageThumbDir);
    if (!await dir.exists()) return const [];
    final alive = {for (final n in imageNames) basenameWithoutExtension(n)};
    final out = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      if (!_exts.contains(extension(name).toLowerCase())) {
        out.add(entity.path);
        continue;
      }
      final sep = name.lastIndexOf('_');
      if (sep <= 0) continue;
      if (!alive.contains(name.substring(0, sep))) out.add(entity.path);
    }
    return out;
  }

  static bool _isJpeg(String path) {
    final ext = extension(path).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg';
  }

  static bool _isHeif(String path) {
    final ext = extension(path).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }
}
