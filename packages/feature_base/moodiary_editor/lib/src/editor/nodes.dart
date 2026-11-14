part of '../moodiary_editor.dart';

String _formatFileSize(Object? size) {
  if (size is! num || size <= 0) return '';
  if (size < 1024) return '${size.round()} B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _MediaNode extends StatefulWidget {
  const _MediaNode({required this.host, required this.view});
  final MoodiaryEditorHost host;
  final ft.TiptapNodeView view;
  @override
  State<_MediaNode> createState() => _MediaNodeState();
}

class _MediaNodeState extends State<_MediaNode> {
  late Future<({String path, String mime})?> _source;
  late Future<({String path, String mime})?> _poster;
  late int _generation;
  String? _imagePath;
  ImageProvider? _imageProvider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageInfo? _imageFrame;
  _MediaPlayback? _playback;
  MVideoPlaybackController? get _video => _playback?.video;
  components.AudioPlaybackController? get _audio => _playback?.audio;
  String get _name => widget.view.node.attrs['src'] as String? ?? '';
  bool _controls = true;
  Timer? _hide;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    _generation = widget.host._generation;
    _detachImage();
    if (widget.view.node.type == 'audio' || widget.view.node.type == 'video') {
      _playback = widget.host._borrowMedia(widget.view);
      _playback?.addListener(_updated);
    }
    _source = _playback?.source ?? widget.host._resolveMedia(widget.view.node);
    _poster = widget.host._resolveMedia(widget.view.node, poster: true);
  }

  @override
  void didUpdateWidget(_MediaNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host ||
        _generation != widget.host._generation ||
        oldWidget.view.node.attrs['src'] != _name ||
        oldWidget.view.node.type != widget.view.node.type ||
        _playback?.disposed == true ||
        _playback != null &&
            !identical(widget.host._media[widget.view.position], _playback)) {
      _detachPlayback(oldWidget.host);
      _resolve();
    }
  }

  void _detachPlayback(MoodiaryEditorHost host) {
    _hide?.cancel();
    _controls = true;
    final playback = _playback;
    _playback = null;
    if (playback == null) return;
    playback.removeListener(_updated);
    host._returnMedia(playback);
  }

  @override
  void dispose() {
    _detachImage();
    _detachPlayback(widget.host);
    super.dispose();
  }

  void _select() {
    if (widget.host.readOnly) {
      if (widget.view.node.type == 'image') {
        widget.host.previewImage(widget.view.position);
      }
      if (widget.view.node.type == 'attachment') {
        widget.host._configuration.onAttachmentTap?.call(
          _name,
          widget.view.node.attrs['name'] as String? ?? _name,
          widget.view.node.attrs['mime'] as String?,
        );
      }
    } else {
      widget.host.bodyFocus.requestFocus();
      widget.host.editor.setSelection(
        ft.NodeSelection(widget.host.editor.state.doc, widget.view.position),
      );
    }
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  void _keepControls() {
    _hide?.cancel();
    setState(() => _controls = true);
    if (_video?.state.value.isPlayIntent == true) {
      _hide = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _controls = false);
      });
    }
  }

  Future<void> _fullscreen() async {
    final playback = _playback;
    if (playback == null) return;
    _keepControls();
    await widget.host._openMediaFullscreen(playback);
    if (mounted) _keepControls();
  }

  void _detachImage() {
    if (_imageListener case final listener?) {
      _imageStream?.removeListener(listener);
    }
    _imageListener = null;
    _imageStream = null;
    _imageProvider = null;
    _imagePath = null;
    _imageFrame?.dispose();
    _imageFrame = null;
  }

  Widget _image(String path, {BoxFit fit = BoxFit.contain}) {
    if (_imagePath != path) {
      _detachImage();
      try {
        _imageProvider = path.startsWith('data:image/')
            ? MemoryImage(UriData.parse(path).contentAsBytes())
            : isNetworkMedia(path)
            ? NetworkImage(path)
            : FastImage(path, tier: FastImageTier.m);
      } on FormatException {
        return _missing(LucideIcons.image);
      }
      _imagePath = path;
      if (widget.view.node.type == 'image') {
        final host = widget.host, generation = _generation, name = _name;
        _imageStream = _imageProvider!.resolve(
          createLocalImageConfiguration(context),
        );
        _imageListener = ImageStreamListener((info, synchronous) {
          final ratio = info.image.width / info.image.height;
          if (!mounted || host._disposed || generation != host._generation) {
            info.dispose();
            return;
          }
          _imageFrame?.dispose();
          _imageFrame = info;
          final changed = host._recordImageRatio(name, ratio, probed: false);
          if (!synchronous && changed) setState(() {});
        }, onError: (Object error, StackTrace? stack) {});
        _imageStream!.addListener(_imageListener!);
      }
    }
    return Image(
      image: _imageProvider!,
      width: widget.view.width,
      height: widget.view.node.type == 'image'
          ? widget.host.estimateNodeHeight(widget.view.node, widget.view.width)
          : null,
      fit: fit,
      frameBuilder: (context, child, frame, synchronous) =>
          frame == null ? _missing(LucideIcons.image) : child,
      errorBuilder: (_, _, _) => _missing(LucideIcons.image),
    );
  }

  Widget _missing(IconData icon) => SizedBox(
    width: widget.view.width,
    height: widget.view.node.type == 'image'
        ? widget.host.estimateNodeHeight(widget.view.node, widget.view.width)
        : widget.view.width * 2 / 3,
    child: ColoredBox(
      color: context.theme.colors.surfaceContainer,
      child: Icon(icon, color: context.theme.colors.onSurfaceVariant),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.host._imageChanges,
    builder: (context, _) => _build(context),
  );

  Widget _build(
    BuildContext context,
  ) => FutureBuilder<({String path, String mime})?>(
    key: ValueKey((widget.host, _generation, _name, widget.view.node.type)),
    future: _source,
    initialData: widget.host._mediaSources.get((_name, false)),
    builder: (context, snapshot) {
      final path = snapshot.data?.path;
      final type = widget.view.node.type;
      Widget child;
      if (type == 'image') {
        child = path == null ? _missing(LucideIcons.image) : _image(path);
      } else if (type == 'video') {
        final video = _video,
            ratio = (_video?.geometry.value.naturalAspect ?? 16 / 9).clamp(
              4 / 5,
              16 / 9,
            ),
            width = math.min(widget.view.width, 480 * ratio);
        child = SizedBox(
          width: width,
          height: width / ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<({String path, String mime})?>(
                future: _poster,
                initialData: widget.host._mediaSources.get((_name, true)),
                builder: (context, poster) => poster.data == null
                    ? ColoredBox(
                        color: context.theme.colors.surfaceContainerHigh,
                      )
                    : _image(poster.data!.path, fit: BoxFit.cover),
              ),
              if (video?.port != null && video!.state.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: video.geometry.value.naturalAspect ?? ratio,
                    child: components.defaultVideoSurfaceBuilder(video.port!),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _select();
                  _keepControls();
                },
              ),
              if (_controls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _videoControls(video),
                ),
            ],
          ),
        );
      } else if (type == 'audio') {
        child = _audioControls(path);
      } else {
        final name =
                widget.view.node.attrs['name'] as String? ??
                context.l10n.editor.toolbar.attachment,
            size = _formatFileSize(widget.view.node.attrs['size']),
            scale = widget.host._configuration.fontScale,
            family = widget.host._configuration.fontResolver?.call()?.family;
        child = Container(
          width: widget.view.width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.theme.colors.surface,
            border: Border.all(color: context.theme.colors.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.theme.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (_name.contains('.') ? _name.split('.').last : '?')
                      .toUpperCase()
                      .characters
                      .take(4)
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: _textStyle(
                    size: 11 * scale,
                    family: family,
                    weight: FontWeight.w700,
                    color: context.theme.colors.onSurfaceVariant,
                  ).copyWith(letterSpacing: 11 * scale * .02),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 15 * scale * 1.35,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _textStyle(
                          family: family,
                          size: 15 * scale,
                          height: 1.35,
                          weight: FontWeight.w500,
                          color: context.theme.colors.onSurface,
                        ),
                      ),
                    ),
                    if (size.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 12 * scale * 1.3,
                        child: Text(
                          size,
                          style: _textStyle(
                            family: family,
                            size: 12 * scale,
                            height: 1.3,
                            color: context.theme.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.view.width >= 140) ...[
                const SizedBox(width: 12),
                Icon(
                  LucideIcons.arrowUpRight,
                  size: 18,
                  color: context.theme.colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        );
      }
      child = ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
      if (type == 'image' && !_name.startsWith('data:')) {
        final card = child;
        child = Hero(
          tag: (widget.host, widget.view.position),
          flightShuttleBuilder:
              (context, animation, direction, fromContext, toContext) {
                final gallery = direction == HeroFlightDirection.push
                    ? toContext
                    : fromContext;
                final routeAnimation = ModalRoute.of(gallery)?.animation;
                final frame = _imageFrame;
                if (frame == null) return card;
                final source = direction == HeroFlightDirection.push
                    ? fromContext
                    : toContext;
                return _ImageFlight(
                  frame: frame,
                  cardSize: (source.findRenderObject()! as RenderBox).size,
                  animation: routeAnimation ?? animation,
                );
              },
          child: child,
        );
      }
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _select,
          onDoubleTap: type == 'image' && !widget.host.readOnly
              ? () => widget.host.previewImage(widget.view.position)
              : null,
          child: child,
        ),
      );
    },
  );
}

