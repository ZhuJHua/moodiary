import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:pool/pool.dart';

import 'runtime.dart';
import 'rust/api/image.dart';

enum FastImageTier {
  s(512),
  m(1280);

  final int width;

  const FastImageTier(this.width);

  static FastImageTier fit(int width) {
    for (final tier in values) {
      if (width <= tier.width) return tier;
    }
    return values.last;
  }
}

class FastImageDerivatives {
  FastImageDerivatives._();

  static const _thumbQuality = 82;

  static const _exts = ['.jpg', '.png'];

  static const baselineMinPixels = 4096 * 4096;

  static final _onDemandGate = Pool(
    (Platform.numberOfProcessors ~/ 2).clamp(1, 4),
  );

  static final _warmGate = Pool(2);

  static final _heavyGate = Pool(1);

  static final _transcodeGate = Pool(1);

  static final _inflight = <String, Future<void>>{};

  static final _absent = <String>{};

  static String _base(String imagePath) => basenameWithoutExtension(imagePath);

  static String tierStem(String imagePath, FastImageTier tier) =>
      join(FastImageRuntime.thumbDir, '${_base(imagePath)}_${tier.width}');

  static List<String> candidateNames(String imageName, FastImageTier tier) {
    final stem = '${basenameWithoutExtension(imageName)}_${tier.width}';
    return [for (final ext in _exts) '$stem$ext'];
  }

  static bool _eligible(String imagePath) =>
      equals(dirname(imagePath), FastImageRuntime.imageDir) &&
      !_isHeif(imagePath);

  static List<String> candidatePaths(String imagePath, FastImageTier tier) => [
    for (final name in candidateNames(imagePath, tier))
      join(FastImageRuntime.thumbDir, name),
  ];

  static String baselineName(String imageName) =>
      '${basenameWithoutExtension(imageName)}_base.jpg';

  static String baselinePath(String imagePath) =>
      join(FastImageRuntime.thumbDir, baselineName(imagePath));

  static List<String> derivativeNamesOf(String imageName) {
    final base = basenameWithoutExtension(imageName);
    return [
      for (final tier in FastImageTier.values)
        for (final ext in _exts) '${base}_${tier.width}$ext',
      baselineName(imageName),
    ];
  }

  static Future<String> resolve(
    String imagePath, {
    required FastImageTier tier,
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
    await _dedup(imagePath, () => _generate(imagePath, only: tier, jpeg: true));
    unawaited(warm(imagePath));
    return await _find(imagePath, tier) ?? imagePath;
  }

  static Future<String?> _find(String imagePath, FastImageTier tier) async {
    for (final candidate in FastImageTier.values) {
      if (candidate.width < tier.width) continue;
      for (final path in candidatePaths(imagePath, candidate)) {
        if (await File(path).exists()) return path;
      }
    }
    return null;
  }

  static Future<void> warm(String imagePath) {
    if (!_eligible(imagePath)) return Future.value();
    return _dedup(imagePath, () async {
      final jpeg = await _sniffJpeg(imagePath);
      await _generate(imagePath, jpeg: jpeg);
    });
  }

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

  static Future<bool> _sniffJpeg(String path) async {
    try {
      final file = await File(path).open();
      try {
        final head = await file.read(3);
        // 0xFFD8FF 是 JPEG 魔数（前三字节）
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

  static Future<String?> ensureBaseline(String imagePath) async {
    if (!_eligible(imagePath)) return null;
    final path = baselinePath(imagePath);
    if (await File(path).exists()) return path;
    if (_absent.contains(path)) return null;
    await _generateBaseline(imagePath);
    return await File(path).exists() ? path : null;
  }

  static const _baselineMinBytes = 2 * 1024 * 1024;

  static Future<void> _generateBaseline(String src) async {
    final path = baselinePath(src);
    try {
      if (_absent.contains(path) || await File(path).exists()) return;
      if (await File(src).length() < _baselineMinBytes) return;
      final probe = await FastImageCodec.probe(filePath: src);
      if (!probe.progressive ||
          probe.width * probe.height <= baselineMinPixels) {
        return;
      }
      await _transcodeGate.withResource(() async {
        if (await File(path).exists()) return;
        await FastImageCodec.toBaselineFile(filePath: src, outputPath: path);
      });
    } catch (e) {
      _absent.add(path);
      FastImageRuntime.log('baseline transcode failed: $src ($e)');
    }
  }

  static Future<void> _generate(
    String src, {
    FastImageTier? only,
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
    final targets = <FastThumbnailTarget>[];
    try {
      await gate.withResource(() async {
        for (final tier in FastImageTier.values) {
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
          targets.add(FastThumbnailTarget(width: tier.width, outputStem: stem));
        }
        if (targets.isEmpty) return;
        final meta = await FastImageCodec.makeThumbnails(
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
      for (final target in targets) {
        _absent.add(target.outputStem);
      }
      FastImageRuntime.log('thumbnail generate failed: $src ($e)');
    }
  }

  static Future<void> deleteFor(String imageName) async {
    for (final tier in FastImageTier.values) {
      _absent.remove(tierStem(imageName, tier));
    }
    _absent.remove(baselinePath(imageName));
    for (final name in derivativeNamesOf(imageName)) {
      final path = join(FastImageRuntime.thumbDir, name);
      try {
        await File(path).delete();
      } on PathNotFoundException {
        // 没生成过。
      } catch (e) {
        FastImageRuntime.log('delete derivative failed: $path ($e)');
      }
    }
  }

  static Future<List<String>> stale(Iterable<String> imageNames) async {
    final dir = Directory(FastImageRuntime.thumbDir);
    if (!await dir.exists()) return const [];
    final alive = {for (final n in imageNames) basenameWithoutExtension(n)};
    final out = <String>[];
    final now = DateTime.now();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      if (!_exts.contains(extension(name).toLowerCase())) {
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

  static const _partGrace = Duration(hours: 1);

  static bool _isHeif(String path) {
    final ext = extension(path).toLowerCase();
    return ext == '.heic' || ext == '.heif';
  }
}
