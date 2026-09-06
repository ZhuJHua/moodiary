import 'dart:io';

import 'package:fast_zip/fast_zip.dart' as archive;
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:path/path.dart' as p;

class MarkdownEntryFile {
  final String path;

  String get name => p.basename(path);

  const MarkdownEntryFile(this.path);
}

class MarkdownImportSource {
  final Directory root;

  final List<MarkdownEntryFile> entries;

  final Directory _workDir;

  const MarkdownImportSource._(this.root, this.entries, this._workDir);

  int get count => entries.length;

  factory MarkdownImportSource.scan(Directory root) =>
      MarkdownImportSource._(root, _scan(root), root);

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

  // "压缩文件夹"常见外层再套一层目录（含 __MACOSX/）
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

  static Future<void> clearWorkspace() =>
      _deleteQuietly(Directory(_workspaceRoot()));

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {
    }
  }
}
