import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:fast_press/fast_press.dart' as press;
import 'package:fast_zip/fast_zip.dart' as archive;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

import '../presentation/image_card/card_style.dart';
import 'export_doc.dart';
import 'export_options.dart';
import 'export_scope.dart';
import 'image_composer.dart';
import 'markdown_writer.dart';
import 'tiptap_to_ir.dart';

class ExportOutcome {
  final String path;

  final List<String> images;

  final int diaryCount;

  final Set<String> unsupportedNodes;

  final int skippedMedia;

  const ExportOutcome({
    required this.path,
    required this.diaryCount,
    this.images = const [],
    this.unsupportedNodes = const {},
    this.skippedMedia = 0,
  });
}

enum ExportError { emptyScope, cancelled }

enum ExportPhase {
  converting,

  writing,

  serializing,
}

class ExportProgress {
  final ExportPhase phase;
  final int done;

  // 0 表示总量未知（不确定进度条）
  final int total;

  const ExportProgress(this.phase, this.done, this.total);
}

class ExportException implements Exception {
  final ExportError error;

  const ExportException(this.error);

  @override
  String toString() => 'ExportException(${error.name})';
}

class ExportService {
  const ExportService._();

  static Future<ExportOutcome> run({
    required ExportFormat format,
    required ExportScope scope,
    required ExportSettings settings,

    required String untitledLabel,

    required String videoLabel,
    required String audioLabel,
    void Function(ExportProgress progress)? onProgress,

    press.CancelToken? cancel,

    ImageCardStyle? imageStyle,
  }) async {
    await press.FastPress.ensureInitialized();
    final token = cancel ?? press.CancelToken();
    final diaries = await scope.resolve();
    if (diaries.isEmpty) {
      throw const ExportException(.emptyScope);
    }

    await clearWorkspace();
    final workDir = await _freshWorkDir();
    try {
      final categories = await _categoryNames(diaries);
      final places = await _places(diaries);
      final media = _MediaStage(
        workDir,
        settings.common.media,
        copyOriginals: format == .markdown,
      );

      final docs = <ExportDoc>[];
      final unsupported = <String>{};
      for (var i = 0; i < diaries.length; i++) {
        _throwIfCancelled(token);
        docs.add(
          await _toExportDoc(
            diaries[i],
            categories,
            places,
            media,
            includePosition: settings.common.includePosition,
          ),
        );
        unsupported.addAll(docs.last.unsupportedNodes);
        onProgress?.call(ExportProgress(.converting, i + 1, diaries.length));
        // 每 8 篇让出一帧，避免纯文字日记连续同步 CPU 卡住进度条
        if (i % 8 == 7) await Future<void>.delayed(.zero);
      }

      final images = <String>[];
      final outcome = switch (format) {
        .markdown => await _writeMarkdown(
          docs,
          settings,
          workDir,
          media,
          untitledLabel,
          token,
        ),
        .docx => await _writeDocx(
          docs,
          settings,
          workDir,
          untitledLabel,
          videoLabel,
          audioLabel,
          token,
        ),
        .pdf => await _writePdf(
          docs,
          settings,
          workDir,
          untitledLabel,
          videoLabel,
          audioLabel,
          onProgress,
          token,
        ),
        .image => await _writeImage(
          docs,
          settings,
          workDir,
          untitledLabel,
          imageStyle ??
              (throw ArgumentError('image export needs an ImageCardStyle')),
          images,
          onProgress,
          token,
        ),
      };

      return ExportOutcome(
        path: outcome,
        images: images,
        diaryCount: docs.length,
        unsupportedNodes: unsupported,
        skippedMedia: media.skipped,
      );
    } catch (e) {
      await _deleteQuietly(workDir);
      if (e is! ExportException && token.isCancelled()) {
        throw const ExportException(.cancelled);
      }
      rethrow;
    }
  }

  static void _throwIfCancelled(press.CancelToken token) {
    if (token.isCancelled()) throw const ExportException(.cancelled);
  }

  static Future<List<ExportDoc>> previewDocs(
    List<Diary> diaries, {
    required bool includePosition,
  }) async {
    final categories = await _categoryNames(diaries);
    final places = await _places(diaries);
    return [
      for (final diary in diaries)
        await _toExportDoc(
          diary,
          categories,
          places,
          null,
          includePosition: includePosition,
        ),
    ];
  }

