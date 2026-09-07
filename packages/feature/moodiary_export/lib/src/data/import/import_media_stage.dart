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

abstract interface class ImportMediaStore {
  Future<String?> save(String path, ImportMediaKind kind);
}

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

  static Future<bool> sameFileContent(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    return await sampleDigest(a) == await sampleDigest(b);
  }

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

  static List<int> _sampleOffsets(int length) {
    if (length <= sampleBytes) return const [0];
    final middle = (length - sampleBytes) ~/ 2;
    final tail = length - sampleBytes;
    return {0, middle, tail}.toList();
  }

  static List<int> _lengthBytes(int length) => [
    for (var i = 0; i < 8; i++) (length >> (8 * i)) & 0xff,
  ];

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

// 必须在 markdown → tiptap 转换之前跑：MarkdownToTiptap 按前缀分流媒体节点
class ImportMediaStage {
  final Directory _root;
  final ImportMediaStore _store;
  final Map<String, String?> _saved = {};

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
    final degraded = m.group(1) == '!' ? '[${m.group(2)}]($raw)' : null;
    try {
      target = Uri.decodeComponent(target);
    } catch (_) {
    }
    if (p.isAbsolute(target)) return degraded;

    final resolved = p.normalize(p.join(dir, target));
    if (!p.isWithin(_root.path, resolved) && resolved != _root.path) {
      return degraded;
    }
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
