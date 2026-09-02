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
/// 的源（贴纸类 PNG、透明 GIF）落 `.png` 保透明。后缀由**内容**定（后缀名可能撒谎：改名的
/// PNG、历史上按扩展名猜的格式），展示端两种都查。快慢路也按内容分：读三个魔数字节判
/// JPEG，不看扩展名。只给 [AppFiles.imageDir] 里的原件算派生物：视频封面之类走这里只会被
/// 孤儿扫描当野文件删掉，永远重算。
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

  /// progressive JPEG 超过看图页封顶（最长边 4096）才值得转一份 baseline：不超过的话引擎
  /// 整解就是全分辨率，用不着 tile。
  static const baselineMinPixels = 4096 * 4096;

  /// 展示端按需生成（JPEG 快路径）：turbojpeg 缩放解码，峰值几 MB，可以并行。与后台预热
  /// 分开排队，同步刚拉下几千张时，正在看的那一格不用排在它们后面。
  static final _onDemandGate = Pool(
    (Platform.numberOfProcessors ~/ 2).clamp(1, 4),
  );

  /// 后台预热的 JPEG 快路径。
  static final _warmGate = Pool(2);

  /// 其余格式全解：48MP 一张 144MB，两张并行就够低端 Android 被杀。
  static final _heavyGate = Pool(1);

  /// progressive → baseline 转码：整幅系数缓冲，一次一个；看图页等它，不和预热挤。
  static final _transcodeGate = Pool(1);

  /// 在飞的生成，按源图路径去重。
  static final _inflight = <String, Future<void>>{};

  /// 生成过一次仍不存在的档位（源图不比档位宽，Rust 跳过不写）。命中直接给原图，
  /// 不再进 Rust 读头。
  static final _absent = <String>{};

  static String _base(String imagePath) => basenameWithoutExtension(imagePath);

  /// 档位文件不带后缀的路径：`image/thumb/<uuid>_<width>`。
  static String tierStem(String imagePath, ImageTier tier) =>
      join(AppFiles.imageThumbDir, '${_base(imagePath)}_${tier.width}');

  /// 某档位可能存在的文件名（相对 thumb 目录），按优先级。后缀由内容定，两种都要查：
  /// 一张叫 `.jpg` 的带 alpha PNG 写出来就是 `.png`。
  static List<String> candidateNames(String imageName, ImageTier tier) {
    final stem = '${basenameWithoutExtension(imageName)}_${tier.width}';
    return [for (final ext in _exts) '$stem$ext'];
  }

  /// 只给原件目录里的文件算派生物。
  static bool _eligible(String imagePath) =>
      equals(dirname(imagePath), AppFiles.imageDir) && !_isHeif(imagePath);

  static List<String> candidatePaths(String imagePath, ImageTier tier) => [
    for (final name in candidateNames(imagePath, tier))
      join(AppFiles.imageThumbDir, name),
  ];

  /// progressive JPEG 的 baseline 副本：`image/thumb/<uuid>_base.jpg`，像素与原件逐字节相同、
  /// 带 restart marker，看图页 tile 只吃它（progressive 要整幅系数缓冲，不能区域解）。
  static String baselineName(String imageName) =>
      '${basenameWithoutExtension(imageName)}_base.jpg';

  static String baselinePath(String imagePath) =>
      join(AppFiles.imageThumbDir, baselineName(imagePath));

  /// 一张图的全部派生物文件名（相对 thumb 目录），两种后缀都算。删图与孤儿扫描共用。
  static List<String> derivativeNamesOf(String imageName) {
    final base = basenameWithoutExtension(imageName);
    return [
      for (final tier in ImageTier.values)
        for (final ext in _exts) '${base}_${tier.width}$ext',
      baselineName(imageName),
    ];
  }

  /// 某档位的可解码路径。要的档位在就给它；不在就往更大档找（m 顶 s 只多解几毫秒）；
  /// 都没有时，JPEG 源就地生成（快路径），其余给原图由 [MediaImage] 按档位宽夹住解。
  /// 这张图的预热若还在飞先等它 —— 刚导入的图正文立刻就要 m 档。
  static Future<String> resolve(
    String imagePath, {
    required ImageTier tier,
  }) async {
    if (!_eligible(imagePath)) return imagePath;
    final warming = _inflight[imagePath];
    if (warming != null) await warming;
    final hit = await _find(imagePath, tier);
    if (hit != null) return hit;
    if (_absent.contains(tierStem(imagePath, tier)) ||
        !await _sniffJpeg(imagePath)) {
      return imagePath;
    }
    // 按需只生成要的这一档（网格只要 s：12MP 解 2/8 再编 512，二十来毫秒）；
    // 其余档位随后由预热补齐，不挡这一格。同一张图在飞的生成只跑一路。
    await _dedup(imagePath, () => _generate(imagePath, only: tier, jpeg: true));
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
    if (!_eligible(imagePath)) return Future.value();
    return _dedup(imagePath, () async {
      final jpeg = await _sniffJpeg(imagePath);
      await _generate(imagePath, jpeg: jpeg);
    });
  }

  /// 同一张图同一时刻只跑一路生成：后来的等前一路结束再跑自己的（前一路可能只生成了
  /// 一档）。写盘侧另有保险：Rust 的临时文件名带进程号与序号，rename 原子。
  static Future<void> _dedup(String imagePath, Future<void> Function() job) {
    final running = _inflight[imagePath];
    if (running != null) {
      return running.then((_) => _dedup(imagePath, job));
    }
    final future = job();
    _inflight[imagePath] = future;
    unawaited(future.whenComplete(() => _inflight.remove(imagePath)));
    return future;
  }

  /// 读三个魔数字节判 JPEG：扩展名会撒谎，而快慢两条路的内存差一个量级。
  static Future<bool> _sniffJpeg(String path) async {
    try {
      final file = await File(path).open();
      try {
        final head = await file.read(3);
        return head.length == 3 &&
            head[0] == 0xFF &&
            head[1] == 0xD8 &&
            head[2] == 0xFF;
      } finally {
        await file.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// 看图页要的 baseline 副本：在就给；不在就现转（重闸门，24MP 约一秒，期间看图页先用
  /// 打底图）；转不了（超过 64MP、非 progressive）给 null，由看图页退回整图封顶路径。
  static Future<String?> ensureBaseline(String imagePath) async {
    if (!_eligible(imagePath)) return null;
    final path = baselinePath(imagePath);
    if (await File(path).exists()) return path;
    if (_absent.contains(path)) return null;
    await _generateBaseline(imagePath);
    return await File(path).exists() ? path : null;
  }

  /// 超过看图页封顶的 progressive JPEG 至少有这么大；小于它的连头都不用读。
  static const _baselineMinBytes = 2 * 1024 * 1024;

  static Future<void> _generateBaseline(String src) async {
    final path = baselinePath(src);
    try {
      if (_absent.contains(path) || await File(path).exists()) return;
      if (await File(src).length() < _baselineMinBytes) return;
      // 读头在闸门外：便宜，别占着转码的位子。不够格的不记 [_absent]（读头就够便宜），
      // 只记转失败的。
      final probe = await rust.ImageCompressor.probe(filePath: src);
      if (!probe.progressive ||
          probe.width * probe.height <= baselineMinPixels) {
        return;
      }
      await _transcodeGate.withResource(() async {
        if (await File(path).exists()) return;
        await rust.ImageCompressor.toBaselineFile(
          filePath: src,
          outputPath: path,
        );
      });
    } catch (e) {
      _absent.add(path);
      logger.d('baseline transcode failed: $src ($e)');
    }
  }

  /// 查档、生成全在闸门里：同步一次拉几千张时它们都挤在这里，不会几千个句柄同时
  /// 打开（iOS 的软上限只有 256）。[only] 给了就只生成这一档。源图不比档位宽的档位
  /// Rust 侧跳过不写，这里记进 [_absent]。整预热（[only] 为空）顺带给大 progressive
  /// JPEG 转 baseline 副本。
  static Future<void> _generate(
    String src, {
    ImageTier? only,
    required bool jpeg,
  }) async {
    if (only == null && jpeg) {
      unawaited(_generateBaseline(src));
    }
    final gate = only != null
        ? _onDemandGate
        : jpeg
        ? _warmGate
        : _heavyGate;
    final targets = <rust.ThumbnailTarget>[];
    try {
      await gate.withResource(() async {
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
      // 解不了的文件（后缀撒谎的 AVIF、坏文件）记进 [_absent]：不然每次滚过这一格都再解一遍。
      for (final target in targets) {
        _absent.add(target.outputStem);
      }
      logger.d('thumbnail generate failed: $src ($e)');
    }
  }

  /// 删图连带删派生物。
  static Future<void> deleteFor(String imageName) async {
    for (final tier in ImageTier.values) {
      _absent.remove(tierStem(imageName, tier));
    }
    _absent.remove(baselinePath(imageName));
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
    final now = DateTime.now();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      if (!_exts.contains(extension(name).toLowerCase())) {
        // 正在写的临时文件放过：扫描是用户在媒体页手动触发的，那一页自己的网格可能正在生成。
        if (name.endsWith('.part')) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) < _partGrace) continue;
        }
        out.add(entity.path);
        continue;
      }
      final sep = name.lastIndexOf('_');
      if (sep <= 0) continue;
      if (!alive.contains(name.substring(0, sep))) out.add(entity.path);
    }
    return out;
  }

  /// 比这新的 `.part` 当成还在写。
  static const _partGrace = Duration(hours: 1);

  static bool _isHeif(String path) {
    final ext = extension(path).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }
}