class _ImageFlight extends StatefulWidget {
  const _ImageFlight({
    required this.frame,
    required this.cardSize,
    required this.animation,
  });

  final ImageInfo frame;
  final Size cardSize;
  final Animation<double> animation;

  @override
  State<_ImageFlight> createState() => _ImageFlightState();
}

class _ImageFlightState extends State<_ImageFlight> {
  late final ImageInfo _frame = widget.frame.clone();

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = applyBoxFit(
        BoxFit.contain,
        widget.cardSize,
        constraints.biggest,
      ).destination;
      return Center(
        child: SizedBox.fromSize(
          size: size,
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (context, child) => ClipRRect(
              borderRadius: BorderRadius.circular(
                12 * (1 - widget.animation.value),
              ),
              child: child,
            ),
            child: RawImage(
              image: _frame.image,
              scale: _frame.scale,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    },
  );
}

class _CodeHeader extends StatefulWidget {
  const _CodeHeader({required this.node, required this.readOnly});
  final ft.TiptapNodeView node;
  final bool readOnly;
  @override
  State<_CodeHeader> createState() => _CodeHeaderState();
}

class _CodeHeaderState extends State<_CodeHeader> {
  bool _copied = false;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _label(String? language) {
    final labels = context.l10n.editor.content;
    return switch (language) {
      null || '' => labels.codeAutoDetect,
      'plaintext' || 'text' || 'txt' => labels.plainText,
      final id => components.codeLanguageNames[id] ?? id,
    };
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.node.node.textContent));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.l10n.editor.content,
        style = context.theme.typography.labelSmall.onSurfaceVariant.copyWith(
          fontSize: 12,
        ),
        language = widget.node.node.attrs['language'] as String?;
    Widget chip(Widget child, VoidCallback? onTap) => InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const .symmetric(horizontal: 4, vertical: 4),
        child: child,
      ),
    );
    final current = Text(
      _label(language),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final languagePicker = widget.readOnly
        ? Padding(padding: const .symmetric(horizontal: 4), child: current)
        : MenuAnchor(
            style: const MenuStyle(
              maximumSize: WidgetStatePropertyAll(Size(220, 320)),
            ),
            menuChildren: [
              for (final id in <String?>[
                null,
                'plaintext',
                ...components.codeLanguageNames.keys,
              ])
                MenuItemButton(
                  trailingIcon: id == language
                      ? const Icon(LucideIcons.check, size: 16)
                      : null,
                  onPressed: () => widget.node.updateAttrs({'language': id}),
                  child: Text(_label(id)),
                ),
            ],
            builder: (context, menu, _) => chip(
              Row(
                children: [
                  Expanded(child: current),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: context.theme.colors.onSurfaceVariant,
                  ),
                ],
              ),
              () => menu.isOpen ? menu.close() : menu.open(),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(child: languagePicker),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: chip(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _copied ? LucideIcons.check : LucideIcons.copy,
                    size: 14,
                    color: context.theme.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _copied ? labels.codeCopied : labels.codeCopy,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              () => unawaited(_copy()),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
Future<void> revealVideoFirstFrame(MVideoPlaybackController video) async {
  if (!video.state.value.isInitialized || video.state.value.isPlayIntent) {
    return;
  }
  await video.port?.seekTo(const Duration(milliseconds: 1));
  if (video.state.value.isInitialized && !video.state.value.isPlayIntent) {
    await video.port?.seekTo(Duration.zero);
  }
}