  static Future<ExportDoc> _toExportDoc(
    Diary diary,
    Map<String, String> categories,
    Map<String, Place> places,
    _MediaStage? media, {
    required bool includePosition,
  }) async {
    var content = diary.content;
    if (!TiptapContent.parse(content).isDoc) {
      content =
          switch (DiaryType.fromValue(diary.type)) {
            .richText => QuillDeltaToTiptap.convert(content),
            _ => MarkdownToTiptap.convert(content),
          } ??
          content;
    }

    final doc = TiptapToIr.convert(
      id: diary.id,
      title: diary.title,
      time: diary.time.toLocal(),
      content: content,
      mood: diary.mood,
      weather: diary.weather,
      place: includePosition ? places[diary.placeId] : null,
      tags: diary.tags,
      categoryName: categories[diary.categoryId],
      resolvePath: AppFiles.getRealPath,
    );

    return media == null ? doc : media.apply(doc);
  }

  static Future<Map<String, String>> _categoryNames(List<Diary> diaries) async {
    final ids = diaries
        .map((d) => d.categoryId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final repository = getIt<CategoryRepository>();
    final names = <String, String>{};
    for (final id in ids) {
      final category = await repository.getCategoryById(id);
      if (category != null) names[id] = category.categoryName;
    }
    return names;
  }

  static Future<Map<String, Place>> _places(List<Diary> diaries) async {
    final ids = diaries.map((d) => d.placeId).whereType<String>().toSet();
    if (ids.isEmpty) return const {};
    final all = await getIt<PlaceRepository>().getAllPlaces();
    return {
      for (final p in all)
        if (ids.contains(p.id)) p.id: p,
    };
  }

  static Future<String> _writeMarkdown(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    _MediaStage media,
    String untitledLabel,
    press.CancelToken token,
  ) async {
    final options = MarkdownOptions(
      includeTitle: settings.common.includeTitle,
      includeMetaLine: settings.common.includeMeta,
    );

    final outDir = Directory(p.join(workDir.path, 'out'))
      ..createSync(recursive: true);

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
    final entries = outDir.listSync();
    if (entries.length == 1 && entries.single is File) {
      return (entries.single as File).path;
    }
    return _zip(
      outDir,
      p.join(workDir.path, 'moodiary-markdown-${_stamp()}.zip'),
      token,
    );
  }

  static Future<String> _writeDocx(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    String untitledLabel,
    String videoLabel,
    String audioLabel,
    press.CancelToken token,
  ) async {
    final layout = settings.docx;
    final style = press.DocxStyle(
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

    final outDir = Directory(p.join(workDir.path, 'out'))
      ..createSync(recursive: true);

    if (settings.common.merge) {
      final path = p.join(outDir.path, '${_stamp()}.docx');
      final builder = await press.DocxBuilder.newInstance(style: style);
      try {
        for (final doc in docs) {
          _throwIfCancelled(token);
          await builder.add(doc: _toIrDoc(doc));
        }
        await builder.finish(outPath: path, cancel: token);
      } finally {
        builder.dispose();
      }
      return path;
    }

    final used = <String>{};
    for (final doc in docs) {
      _throwIfCancelled(token);
      final name = _uniqueName(
        _fileName(doc, settings.common.nameTemplate, untitledLabel),
        'docx',
        used,
        untitledLabel,
      );
      await press.writeDocx(
        docs: _toIr([doc]),
        style: style,
        outPath: p.join(outDir.path, name),
        cancel: token,
      );
    }
    return _zip(
      outDir,
      p.join(workDir.path, 'moodiary-docx-${_stamp()}.zip'),
      token,
    );
  }

  static Future<String> _writePdf(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    String untitledLabel,
    String videoLabel,
    String audioLabel,
    void Function(ExportProgress progress)? onProgress,
    press.CancelToken token,
  ) async {
    final layout = settings.pdf;
    final style = press.PdfStyle(
      fontPath: AppFiles.getRealPath('font', layout.eastAsiaFont),
      // 留空让 typst 用字体文件自报的家族名
      fontFamily: '',
      fontSizePt: layout.fontSizePt,
      // typst 默认 leading 是 0.65em，行距倍数按此映射
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
      final path = p.join(outDir.path, '${_stamp()}.pdf');
      final builder = await press.PdfBuilder.newInstance(style: style);
      try {
        onProgress?.call(ExportProgress(.writing, 0, docs.length));
        for (var i = 0; i < docs.length; i++) {
          _throwIfCancelled(token);
          await builder.add(doc: _toIrDoc(docs[i]));
          onProgress?.call(ExportProgress(.writing, i + 1, docs.length));
        }
        onProgress?.call(const ExportProgress(.serializing, 0, 0));
        await builder.finish(outPath: path, cancel: token);
      } finally {
        builder.dispose();
      }
      return path;
    }

    final used = <String>{};
    var done = 0;
    onProgress?.call(ExportProgress(.writing, 0, docs.length));
    for (final doc in docs) {
      _throwIfCancelled(token);
      final name = _uniqueName(
        _fileName(doc, settings.common.nameTemplate, untitledLabel),
        'pdf',
        used,
        untitledLabel,
      );
      await press.writePdf(
        docs: _toIr([doc]),
        style: style,
        outPath: p.join(outDir.path, name),
        cancel: token,
      );
      onProgress?.call(ExportProgress(.writing, ++done, docs.length));
    }
    return _zip(
      outDir,
      p.join(workDir.path, 'moodiary-pdf-${_stamp()}.zip'),
      token,
    );
  }

  static Future<String> _writeImage(
    List<ExportDoc> docs,
    ExportSettings settings,
    Directory workDir,
    String untitledLabel,
    ImageCardStyle style,
    List<String> images,
    void Function(ExportProgress progress)? onProgress,
    press.CancelToken token,
  ) async {
    final outDir = Directory(p.join(workDir.path, 'out'))
      ..createSync(recursive: true);

    Future<String> compose(List<ExportDoc> group, String name) async {
      final path = p.join(outDir.path, name);
      final result = await ImageComposer.composeToFile(
        docs: group,
        common: settings.common,
        options: settings.image,
        style: style,
        outPath: path,
        isCancelled: token.isCancelled,
      );
      return result.path;
    }

    if (settings.common.merge) {
      onProgress?.call(const ExportProgress(.writing, 0, 1));
      final path = await compose(docs, '${_stamp()}.png');
      images.add(path);
      onProgress?.call(const ExportProgress(.writing, 1, 1));
      return path;
    }

    final used = <String>{};
    onProgress?.call(ExportProgress(.writing, 0, docs.length));
    for (var i = 0; i < docs.length; i++) {
      _throwIfCancelled(token);
      final name = _uniqueName(
        _fileName(docs[i], settings.common.nameTemplate, untitledLabel),
        'png',
        used,
        untitledLabel,
      );
      images.add(await compose([docs[i]], name));
      onProgress?.call(ExportProgress(.writing, i + 1, docs.length));
    }

    if (images.length <= _kLooseImageLimit) return images.first;
    final zipPath = await _zip(
      outDir,
      p.join(workDir.path, 'moodiary-image-${_stamp()}.zip'),
      token,
    );
    images.clear();
    return zipPath;
  }

  static const int _kLooseImageLimit = 9;

  static press.IrDoc _toIrDoc(ExportDoc doc) =>
      doc.toIr(TimeFormat.longDateTime(doc.time));

  static List<press.IrDoc> _toIr(List<ExportDoc> docs) => [
    for (final doc in docs) _toIrDoc(doc),
  ];

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

  static Future<String> _zip(
    Directory dir,
    String zipPath,
    press.CancelToken token,
  ) async {
    await archive.FastZip.ensureInitialized();
    final zip = await archive.Zip.newInstance(filePath: zipPath);
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        _throwIfCancelled(token);
        await zip.addFile(
          filePath: entity.path,
          zipPath: p.relative(entity.path, from: dir.path),
          stored: true,
        );
      }
      await zip.finish();
    } finally {
      zip.dispose();
    }
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
    }
  }

  static Future<void> clearWorkspace() async {
    final root = Directory(
      p.join(PlatformService.get().applicationCachePath, 'export'),
    );
    await _deleteQuietly(root);
  }
}

