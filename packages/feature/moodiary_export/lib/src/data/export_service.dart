import 'dart:convert';
import 'dart:io';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

import 'export_options.dart';
import 'export_scope.dart';

class ExportOutcome {
  /// 最终产物路径。单文件时是它本身，多文件 / 带素材时是打包好的 zip。
  final String path;
  final int diaryCount;

  /// IR 表达不了的 tiptap 节点类型。非空说明编辑器加了新节点而导出没跟上。
  final Set<String> unsupportedNodes;

  /// 文件缺失 / 解码失败被跳过的媒体数。
  final int skippedMedia;

  const ExportOutcome({
    required this.path,
    required this.diaryCount,
    this.unsupportedNodes = const {},
    this.skippedMedia = 0,
  });
}

/// 导出失败的原因。文案在 UI 层按 l10n 映射。
enum ExportError { emptyScope }

/// 导出进度的阶段。文案在 UI 层按 l10n 映射。
enum ExportPhase {
  /// 逐篇把日记转成 IR、转码媒体。跑在主 isolate，但每篇之间会让出事件循环。
  converting,

  /// 生成目标文件：PDF 逐篇排版，能报真实进度。
  writing,

  /// PDF 的收尾：二次排版 + 绘制 + 字形子集化 + 序列化，一整块切不开，
  /// [ExportProgress.total] 恒为 0（不确定进度）。大库导出时这一段最久。
  serializing,
}

class ExportProgress {
  final ExportPhase phase;
  final int done;

  /// 0 表示总量未知（不确定进度条）。
  final int total;

  const ExportProgress(this.phase, this.done, this.total);
}

class ExportException implements Exception {
  final ExportError error;

  const ExportException(this.error);

  @override
  String toString() => 'ExportException(${error.name})';
}

/// 导出编排：日记 → [ExportDoc] → 目标格式文件。
///
/// 全程不经 WebView —— 遍历在 Dart 侧（见 [TiptapToExportDoc]），批量导出才不必等编辑器
/// 起来、也才能报进度。代价是「节点覆盖」有 JS 与 Dart 两份真相，故未知节点会被收集进
/// [ExportOutcome.unsupportedNodes] 上报，而不是静默丢掉。
class ExportService {
  const ExportService._();

  static Future<ExportOutcome> run({
    required ExportFormat format,
    required ExportScope scope,
    required ExportSettings settings,
    /// 无标题日记在文件名里的回退词（已本地化）。
    required String untitledLabel,
    /// 音视频占位行的类型词（已本地化）——Rust 侧没有 l10n，由这里传下去。
    required String videoLabel,
    required String audioLabel,
    void Function(ExportProgress progress)? onProgress,
  }) async {
    final diaries = await scope.resolve();
    if (diaries.isEmpty) {
      throw const ExportException(ExportError.emptyScope);
    }

    // 上一次的产物已经交给用户（分享 / 另存）了，这里先清掉再开工 —— 产物必须留在盘上
    // 直到分享面板用完，所以不能在导出结束时删，只能下次进来时收。
    await clearWorkspace();
    final workDir = await _freshWorkDir();
    try {
      final categories = await _categoryNames(diaries);
      final media = _MediaStage(workDir, settings.common.media);

      final docs = <ExportDoc>[];
      final unsupported = <String>{};
      for (var i = 0; i < diaries.length; i++) {
        docs.add(await _toExportDoc(diaries[i], categories, media));
        unsupported.addAll(docs.last.unsupportedNodes);
        onProgress?.call(
          ExportProgress(ExportPhase.converting, i + 1, diaries.length),
        );
        // 无图日记整条链只产生 microtask，不让出事件循环——一批纯文字日记会连成一整块
        // 同步 CPU。显式让一帧，保证进度条能画出来。
        if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
      }

      final outcome = switch (format) {
        ExportFormat.markdown =>
          await _writeMarkdown(docs, settings, workDir, media, untitledLabel),
        ExportFormat.docx => await _writeDocx(
          docs,
          settings,
          workDir,
          untitledLabel,
          videoLabel,
          audioLabel,
        ),
        ExportFormat.pdf => await _writePdf(
          docs,
          settings,
          workDir,
          untitledLabel,
          videoLabel,
          audioLabel,
          onProgress,
        ),
      };

      return ExportOutcome(
        path: outcome,
        diaryCount: docs.length,
        unsupportedNodes: unsupported,
        skippedMedia: media.skipped,
      );
    } catch (e) {
      await _deleteQuietly(workDir);
      rethrow;
    }
  }

  // ------------------------------------------------------------- 组装 IR

