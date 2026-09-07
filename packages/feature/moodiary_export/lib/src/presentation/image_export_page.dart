import 'dart:io';
import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_router/moodiary_router.dart';
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

class ImageExportPage extends StatefulWidget {
  final String? diaryId;

  final ExportScope? scope;

  const ImageExportPage({super.key, this.diaryId}) : scope = null;

  factory ImageExportPage.fromRoute(GoRouterState state) =>
      ImageExportPage(diaryId: state.params['diary_id'] as String?);

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

  // 只在这一页有效，不写回 exportSettings；null = 跟应用当前明暗
  Brightness? _brightness;

  List<ui.Image> get _bands => _preview?.bands ?? const [];

  @override
  void initState() {
    super.initState();
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

  Brightness get _effectiveBrightness =>
      _brightness ?? Theme.of(context).brightness;

  ImageCardStyle _style({double? widthDp}) => ImageCardStyle.resolve(
    brightness: _effectiveBrightness,
    fallback: Theme.of(context).brightness,
    widthDp: widthDp ?? _settings.image.widthDp,
    watermark: _settings.image.watermark,
  );

  void _toggleBrightness() {
    setState(() {
      _brightness = _effectiveBrightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
    });
    _render();
  }

  Future<void> _render() async {
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
    final picked = widget.isSample ? diaries.take(1).toList() : diaries;
    return ExportService.previewDocs(
      picked,
      includePosition: _settings.common.includePosition,
    );
  }

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
        actions: [
          IconButton(
            onPressed: _busy ? null : _toggleBrightness,
            tooltip: l10n.export.imageBrightness,
            icon: Icon(
              _effectiveBrightness == Brightness.dark
                  ? LucideIcons.sun
                  : LucideIcons.moon,
            ),
          ),
        ],
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
