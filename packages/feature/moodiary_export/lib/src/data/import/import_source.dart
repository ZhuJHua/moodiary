import 'dart:io';

import 'package:fast_zip/fast_zip.dart' as archive;
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:path/path.dart' as p;

/// 待导入的一篇：工作目录里的一个顶层 `.md`。
class MarkdownEntryFile {
  final String path;

  String get name => p.basename(path);

  const MarkdownEntryFile(this.path);
}

/// 解压 / 拷贝到缓存目录后的导入包。
///
/// 规范：**顶层的 `*.md` 各是一篇**，子目录里的不算（`assets/` 里的说明文件不该变成日记）；
/// 媒体在 `assets/`（子目录任意），正文里按相对路径引用。zip 由 fast_zip 解压，Rust 侧走
/// `enclosed_name()`，`../` 这类条目进不来。
class MarkdownImportSource {
  /// 相对路径的解析根 —— 顶层 `.md` 所在目录。
  final Directory root;

  final List<MarkdownEntryFile> entries;

  /// 整个工作目录（[root] 可能是它的子目录）。
  final Directory _workDir;

  const MarkdownImportSource._(this.root, this.entries, this._workDir);

  int get count => entries.length;

  /// 直接扫描一个已经摆好的目录（测试与预演用），不经解压。[dispose] 同样会删掉它。
  factory MarkdownImportSource.scan(Directory root) =>
      MarkdownImportSource._(root, _scan(root), root);

  /// 打开一个 zip 或单个 `.md`。
  static Future<MarkdownImportSource> open(
    String path, {
    archive.CancelToken? cancel,
  }) async {
    await clearWorkspace();
    final workDir = Directory(
      p.join(
        _workspaceRoot(),
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await workDir.create(recursive: true);

    try {
      if (_isMarkdown(path)) {
        await File(path).copy(p.join(workDir.path, p.basename(path)));
      } else {
        await archive.FastZip.ensureInitialized();
        await archive.Zip.extract(
          zipPath: path,
          destDir: workDir.path,
          cancel: cancel ?? archive.CancelToken(),
        );
      }
      final root = _resolveRoot(workDir);
      return MarkdownImportSource._(root, _scan(root), workDir);
    } catch (_) {
      await _deleteQuietly(workDir);
      rethrow;
    }
  }

  /// 「压缩文件夹」得到的包外面多套一层目录（往往还带 `__MACOSX/`）：顶层没有 `.md`
  /// 而恰好只有一个真实子目录时，往下走一层。
  static Directory _resolveRoot(Directory workDir) {
    if (_scan(workDir).isNotEmpty) return workDir;
    final dirs = workDir
        .listSync()
        .whereType<Directory>()
        .where((d) => !_ignored(p.basename(d.path)))
        .toList();
    if (dirs.length == 1) return dirs.single;
    return workDir;
  }

  static List<MarkdownEntryFile> _scan(Directory dir) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => _isMarkdown(f.path) && !_ignored(p.basename(f.path)))
        .map((f) => MarkdownEntryFile(f.path))
        .toList();
    files.sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  static bool _isMarkdown(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.md' || ext == '.markdown';
  }

  static bool _ignored(String name) =>
      name.startsWith('.') || name == '__MACOSX';

  Future<void> dispose() => _deleteQuietly(_workDir);

  static String _workspaceRoot() =>
      p.join(PlatformService.get().applicationCachePath, 'import');

  /// 清掉历次导入留下的工作目录。
  static Future<void> clearWorkspace() =>
      _deleteQuietly(Directory(_workspaceRoot()));

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {
      /* 清理失败不该盖住真正的错误 */
    }
  }
}