  static Future<ExportDoc> _toExportDoc(
    Diary diary,
    Map<String, String> categories,
    _MediaStage media,
  ) async {
    // 旧 markdown / richText 日记先转成 tiptap 文档，走同一条遍历。
    var content = diary.content;
    if (!TiptapContent.parse(content).isDoc) {
      content = MarkdownToTiptap.convert(content) ?? content;
    }

    final doc = TiptapToExportDoc.convert(
      id: diary.id,
      title: diary.title,
      // 模型里存的是绝对时刻（UTC），展示与分桶前必须转本地。
      time: diary.time.toLocal(),
      content: content,
      mood: diary.mood,
      weather: diary.weather,
      position: diary.position,
      tags: diary.tags,
      categoryName: categories[diary.categoryId],
      resolvePath: AppFiles.getRealPath,
    );

    return media.apply(doc);
  }

  static Future<Map<String, String>> _categoryNames(List<Diary> diaries) async {
    final ids = diaries
        .map((d) => d.categoryId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final repository = CategoryRepository.get();
    final names = <String, String>{};
    for (final id in ids) {
      final category = await repository.getCategoryById(id);
      if (category != null) names[id] = category.categoryName;
    }
    return names;
  }

  // -------------------------------------------------------------- 各格式

  static Future<String> _writeMarkdown(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    _MediaStage media,
    String untitledLabel,
  ) async {
    final options = MarkdownOptions(
      dialect: settings.markdown.dialect,
      frontMatter: settings.markdown.frontMatter,
      includeTitle: settings.common.includeTitle,
      includeMetaLine: settings.common.includeMeta,
      mediaMode: MarkdownMediaMode.relative,
    );

    final outDir = Directory(p.join(workDir.path, 'out'))..createSync(recursive: true);

    if (settings.common.merge) {
      final buffer = StringBuffer();
      for (final doc in docs) {
        buffer.writeln(MarkdownWriter.write(doc, options));
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
      File(p.join(outDir.path, '${_stamp()}.md'))
          .writeAsStringSync(buffer.toString());
    } else {
      final used = <String>{};
      for (final doc in docs) {
        final name = _uniqueName(
          _fileName(doc, settings.common.nameTemplate, untitledLabel),
          'md',
          used,
          untitledLabel,
        );
        File(p.join(outDir.path, name))
            .writeAsStringSync(MarkdownWriter.write(doc, options));
      }
    }

    await media.copyAssetsInto(outDir);
    // 单个 .md 且无素材时直接给文件，省掉一层解压。
    final entries = outDir.listSync();
    if (entries.length == 1 && entries.single is File) {
      return (entries.single as File).path;
    }
    return _zip(outDir, p.join(workDir.path, 'moodiary-markdown-${_stamp()}.zip'));
  }

  static Future<String> _writeDocx(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    String untitledLabel,
    String videoLabel,
    String audioLabel,
  ) async {
    final layout = settings.docx;
    final style = rust.DocxStyle(
      eastAsiaFont: layout.eastAsiaFont.isEmpty ? '宋体' : layout.eastAsiaFont,
      asciiFont: layout.asciiFont,
      fontSizePt: layout.fontSizePt,
      lineSpacing: layout.lineSpacing,
      firstLineIndent: layout.firstLineIndent,
      pageWidth: layout.paper.width,
      pageHeight: layout.paper.height,
      pageMargin: layout.margin,
      includeTitle: settings.common.includeTitle,
      includeMeta: settings.common.includeMeta,
      pageBreakBetween: true,
      videoLabel: videoLabel,
      audioLabel: audioLabel,
    );

    final outDir = Directory(p.join(workDir.path, 'out'))..createSync(recursive: true);

    if (settings.common.merge) {
      final path = p.join(outDir.path, '${_stamp()}.docx');
      await rust.writeDocx(
        docsJson: _encodeDocs(docs),
        style: style,
        outPath: path,
      );
      return path;
    }

    final used = <String>{};
    for (final doc in docs) {
      final name = _uniqueName(
        _fileName(doc, settings.common.nameTemplate, untitledLabel),
        'docx',
        used,
        untitledLabel,
      );
      await rust.writeDocx(
        docsJson: _encodeDocs([doc]),
        style: style,
        outPath: p.join(outDir.path, name),
      );
    }
    return _zip(outDir, p.join(workDir.path, 'moodiary-docx-${_stamp()}.zip'));
  }

  /// PDF 排版走 Rust 侧的 typst。
  ///
  /// 之前用 Dart 的 `pdf` 包，它按空格切词，中文整段被当成一个「词」，每排一行都要在
  /// 整段上二分查找并测量前缀宽度——实测 4 万字 55 秒、8 万字跑不完，真机上 32 万字的
  /// 那篇外推 8 小时。typst 同一份 0.29 秒排完 352 页，且 CJK 禁则是原生的。
  ///
  /// 也因此不再需要 isolate：FRB 调用跑在 Rust 线程池上，本来就不占主 isolate。
  static Future<String> _writePdf(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    String untitledLabel,
    String videoLabel,
    String audioLabel,
    void Function(ExportProgress progress)? onProgress,
  ) async {
    final layout = settings.pdf;
    final style = rust.PdfStyle(
      fontPath: AppFiles.getRealPath('font', layout.eastAsiaFont),
      // 留空让 typst 用字体文件自报的家族名——用户导入什么就用什么，不必猜名字。
      fontFamily: '',
      fontSizePt: layout.fontSizePt,
      // typst 的 leading 是行间距（默认 0.65em），把「倍数」线性映射过去。
      lineSpacingEm: 0.65 * layout.lineSpacing,
      firstLineIndent: layout.firstLineIndent,
      pageWidthMm: layout.paper.widthMm,
      pageHeightMm: layout.paper.heightMm,
      pageMarginMm: layout.margin * 25.4 / 1440,
      includeTitle: settings.common.includeTitle,
      includeMeta: settings.common.includeMeta,
      videoLabel: videoLabel,
      audioLabel: audioLabel,
    );

    final outDir = Directory(p.join(workDir.path, 'out'))
      ..createSync(recursive: true);

    if (settings.common.merge) {
      onProgress?.call(const ExportProgress(ExportPhase.serializing, 0, 0));
      final path = p.join(outDir.path, '${_stamp()}.pdf');
      await rust.writePdf(
        docsJson: _encodeDocs(docs),
        style: style,
        outPath: path,
      );
      return path;
    }

    final used = <String>{};
    var done = 0;
    onProgress?.call(ExportProgress(ExportPhase.writing, 0, docs.length));
    for (final doc in docs) {
      final name = _uniqueName(
        _fileName(doc, settings.common.nameTemplate, untitledLabel),
        'pdf',
        used,
        untitledLabel,
      );
      await rust.writePdf(
        docsJson: _encodeDocs([doc]),
        style: style,
        outPath: p.join(outDir.path, name),
      );
      onProgress?.call(
        ExportProgress(ExportPhase.writing, ++done, docs.length),
      );
    }
    return _zip(outDir, p.join(workDir.path, 'moodiary-pdf-${_stamp()}.zip'));
  }

  static String _encodeDocs(List<ExportDoc> docs) => jsonEncode([
    for (final doc in docs)
      // 时间在 IR 里是 ISO 串，Rust 侧只是照抄进 meta 行，这里换成人读的格式。
      doc.toJson()..['time'] = TimeFormat.longDateTime(doc.time),
  ]);

  // ------------------------------------------------------------ 文件命名

  static String _fileName(ExportDoc doc, String template, String untitled) {
    final t = doc.time;
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${t.year}-${two(t.month)}-${two(t.day)}';
    final title = doc.title.trim().isEmpty ? untitled : doc.title.trim();
    return template
        .replaceAll('{date}', date)
        .replaceAll('{title}', title)
        .replaceAll('{id}', doc.id);
  }

  /// 文件名里剔掉路径分隔符与各平台保留字符，并按需去重。
  static String _uniqueName(
    String raw,
    String extension,
    Set<String> used,
    String untitled,
  ) {
    var base = raw.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '_').trim();
    if (base.isEmpty) base = untitled;
    if (base.length > 80) base = base.substring(0, 80);

    var name = '$base.$extension';
    var n = 2;
    while (!used.add(name)) {
      name = '$base ($n).$extension';
      n++;
    }
    return name;
  }

  static String _stamp() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'moodiary-${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  // ---------------------------------------------------------------- 打包

  static Future<String> _zip(Directory dir, String zipPath) async {
    final zip = rust.Zip(filePath: zipPath);
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      await zip.addFile(
        filePath: entity.path,
        zipPath: p.relative(entity.path, from: dir.path),
        // 媒体与 docx/pdf 本身都是已压缩格式，再 deflate 一遍只费时间。
        stored: true,
      );
    }
    await zip.finish();
    return zipPath;
  }

