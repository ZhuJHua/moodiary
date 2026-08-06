import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/src/basic/action_bar.dart';
import 'package:moodiary_ui/src/basic/sheet.dart';
import 'package:moodiary_ui/src/common/toast.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

/// 全屏图片浏览器：左右翻页、双指缩放、下拉手势关闭（背景与操作钮随手势渐隐）、
/// Hero 飞入飞出（传 [heroPrefix] 启用，缩略图侧 tag 须为 `'$heroPrefix-<image>'`）。
/// 底部操作：保存到相册 / 图片信息（分辨率、大小、格式、修改时间）。
/// [images] 每项为本地绝对路径或 http(s) 外链。
class MoodiaryImageBrowser extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? heroPrefix;

  /// 缩略图侧的 ResizeImage 解码宽度。传入后全图解码完成前先显示同缓存键的缩略图
  /// （命中内存缓存，首帧即有像素）——Hero 首次打开就能起飞，全图就绪后无缝替换。
  /// 必须与缩略图侧完全一致（同路径 FileImage + 同 width）才会命中缓存。
  final int? placeholderCacheWidth;

  const MoodiaryImageBrowser({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroPrefix,
    this.placeholderCacheWidth,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? heroPrefix,
    int? placeholderCacheWidth,
  }) {
    return context.pushTransparentRoute(
      MoodiaryImageBrowser(
        images: images,
        initialIndex: initialIndex,
        heroPrefix: heroPrefix,
        placeholderCacheWidth: placeholderCacheWidth,
      ),
    );
  }

  @override
  State<MoodiaryImageBrowser> createState() => _MoodiaryImageBrowserState();
}

class _MoodiaryImageBrowserState extends State<MoodiaryImageBrowser> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;

  /// 操作钮不透明度，随下拉手势渐隐（DismissiblePage onDragUpdate 回传）。
  double _chrome = 1.0;
  bool _saving = false;

  /// 当前页是否放大（非 initial 缩放态）。放大时禁掉 PageView 的水平滚动，
  /// 让横向平移完全归 PhotoView（竖直平移由 scope 的 shouldMove 抢占解决）。
  bool _zoomed = false;

  static bool _isNetwork(String image) =>
      image.startsWith('http://') || image.startsWith('https://');

  ImageProvider _providerOf(String image) => _isNetwork(image)
      ? CachedNetworkImageProvider(image)
      : FileImage(File(image)) as ImageProvider;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                  IconButton(
                    tooltip: context.l10n.imageBrowserInfo,
                    icon: const Icon(LucideIcons.info, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                    onPressed: _showInfo,
                  ),
                  IconButton(
                    tooltip: context.l10n.imageBrowserSave,
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
        onPageChanged: (i) => setState(() {
          _current = i;
          _zoomed = false;
        }),
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
    final page = PhotoView(
      imageProvider: _providerOf(image),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      scaleStateChangedCallback: (state) {
        if (index != _current) return;
        final zoomed = state != .initial;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      },
      onTapUp: (_, _, _) => Navigator.of(context).maybePop(),
      loadingBuilder: (_, _) => placeholder != null
          ? Image(
              image: placeholder,
              fit: .contain,
              width: .infinity,
              height: .infinity,
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorBuilder: (_, _, _) => const Center(
        child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
      ),
    );
    if (!hero) return page;
    return Hero(tag: '${widget.heroPrefix}-$image', child: page);
  }

  ImageProvider? _placeholderOf(String image) {
    final width = widget.placeholderCacheWidth;
    if (width == null || _isNetwork(image)) return null;
    return ResizeImage(FileImage(File(image)), width: width);
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
          ? toast.success(message: l10n.imageBrowserSaved)
          : toast.error(message: l10n.imageBrowserSaveFailed);
    } catch (_) {
      toast.error(message: l10n.imageBrowserSaveFailed);
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
    await showMoodiarySheet<void>(
      context,
      builder: (sheetContext) => MoodiarySheetScaffold<void>(
        title: sheetContext.l10n.imageBrowserInfo,
        icon: LucideIcons.info,
        actions: [MoodiaryAction(label: sheetContext.l10n.ok, isPrimary: true)],
        child: _ImageInfoSheet(info: info),
      ),
    );
  }

  Future<_ImageInfoData> _loadInfo(String image) async {
    if (_isNetwork(image)) {
      // 外链：图已在屏上（provider 命中缓存），只补分辨率。
      String? resolution;
      try {
        final size = await MediaManager.getImageSize(
          _providerOf(image),
        ).timeout(const Duration(seconds: 3));
        resolution = '${size.width.toInt()} × ${size.height.toInt()}';
      } catch (_) {}
      return _ImageInfoData(url: image, resolution: resolution);
    }

    final file = File(image);
    int? length;
    DateTime? modified;
    Uint8List? bytes;
    try {
      length = await file.length();
      modified = await file.lastModified();
      bytes = await file.readAsBytes();
    } catch (_) {}

    String? resolution;
    if (bytes != null) {
      try {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        resolution = '${descriptor.width} × ${descriptor.height}';
        descriptor.dispose();
        buffer.dispose();
      } catch (_) {}
    }

    final unit = length == null ? null : AppFiles.bytesToUnits(length);
    final ext = p.extension(image).replaceFirst('.', '').toUpperCase();
    return _ImageInfoData(
      name: p.basename(image),
      resolution: resolution,
      size: unit == null ? null : '${unit['size']} ${unit['unit']}',
      format: ext.isEmpty ? null : ext,
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
  final DateTime? modified;

  const _ImageInfoData({
    this.name,
    this.url,
    this.resolution,
    this.size,
    this.format,
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
      if (info.name != null) (l10n.imageBrowserInfoName, info.name!),
      if (info.url != null) (l10n.imageBrowserInfoUrl, info.url!),
      if (info.resolution != null)
        (l10n.imageBrowserInfoResolution, info.resolution!),
      if (info.size != null) (l10n.imageBrowserInfoSize, info.size!),
      if (info.format != null) (l10n.imageBrowserInfoFormat, info.format!),
      if (info.modified != null)
        (
          l10n.imageBrowserInfoModified,
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
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(value, style: context.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