class _MediaStage {
  final Directory _workDir;
  final ExportMediaPolicy _policy;
  final bool copyOriginals;
  final Map<String, String?> _converted = {};

  final Map<String, String> _assets = {};

  int skipped = 0;

  _MediaStage(this._workDir, this._policy, {this.copyOriginals = false});

  Future<ExportDoc> apply(ExportDoc doc) async {
    if (_policy == .none) {
      return _rebuild(doc, await _mapBlocks(doc.blocks, _dropMedia));
    }
    return _rebuild(doc, await _mapBlocks(doc.blocks, _stageBlock));
  }

  Future<List<IrBlock>> _mapBlocks(
    List<IrBlock> blocks,
    Future<IrBlock?> Function(IrBlock) visit,
  ) async {
    final out = <IrBlock>[];
    for (final block in blocks) {
      final mapped = await visit(block);
      if (mapped != null) out.add(mapped);
    }
    return out;
  }

  Future<IrBlock?> _dropMedia(IrBlock block) async => switch (block) {
    IrBlock_Image() || IrBlock_Media() => null,
    IrBlock_Quote(:final children) => IrBlock.quote(
      children: await _mapBlocks(children, _dropMedia),
    ),
    IrBlock_List(:final ordered, :final start, :final items) => IrBlock.list(
      ordered: ordered,
      start: start,
      items: [
        for (final item in items)
          IrListItem(
            children: await _mapBlocks(item.children, _dropMedia),
            checked: item.checked,
          ),
      ],
    ),
    _ => block,
  };

