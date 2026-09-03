import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

import 'original_image_view.dart';

/// 全屏图片浏览器：左右翻页、双指缩放、下拉手势关闭（背景与操作钮随手势渐隐）、
/// Hero 飞入飞出（传 [heroPrefix] 启用，缩略图侧 tag 须为 `'$heroPrefix-<image>'`）。
/// 底部操作：保存到相册 / 图片信息（分辨率、大小、格式、修改时间）。
/// [images] 每项为本地绝对路径或 http(s) 外链。
class MImageBrowser extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? heroPrefix;

  /// 缩略图侧的档位。传入后全图解码完成前先显示同缓存键的缩略图
  /// （命中内存缓存，首帧即有像素）——Hero 首次打开就能起飞，全图就绪后无缝替换。
  /// 必须与缩略图侧完全一致（同路径 [MediaImage] + 同档位）才会命中缓存。
  final ImageTier? placeholderTier;

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
    ImageTier? placeholderTier,
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

  /// 操作钮不透明度，随下拉手势渐隐（DismissiblePage onDragUpdate 回传）。
  double _chrome = 1.0;
  bool _saving = false;

  /// 各页是否放大（非 initial 缩放态）。当前页放大时禁掉 PageView 的水平滚动，
  /// 让横向平移完全归 PhotoView（竖直平移由 scope 的 shouldMove 抢占解决）。邻页仍装着、
  /// 缩放态还在，翻回去要照它的态来。
  final _zoomedPages = <int>{};

  bool get _zoomed => _zoomedPages.contains(_current);

  /// 本地图能走 tile 的话记（转正后尺寸, 交给 Rust 解的文件），探头一次记一次；
  /// null = 探过了，不能走 tile。
  final _regions = <String, ({Size size, String decodePath})?>{};

  /// 探头还没回来的图：这期间只画 m 档打底，不解原图。
  final _probing = <String>{};

  static bool _isNetwork(String image) =>
      image.startsWith('http://') || image.startsWith('https://');

  ImageProvider _providerOf(String image) => _isNetwork(image)
      ? CachedNetworkImageProvider(image)
      : MediaImage(image) as ImageProvider;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 本地图只读头：能区域解码（baseline JPEG、非隔行 PNG、非动图 WebP）就直接走 tile 页；
  /// 大的 progressive JPEG 先要它的 baseline 副本（在就秒开，不在现转）；其余留在整图路径。
  Future<void> _probe(String image) async {
    if (_regions.containsKey(image) || _probing.contains(image)) return;
    _probing.add(image);
    try {
      final probe = await rust.ImageCompressor.probe(filePath: image);
      final size = Size(probe.width.toDouble(), probe.height.toDouble());
      String? decodePath;
      if (probe.regionDecodable) {
        decodePath = image;
      } else if (probe.format == rust.ImageFormat.jpeg && probe.progressive) {
        decodePath = await ImageDerivatives.ensureBaseline(image);
      }
      if (!mounted) return;
      setState(() {
        _regions[image] = decodePath == null
            ? null
            : (size: size, decodePath: decodePath);
      });
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
                  // 长按：切换 tile 调试叠层（看图页原图层的加载过程）。不能再给
                  // tooltip：它自己就靠长按触发，会把手势抢走。
                  Semantics(
                    button: true,
                    label: context.l10n.ui.imageBrowserInfo,
                    child: IconButton(
                      icon: const Icon(LucideIcons.info, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                      onPressed: _showInfo,
                      onLongPress: () => OriginalImageView.debugOverlay.value =
                          !OriginalImageView.debugOverlay.value,
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
        // 仅当前页参与 Hero，避免离屏页与缩略图侧 tag 冲突。
        itemBuilder: (context, index) => HeroMode(
          enabled: hero && index == _current,
          child: _buildPage(index, hero: hero),
        ),
      );
    }
    // 竖直轴 scope 让 PhotoView 的识别器按需抢占手势竞技场：双指（捏合）立即抢，
    // 否则会被外层 DismissiblePage 的竖直拖动判成下拉；单指竖直仅在放大后图可平移时
    // 抢（平移到边缘 / 原始比例时不抢，下拉 dismiss 照常）。
    return PhotoViewGestureDetectorScope(axis: .vertical, child: gallery);
  }

  /// Hero 包在整个 PhotoView 外面（而非 photo_view 的 heroAttributes——那个 Hero 在图
  /// 解码完成前不存在，目的地缺席导致首次打开不起飞）；加载态显示缩略图占位，飞的就是它。
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
      // 能区域解码的图：child 尺寸 = 源像素，三层叠加，原图从不整解。控制器归页自己：
      // PageView 会销毁两页开外的页，复用的控制器会带着上次的平移量回来，整页白屏。
      page = _TilePage(
        image: image,
        decodePath: region.decodePath,
        size: region.size,
        overview: placeholder ?? MediaImage(image, tier: .m),
        active: index == _current,
        onScaleState: (state) => _onScaleState(index, state),
        onTap: () => Navigator.of(context).maybePop(),
      );
    } else if (local && _probing.contains(image)) {
      // 探头还没回来：只画 m 档。直接上原图会让引擎先整解一张 4096 封顶的位图进缓存，
      // 探头一回来它就被换掉，白解 50MB。
      page = PhotoView(
        imageProvider: placeholder ?? MediaImage(image, tier: .m),
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
    return MediaImage(image, tier: tier);
  }

  /// 保存当前图到相册。外链先经 [IHttpClient] 下载到缓存临时文件，成功与否统一 toast。
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
          final resp = await IHttpClient.get().requestBytes(
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

  /// URL 的扩展名（剥 query），拿不到按 .jpg 兜底（gal 依后缀选类型）。
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
      // 外链：图已在屏上（provider 命中缓存），只补分辨率。
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

    // 只读头：转正后的宽高，不把原图整解一遍。顺带说清这张图走的是哪条解码路。
    String? resolution;
    String? decode;
    try {
      final probe = await rust.ImageCompressor.probe(filePath: image);
      resolution = '${probe.width} × ${probe.height}';
      final region = _regions[image];
      decode = region != null
          ? (region.decodePath == image
                ? l10n.ui.imageBrowserDecodeTiled
                : l10n.ui.imageBrowserDecodeTiledBaseline)
          : probe.format == rust.ImageFormat.jpeg && probe.progressive
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

/// 走 tile 解码的一页：自己持有 [PhotoViewController]（[OriginalImageView] 靠它算可见区域），
/// 生命周期跟页元素一致。
class _TilePage extends StatefulWidget {
  final String image;
  final String decodePath;
  final Size size;
  final ImageProvider overview;
  final bool active;
  final ValueChanged<PhotoViewScaleState> onScaleState;
  final VoidCallback onTap;

  const _TilePage({
    required this.image,
    required this.decodePath,
    required this.size,
    required this.overview,
    required this.active,
    required this.onScaleState,
    required this.onTap,
  });

  @override
  State<_TilePage> createState() => _TilePageState();
}

class _TilePageState extends State<_TilePage> {
  final _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 上限跟分辨率走，不跟屏幕比例走：铺满屏再放 3 倍，或者放到每个源像素占 2 个物理
        // 像素（1:1 再放一倍，系统相册的口径），取大者。24000² 的图只按 covered×3 只能
        // 看到原图四成的清晰度。
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final covered = math.max(
          constraints.maxWidth / size.width,
          constraints.maxHeight / size.height,
        );
        return PhotoView.customChild(
          childSize: size,
          controller: _controller,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: math.max(covered * 3, 2 / dpr),
          scaleStateChangedCallback: widget.onScaleState,
          onTapUp: (_, _, _) => widget.onTap(),
          child: OriginalImageView(
            path: widget.image,
            decodePath: widget.decodePath,
            imageSize: size,
            controller: _controller,
            viewportSize: constraints.biggest,
            overview: widget.overview,
            active: widget.active,
          ),
        );
      },
    );
  }
}
