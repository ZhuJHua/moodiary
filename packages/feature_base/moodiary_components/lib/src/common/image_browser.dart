import 'dart:async';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:fast_image/fast_image.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

class MImageBrowser extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? heroPrefix;

  final FastImageTier? placeholderTier;

  const MImageBrowser({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroPrefix,
    this.placeholderTier,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? heroPrefix,
    FastImageTier? placeholderTier,
  }) {
    return context.pushTransparentRoute(
      MImageBrowser(
        images: images,
        initialIndex: initialIndex,
        heroPrefix: heroPrefix,
        placeholderTier: placeholderTier,
      ),
    );
  }

  @override
  State<MImageBrowser> createState() => _MImageBrowserState();
}

class _MImageBrowserState extends State<MImageBrowser> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;

  double _chrome = 1.0;
  bool _saving = false;

  final _zoomedPages = <int>{};

  bool get _zoomed => _zoomedPages.contains(_current);

  final _regions = <String, FastTileSource?>{};

  final _probing = <String>{};

  static bool _isNetwork(String image) =>
      image.startsWith('http://') || image.startsWith('https://');

  ImageProvider _providerOf(String image) => _isNetwork(image)
      ? CachedNetworkImageProvider(image)
      : FastImage(image) as ImageProvider;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _probe(String image) async {
    if (_regions.containsKey(image) || _probing.contains(image)) return;
    _probing.add(image);
    try {
      final source = await FastTileSource.resolve(image);
      if (!mounted) return;
      setState(() => _regions[image] = source);
    } catch (e) {
      logger.d('probe failed: $image ($e)');
      if (mounted) setState(() => _regions[image] = null);
    } finally {
      _probing.remove(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        DismissiblePage(
          onDismissed: () => Navigator.of(context).pop(),
          onDragUpdate: (details) => setState(() => _chrome = details.opacity),
          direction: .vertical,
          backgroundColor: Colors.black,
          minScale: 0.2,
          dragSensitivity: 0.8,
          startingOpacity: 0.9,
          maxTransformValue: 0.6,
          child: _buildGallery(),
        ),
        Positioned(
          top: topPadding + 8,
          left: 8,
          child: Opacity(
            opacity: _chrome,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Positioned(
            top: topPadding + 16,
            right: 16,
            child: Opacity(
              opacity: _chrome,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: .circular(12),
                ),
                child: Padding(
                  padding: const .symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    '${_current + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Opacity(
              opacity: _chrome,
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: context.l10n.ui.imageBrowserInfo,
                    child: IconButton(
                      icon: const Icon(LucideIcons.info, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                      onPressed: _showInfo,
                      onLongPress: () => FastTileImageView.debugOverlay.value =
                          !FastTileImageView.debugOverlay.value,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.ui.imageBrowserSave,
                    icon: const Icon(
                      LucideIcons.imageDown,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGallery() {
    final hero = widget.heroPrefix != null;
    final Widget gallery;
    if (widget.images.length == 1) {
      gallery = _buildPage(0, hero: hero);
    } else {
      gallery = PageView.builder(
        controller: _pageController,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.images.length,
        itemBuilder: (context, index) => HeroMode(
          enabled: hero && index == _current,
          child: _buildPage(index, hero: hero),
        ),
      );
    }
    return PhotoViewGestureDetectorScope(axis: .vertical, child: gallery);
  }

  Widget _buildPage(int index, {required bool hero}) {
    final image = widget.images[index];
    final placeholder = _placeholderOf(image);
    final local = !_isNetwork(image);
    if (local && !_regions.containsKey(image)) {
      unawaited(_probe(image));
    }
    final region = _regions[image];
    final Widget page;
    if (region != null) {
      page = FastTileImageViewer(
        path: image,
        decodePath: region.decodePath,
        imageSize: region.size,
        overview: placeholder ?? FastImage(image, tier: .m),
        active: index == _current,
        onScaleState: (state) => _onScaleState(index, state),
        onTap: () => Navigator.of(context).maybePop(),
      );
    } else if (local && _probing.contains(image)) {
      page = PhotoView(
        imageProvider: placeholder ?? FastImage(image, tier: .m),
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained,
        onTapUp: (_, _, _) => Navigator.of(context).maybePop(),
      );
    } else {
      page = PhotoView(
        imageProvider: _providerOf(image),
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        scaleStateChangedCallback: (state) => _onScaleState(index, state),
        onTapUp: (_, _, _) => Navigator.of(context).maybePop(),
        loadingBuilder: (_, _) => placeholder != null
            ? Image(
                image: placeholder,
                fit: .contain,
                width: .infinity,
                height: .infinity,
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
        errorBuilder: (_, _, _) => const Center(
          child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
        ),
      );
    }
    if (!hero) return page;
    return Hero(tag: '${widget.heroPrefix}-$image', child: page);
  }

  void _onScaleState(int index, PhotoViewScaleState state) {
    final zoomed = state != .initial;
    if (zoomed == _zoomedPages.contains(index)) return;
    setState(() {
      if (zoomed) {
        _zoomedPages.add(index);
      } else {
        _zoomedPages.remove(index);
      }
    });
  }

  ImageProvider? _placeholderOf(String image) {
    final tier = widget.placeholderTier;
    if (tier == null || _isNetwork(image)) return null;
    return FastImage(image, tier: tier);
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    final l10n = context.l10n;
    final image = widget.images[_current];
    var path = image;
    String? tempPath;
    try {
      if (_isNetwork(image)) {
        toast.loading();
        try {
          final resp = await getIt<IHttpClient>().requestBytes(
            .get,
            image,
            silent: true,
          );
          final bytes = resp.data;
          if (bytes == null || bytes.isEmpty) {
            throw const FormatException('empty body');
          }
          tempPath = AppFiles.getCachePath('save-${uuidV7()}${_extOf(image)}');
          await File(tempPath).writeAsBytes(bytes);
          path = tempPath;
        } finally {
          await toast.dismiss();
        }
      }
      final ok = await MediaManager.saveToGallery(path: path, type: .image);
      ok
          ? toast.success(message: l10n.ui.imageBrowserSaved)
          : toast.error(message: l10n.ui.imageBrowserSaveFailed);
    } catch (_) {
      toast.error(message: l10n.ui.imageBrowserSaveFailed);
    } finally {
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
      _saving = false;
    }
  }

  static String _extOf(String url) {
    final ext = p.extension(Uri.tryParse(url)?.path ?? url);
    return ext.isEmpty ? '.jpg' : ext;
  }

  Future<void> _showInfo() async {
    final info = await _loadInfo(widget.images[_current]);
    if (!mounted) return;
    await MSheet.show<void>(
      context,
      builder: (sheetContext) => MSheetScaffold<void>(
        title: sheetContext.l10n.ui.imageBrowserInfo,
        icon: LucideIcons.info,
        actions: [MAction(label: sheetContext.l10n.common.ok, isPrimary: true)],
        child: _ImageInfoSheet(info: info),
      ),
    );
  }

  Future<_ImageInfoData> _loadInfo(String image) async {
    if (_isNetwork(image)) {
      String? resolution;
      try {
        final size = await MediaManager.getImageSize(_providerOf(image))
            .timeout(const Duration(seconds: 3));
        resolution = '${size.width.toInt()} × ${size.height.toInt()}';
      } catch (_) {}
      return _ImageInfoData(url: image, resolution: resolution);
    }

    final file = File(image);
    int? length;
    DateTime? modified;
    try {
      length = await file.length();
      modified = await file.lastModified();
    } catch (_) {}

    String? resolution;
    String? decode;
    try {
      final probe = await FastImageCodec.probe(filePath: image);
      resolution = '${probe.width} × ${probe.height}';
      final region = _regions[image];
      decode = region != null
          ? (region.decodePath == image
                ? l10n.ui.imageBrowserDecodeTiled
                : l10n.ui.imageBrowserDecodeTiledBaseline)
          : probe.format == FastImageFormat.jpeg && probe.progressive
          ? l10n.ui.imageBrowserDecodeWholeProgressive
          : l10n.ui.imageBrowserDecodeWhole;
    } catch (_) {}

    final unit = length == null ? null : AppFiles.bytesToUnits(length);
    final ext = p.extension(image).replaceFirst('.', '').toUpperCase();
    return _ImageInfoData(
      name: p.basename(image),
      resolution: resolution,
      size: unit == null ? null : '${unit['size']} ${unit['unit']}',
      format: ext.isEmpty ? null : ext,
      decode: decode,
      modified: modified,
    );
  }
}

class _ImageInfoData {
  final String? name;
  final String? url;
  final String? resolution;
  final String? size;
  final String? format;
  final String? decode;
  final DateTime? modified;

  const _ImageInfoData({
    this.name,
    this.url,
    this.resolution,
    this.size,
    this.format,
    this.decode,
    this.modified,
  });
}

class _ImageInfoSheet extends StatelessWidget {
  final _ImageInfoData info;

  const _ImageInfoSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <(String, String)>[
      if (info.name != null) (l10n.common.fileName, info.name!),
      if (info.url != null) (l10n.ui.imageBrowserInfoUrl, info.url!),
      if (info.resolution != null)
        (l10n.ui.imageBrowserInfoResolution, info.resolution!),
      if (info.size != null) (l10n.ui.imageBrowserInfoSize, info.size!),
      if (info.format != null) (l10n.ui.imageBrowserInfoFormat, info.format!),
      if (info.decode != null) (l10n.ui.imageBrowserInfoDecode, info.decode!),
      if (info.modified != null)
        (
          l10n.ui.imageBrowserInfoModified,
          TimeFormat.fullDateTime(info.modified!),
        ),
    ];
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const .symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    label,
                    style: context.theme.typography.bodyMedium.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: context.theme.typography.bodyMedium.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
