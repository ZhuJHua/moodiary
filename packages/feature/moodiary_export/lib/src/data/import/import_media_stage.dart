import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

enum ImportMediaKind { image, video, audio }

/// 把包里的媒体文件收进应用目录，返回入库文件名（`image-` / `video-` / `audio-` 前缀）；
/// 失败返回 null。抽成接口是为了让编排层的测试不碰真实媒体管线。
abstract interface class ImportMediaStore {
  Future<String?> save(String path, ImportMediaKind kind);
}

/// 真实现：与编辑器插入媒体走同一条管线，但**默认拷贝重命名** —— 本 App 导出的包里
/// 素材就叫 `image-<uuid>.jpg`，MediaManager 会把这种名字当成「已在本机目录里」直接
/// 复用，换一台设备导入就是一堆指向不存在文件的引用。
///
/// 唯一复用的情形：包里的名字已是本 App 形制，本机同名文件**存在且内容一致**
/// （[sameFileContent]）—— 那就是同一个文件（日记删了媒体还没清理、手改过 front matter
/// 之类），不再多落一份。
class AppImportMediaStore implements ImportMediaStore {
  const AppImportMediaStore();

  @override
  Future<String?> save(String path, ImportMediaKind kind) async {
    if (await _reuseLocal(path, kind) case final name?) return name;
    switch (kind) {
      case .image:
        return MediaManager.saveImage(XFile(path), reuseExisting: false);
      case .video:
        final saved = await MediaManager.saveVideo(
          videoFileList: [XFile(path)],
          reuseExisting: false,
        );
        return saved[path];
      case .audio:
        return _saveAudio(path);
    }
  }

  Future<String?> _reuseLocal(String path, ImportMediaKind kind) async {
    final name = p.basename(path);
    if (!name.startsWith('${kind.name}-')) return null;
    final local = File(AppFiles.getRealPath(kind.name, name));
    if (!local.existsSync()) return null;
    if (!await sameFileContent(File(path), local)) return null;
    switch (kind) {
      case .image:
        return name;
      case .video:
        // 没封面就当没有：重新拷一份会顺带生成封面，比补一条重生成链路省事。
        return File(AppFiles.getRealPath('thumbnail', name)).existsSync()
            ? name
            : null;
      case .audio:
        final repo = getIt<MediaInfoRepository>();
        if (await repo.getMediaInfoByFileName(name) == null) {
          final duration = await probeAudioDuration(local.path);
          await repo.insertAMediaInfo(
            MediaInfo.create(
              fileName: name,
              name: p.basenameWithoutExtension(path),
              durationMs: duration?.inMilliseconds,
            ),
          );
        }
        return name;
    }
  }

  /// 「内容一致」= 长度相等且 [sampleDigest] 相同。
  static Future<bool> sameFileContent(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    return await sampleDigest(a) == await sampleDigest(b);
  }

  /// 抽样指纹：长度 + 头 / 中 / 尾各 [sampleBytes] 字节做 md5。不读整个文件 —— 视频
  /// 几百 MB 全量哈希是秒级；名字已经是 uuid，三段抽样足以把「同名不同文件」排掉。
  static Future<Digest> sampleDigest(File file) async {
    final length = await file.length();
    final raf = await file.open();
    try {
      final bytes = BytesBuilder(copy: false)..add(_lengthBytes(length));
      for (final start in _sampleOffsets(length)) {
        await raf.setPosition(start);
        bytes.add(await raf.read(sampleBytes));
      }
      return md5.convert(bytes.takeBytes());
    } finally {
      await raf.close();
    }
  }

  static const int sampleBytes = 64 * 1024;

  /// 头、中、尾三段的起点；文件短到彼此重叠时去重，不足一段就整个读。
  static List<int> _sampleOffsets(int length) {
    if (length <= sampleBytes) return const [0];
    final middle = (length - sampleBytes) ~/ 2;
    final tail = length - sampleBytes;
    return {0, middle, tail}.toList();
  }

  static List<int> _lengthBytes(int length) => [
    for (var i = 0; i < 8; i++) (length >> (8 * i)) & 0xff,
  ];