  Future<IrBlock?> _stageBlock(IrBlock block) async {
    switch (block) {
      case IrBlock_Image():
        if (block.isExternal) return block;
        if (_policy == .placeholder) return null;
        final staged = await _stageImage(block.path);
        if (staged == null) {
          skipped++;
          return null;
        }
        return .image(
          path: staged,
          alt: block.alt,
          widthPercent: block.widthPercent,
          isExternal: false,
        );

      case IrBlock_Media():
        final cover = block.coverPath == null || _policy == .placeholder
            ? null
            : await _stageImage(block.coverPath!);
        _rememberAsset(block.path, '${block.kind}/${block.filename}');
        return .media(
          kind: block.kind,
          filename: block.filename,
          path: block.path,
          coverPath: cover,
        );

      case IrBlock_Quote(:final children):
        return .quote(children: await _mapBlocks(children, _stageBlock));

      case IrBlock_List(:final ordered, :final start, :final items):
        return .list(
          ordered: ordered,
          start: start,
          items: [
            for (final item in items)
              IrListItem(
                children: await _mapBlocks(item.children, _stageBlock),
                checked: item.checked,
              ),
          ],
        );

      default:
        return block;
    }
  }

  Future<String?> _stageImage(String source) async {
    if (_converted.containsKey(source)) return _converted[source];

    if (!File(source).existsSync()) {
      _converted[source] = null;
      return null;
    }
    if (copyOriginals) {
      _converted[source] = source;
      _assets[source] = 'image/${p.basename(source)}';
      return source;
    }

    final name = '${p.basenameWithoutExtension(source)}.jpg';
    final target = p.join(_workDir.path, 'media', name);
    try {
      await FastImageCodec.containToFile(
        filePath: source,
        outputPath: target,
        // maxWidth/maxHeight 是"拉到正好"不是夹取，会放大小图，故不传
        spec: const FastCompressSpec(compressFormat: .jpeg, quality: 85),
      );
    } catch (e, st) {
      logger.e('导出转码失败：$source', error: e, stackTrace: st);
      _converted[source] = null;
      return null;
    }
    _converted[source] = target;
    _assets[target] = 'image/$name';
    return target;
  }

  void _rememberAsset(String path, String relative) {
    if (File(path).existsSync()) _assets[path] = relative;
  }

  Future<void> copyAssetsInto(Directory outDir) async {
    if (_assets.isEmpty) return;
    final assets = Directory(p.join(outDir.path, 'assets'));
    for (final entry in _assets.entries) {
      final source = File(entry.key);
      if (!source.existsSync()) continue;
      final target = File(p.join(assets.path, entry.value));
      target.parent.createSync(recursive: true);
      source.copySync(target.path);
    }
  }

  ExportDoc _rebuild(ExportDoc doc, List<IrBlock> blocks) => ExportDoc(
    id: doc.id,
    title: doc.title,
    time: doc.time,
    mood: doc.mood,
    weather: doc.weather,
    place: doc.place,
    tags: doc.tags,
    categoryName: doc.categoryName,
    blocks: blocks,
    unsupportedNodes: doc.unsupportedNodes,
  );
}
