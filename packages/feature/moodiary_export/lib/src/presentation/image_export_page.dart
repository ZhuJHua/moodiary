import 'dart:io';
import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../data/export_doc.dart';
import '../data/export_options.dart';
import '../data/export_scope.dart';
import '../data/export_service.dart';
import '../data/image_composer.dart';
import 'image_card/card_style.dart';

/// 图片预览页 —— **整页只有三个可点的东西**：返回、保存到相册、分享。
///
/// 样式一个都不在这里选：模版只有「原稿」一个，明暗 / 尺寸 / 清晰度 / 水印全部取
/// 「导入与导出 → 图片」存下的那份设置，**分享只读不写**。分享是个快动作，
/// 用户在这里改不动设置，也就不会顺手改掉批量导出的默认值。
///
/// 预览显示的是**真产物**：同一个 [ImageComposer] 出的带，只是倍率取 1；
/// 点按钮时才按设置里的倍率重出一张落盘。所以不存在「预览与产物两份代码」。
class ImageExportPage extends StatefulWidget {
  /// 单篇分享。与 [scope] 二选一。
  final String? diaryId;

  /// 批量导出的样张：只渲 scope 里的第一篇。
  final ExportScope? scope;

  const ImageExportPage({super.key, this.diaryId}) : scope = null;

  const ImageExportPage.sample({super.key, required ExportScope this.scope})
    : diaryId = null;

  bool get isSample => scope != null;

  @override
  State<ImageExportPage> createState() => _ImageExportPageState();
}

class _ImageExportPageState extends State<ImageExportPage> {
  late final ExportSettings _settings = .decode(
    MoodiaryKVs.exportSettings.get() ?? '',
  );

  List<ExportDoc>? _docs;
  ImagePreviewBands? _preview;
  Object? _error;
  bool _busy = false;

  List<ui.Image> get _bands => _preview?.bands ?? const [];

  @override
  void initState() {
    super.initState();
    // 主题快照要在 build 之外拿：离屏树没有祖先 Theme，样式必须由这一侧解析好。
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  void dispose() {
    _disposeBands();
    super.dispose();
  }

  void _disposeBands() {
    _preview?.dispose();
    _preview = null;
  }

  ImageCardStyle _style({double? widthDp}) => ImageCardStyle.resolve(
    brightness: _settings.image.brightness,
    fallback: Theme.of(context).brightness,
    widthDp: widthDp ?? _settings.image.widthDp,
    watermark: _settings.image.watermark,
  );

  Future<void> _render() async {
    // context 在第一个 await 之前取干净：渲染是异步的，之后不保证还 mounted。
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final style = _style();
    try {
      final docs = _docs ??= await _loadDocs();
      if (docs.isEmpty) {
        setState(() => _error = _EmptyScope());
        return;
      }
      final preview = await ImageComposer.renderBands(
        docs: docs,
        common: _settings.common,
        style: style,
        // 按屏幕像素密度出图：预览卡片是按逻辑宽度铺开的，1 倍出图在 3x 屏上等于放大三倍。
        devicePixelRatio: devicePixelRatio,
      );
      if (!mounted) {
        preview.dispose();
        return;
      }
      setState(() {
        _disposeBands();
        _preview = preview;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<List<ExportDoc>> _loadDocs() async {
    final scope = widget.scope;
    final diaries = scope != null
        ? await scope.resolve()
        : [
            ?await getIt<DiaryRepository>().getDiaryByBusinessId(
              widget.diaryId ?? '',
            ),
          ];
    // 样张只看第一篇：全量导出前确认一眼版式，不必等 342 篇都渲完。
    final picked = widget.isSample ? diaries.take(1).toList() : diaries;
    return ExportService.previewDocs(
      picked,
      includePosition: _settings.common.includePosition,
    );
  }

  /// 按设置里的真实倍率出一张 PNG 落到缓存目录。
  Future<String?> _composeFile() async {
    final docs = _docs;
    if (docs == null || docs.isEmpty) return null;
    final dir = Directory(
      p.join(PlatformService.get().applicationCachePath, 'export', 'share'),
    );
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final result = await ImageComposer.composeToFile(
      docs: docs,
      common: _settings.common,
      options: _settings.image,
      style: _style(),
      outPath: p.join(
        dir.path,
        'moodiary-${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    // 每次点按钮都现出一张，所以这里不会撞上缓存被 purge 的时间窗；
    // 真出不来（磁盘满）就当没有产物，由调用方报错。
    return File(result.path).existsSync() ? result.path : null;
  }

  Future<void> _saveToAlbum() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final path = await _composeFile();
      if (path == null) {
        toast.error(message: l10n.export.artifactMissing);
        return;
      }
      final ok = await MediaManager.saveToGallery(path: path, type: .image);
      if (ok) {
        toast.success(message: l10n.share.savedToAlbum);
      } else {
        // saveToGallery 把异常吞成 false，最现实的成因就是相册权限被拒。
        toast.error(message: l10n.share.saveToAlbumFailed);
      }
    } catch (e) {
      toast.error(message: l10n.share.renderFailed(error: '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final path = await _composeFile();
      if (path == null) {
        toast.error(message: l10n.export.artifactMissing);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          text: l10n.share.subject,
        ),
      );
    } catch (e) {
      toast.error(message: l10n.share.renderFailed(error: '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSample
              ? l10n.share.previewSampleTitle
              : l10n.share.previewTitle,
        ),
      ),
      body: _body(l10n),
      bottomNavigationBar: SafeArea(
        minimum: const .fromLTRB(16, 12, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.tonalIcon(
                  onPressed: _bands.isEmpty || _busy ? null : _saveToAlbum,
                  icon: const Icon(LucideIcons.image, size: 18),
                  label: Text(l10n.share.saveToAlbum),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _bands.isEmpty || _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.share2, size: 18),
                  label: Text(l10n.share.share),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Translations l10n) {
    final scheme = context.theme.colors;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const .all(24),
          child: Text(
            _error is _EmptyScope
                ? l10n.share.empty
                : l10n.share.renderFailed(error: '$_error'),
            textAlign: .center,
            style: context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ),
      );
    }
    if (_bands.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.share.rendering,
              style: context.theme.typography.bodyMedium.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    // 底色比卡片深一档，卡片才浮得起来；短图垂直居中、长图从顶上开始滚 ——
    // 用 ConstrainedBox(minHeight: 视口) + Center 一次拿到两种行为。
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = EdgeInsets.fromLTRB(24, 20, 24, 24);
          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: .circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        // 各带首尾相接就是整张长图；分带是为了绕开单张纹理上限，
                        // 拼在一起看不出接缝（切点落在整数像素上）。
                        for (final band in _bands)
                          RawImage(
                            image: band,
                            width: _settings.image.widthDp,
                            fit: .fitWidth,
                            filterQuality: .medium,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyScope implements Exception {}