  /// 仿编辑器 `_pickAudioFile`：原字节拷贝、命名 `audio-<uuid>.<ext>`，原文件名作显示名
  /// 与时长一起落 MediaInfo。探不出时长的文件按坏文件拒绝（同编辑器的导入闸门）。
  Future<String?> _saveAudio(String path) async {
    final ext = p.extension(path).toLowerCase();
    final name = 'audio-${uuidV7()}$ext';
    final target = AppFiles.getRealPath('audio', name);
    try {
      await File(path).copy(target);
      final duration = await probeAudioDuration(target);
      if (duration == null) {
        await AppFiles.deleteFile(target);
        return null;
      }
      await getIt<MediaInfoRepository>().insertAMediaInfo(
        MediaInfo.create(
          fileName: name,
          name: p.basenameWithoutExtension(path),
          durationMs: duration.inMilliseconds,
        ),
      );
      return name;
    } catch (e, st) {
      logger.e('导入音频失败：$path', error: e, stackTrace: st);
      await AppFiles.deleteFile(target);
      return null;
    }
  }
}

/// 正文里的媒体引用 → 入库文件名的改写。**必须在 markdown → tiptap 转换之前跑**：
/// `MarkdownToTiptap` 按 `image-` / `video-` / `audio-` 前缀把 `![](name)` 分流成一等节点，
/// 改写后 `withDerivedMedia` 才数得出三列。
///
/// 只认相对路径（无 scheme、非锚点），相对于该 md 文件所在目录解析，规范化后必须仍在
/// 包目录内。收不进来的引用（越界 / 缺文件 / 认不出类型 / 入库失败）若写的是图片语法，
/// 降级成普通链接 —— 否则转换器会把 `![](assets/x.jpg)` 变成一个指向不存在文件的图片
/// 节点，还会被 `withDerivedMedia` 数进 imageName。缺文件与入库失败计入 [missing]。
/// 同一素材被多篇引用只落一次。
class ImportMediaStage {
  final Directory _root;
  final ImportMediaStore _store;
  final Map<String, String?> _saved = {};

  /// 引用了但没能收进来的次数（缺文件 / 坏文件 / 类型不明）。
  int missing = 0;

  ImportMediaStage(this._root, this._store);

  static final RegExp _link = RegExp(
    r'(!?)\[([^\]]*)\]\(\s*(<[^>]*>|[^\s)]+)(?:\s+"[^"]*")?\s*\)',
  );
  static final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');

  static const _imageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  };
  static const _videoExts = {'.mp4', '.mov', '.m4v', '.webm', '.mkv', '.3gp'};
  static const _audioExts = {
    '.m4a',
    '.mp3',
    '.aac',
    '.wav',
    '.ogg',
    '.oga',
    '.opus',
    '.flac',
    '.amr',
  };

  static ImportMediaKind? kindOf(String path) {
    final ext = p.extension(path).toLowerCase();
    if (_imageExts.contains(ext)) return .image;
    if (_videoExts.contains(ext)) return .video;
    if (_audioExts.contains(ext)) return .audio;
    return null;
  }

  Future<String> rewrite(String markdown, String markdownPath) async {
    final dir = p.dirname(markdownPath);
    final out = StringBuffer();
    var last = 0;
    for (final m in _link.allMatches(markdown)) {
      out.write(markdown.substring(last, m.start));
      last = m.end;
      final replaced = await _replace(m, dir);
      out.write(replaced ?? m.group(0));
    }
    out.write(markdown.substring(last));
    return out.toString();
  }

  Future<String?> _replace(RegExpMatch m, String dir) async {
    final raw = m.group(3)!;
    var target = raw;
    if (target.startsWith('<')) target = target.substring(1, target.length - 1);
    if (target.isEmpty || target.startsWith('#') || _scheme.hasMatch(target)) {
      return null;
    }
    // 图片语法但收不进来：降成普通链接，别留下坏图片节点。
    final degraded = m.group(1) == '!' ? '[${m.group(2)}]($raw)' : null;
    try {
      target = Uri.decodeComponent(target);
    } catch (_) {
      /* 不是合法百分号编码，按字面用 */
    }
    if (p.isAbsolute(target)) return degraded;

    final resolved = p.normalize(p.join(dir, target));
    if (!p.isWithin(_root.path, resolved) && resolved != _root.path) {
      return degraded;
    }
    // 指向包内非媒体文件（说明 pdf 之类）的链接不是媒体引用，不计缺失。
    final kind = kindOf(resolved);
    if (kind == null) return degraded;
    if (!File(resolved).existsSync()) {
      missing++;
      return degraded;
    }
    final name = await _save(resolved, kind);
    if (name == null) {
      missing++;
      return degraded;
    }
    // 三类统一写成图片语法，转换器按文件名前缀分流；视频 / 音频没有 alt。
    final alt = kind == .image ? m.group(2)! : '';
    return '![$alt]($name)';
  }

  Future<String?> _save(String path, ImportMediaKind kind) async {
    if (_saved.containsKey(path)) return _saved[path];
    final name = await _store.save(path, kind);
    _saved[path] = name;
    return name;
  }
}