  static Future<Directory> _freshWorkDir() async {
    final dir = Directory(
      p.join(
        PlatformService.get().applicationCachePath,
        'export',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {
      /* 清理失败不该盖住真正的错误 */
    }
  }

  /// 清掉历次导出留下的工作目录。产物已经交给用户（分享/保存）后调用。
  static Future<void> clearWorkspace() async {
    final root = Directory(
      p.join(PlatformService.get().applicationCachePath, 'export'),
    );
    await _deleteQuietly(root);
  }
}

/// 媒体转码与暂存。
///
/// 磁盘上的图片是有损 WebP：docx-rs 只认 png/jpeg，dart_pdf 遇到非 JPEG 会解码成裸位图
/// 再 Flate（2 MB 图能撑出 13 MB PDF）。所以两条路都先统一转成 JPEG 落到工作目录，
/// IR 里的路径换成转码后的临时文件。
class _MediaStage {
  final Directory _workDir;
  final ExportMediaPolicy _policy;
  final Map<String, String?> _converted = {};
  final Map<String, String> _assets = {};

  int skipped = 0;

  _MediaStage(this._workDir, this._policy);

  Future<ExportDoc> apply(ExportDoc doc) async {
    if (_policy == ExportMediaPolicy.none) {
      return _rebuild(doc, await _mapBlocks(doc.blocks, _dropMedia));
    }
    return _rebuild(doc, await _mapBlocks(doc.blocks, _stageBlock));
  }

  Future<List<ExportBlock>> _mapBlocks(
    List<ExportBlock> blocks,
    Future<ExportBlock?> Function(ExportBlock) visit,
  ) async {
    final out = <ExportBlock>[];
    for (final block in blocks) {
      final mapped = await visit(block);
      if (mapped != null) out.add(mapped);
    }
    return out;
  }

  Future<ExportBlock?> _dropMedia(ExportBlock block) async => switch (block) {
    ImageBlock() || MediaBlock() => null,
    QuoteBlock(:final children) =>
      QuoteBlock(await _mapBlocks(children, _dropMedia)),
    ListBlock(:final ordered, :final start, :final items) => ListBlock(
      ordered: ordered,
      start: start,
      items: [
        for (final item in items)
          ExportListItem(
            await _mapBlocks(item.children, _dropMedia),
            checked: item.checked,
          ),
      ],
    ),
    _ => block,
  };

  Future<ExportBlock?> _stageBlock(ExportBlock block) async {
    switch (block) {
      case ImageBlock():
        if (block.isExternal) return block;
        if (_policy == ExportMediaPolicy.placeholder) return null;
        final staged = await _stageImage(block.path);
        if (staged == null) {
          skipped++;
          return null;
        }
        return ImageBlock(
          path: staged,
          alt: block.alt,
          widthPercent: block.widthPercent,
        );

      case MediaBlock():
        final cover = block.coverPath == null || _policy == ExportMediaPolicy.placeholder
            ? null
            : await _stageImage(block.coverPath!);
        _rememberAsset(block.path, block.filename);
        return MediaBlock(
          kind: block.kind,
          filename: block.filename,
          path: block.path,
          coverPath: cover,
        );

      case QuoteBlock(:final children):
        return QuoteBlock(await _mapBlocks(children, _stageBlock));

      case ListBlock(:final ordered, :final start, :final items):
        return ListBlock(
          ordered: ordered,
          start: start,
          items: [
            for (final item in items)
              ExportListItem(
                await _mapBlocks(item.children, _stageBlock),
                checked: item.checked,
              ),
          ],
        );

      default:
        return block;
    }
  }

  /// WebP → JPEG。同一张图在多篇日记里复用时只转一次。
  Future<String?> _stageImage(String source) async {
    if (_converted.containsKey(source)) return _converted[source];

    if (!File(source).existsSync()) {
      _converted[source] = null;
      return null;
    }

    final name = '${p.basenameWithoutExtension(source)}.jpg';
    final target = p.join(_workDir.path, 'media', name);
    try {
      await rust.ImageCompressor.containToFile(
        filePath: source,
        outputPath: target,
        // 不给 maxWidth/maxHeight：那两个字段不是夹取而是「拉到正好」，小图会被放大。
        spec: const rust.CompressSpec(
          compressFormat: rust.CompressFormat.jpeg,
          quality: 85,
        ),
      );
    } catch (_) {
      _converted[source] = null;
      return null;
    }
    _converted[source] = target;
    _assets[target] = name;
    return target;
  }

  void _rememberAsset(String path, String name) {
    if (File(path).existsSync()) _assets[path] = name;
  }

  /// 把用到的素材拷进产物目录的 `assets/`（markdown 相对引用指向这里）。
  Future<void> copyAssetsInto(Directory outDir) async {
    if (_assets.isEmpty) return;
    final assets = Directory(p.join(outDir.path, 'assets'))
      ..createSync(recursive: true);
    for (final entry in _assets.entries) {
      final source = File(entry.key);
      if (!source.existsSync()) continue;
      source.copySync(p.join(assets.path, entry.value));
    }
  }

  ExportDoc _rebuild(ExportDoc doc, List<ExportBlock> blocks) => ExportDoc(
    id: doc.id,
    title: doc.title,
    time: doc.time,
    mood: doc.mood,
    weather: doc.weather,
    position: doc.position,
    tags: doc.tags,
    categoryName: doc.categoryName,
    blocks: blocks,
    unsupportedNodes: doc.unsupportedNodes,
  );
}
