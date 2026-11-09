part of '../moodiary_editor.dart';

String _formatDuration(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
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
  MVideoPlaybackController? _video;
  components.AudioPlaybackController? _audio;
  String get _name => widget.view.node.attrs['src'] as String? ?? '';
  bool _controls = true;
  Timer? _hide;
  int _resolveGeneration = 0;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    widget.host._media[_name] = this;
    Future<({String path, String mime})?> resolve(bool poster) async {
      if (_name.startsWith('https://') ||
          _name.startsWith('http://') ||
          widget.view.node.type == 'image' && _name.startsWith('data:image/')) {
        return poster ? null : (path: _name, mime: '');
      }
      if (!_isSafeMediaName(_name)) return null;
      try {
        return await widget.host._configuration.mediaResolver?.call(
          _name,
          poster: poster,
        );
      } catch (error, stack) {
        _log(
          'media resolve failed: $_name',
          error: error,
          stack: stack,
          level: 1000,
        );
        return null;
      }
    }

    final generation = ++_resolveGeneration;
    _source = resolve(false);
    unawaited(
      _source.then((source) {
        if (mounted && generation == _resolveGeneration && source != null) {
          if (widget.view.node.type == 'video') _initializeVideo(source.path);
          if (widget.view.node.type == 'audio') {
            final audio = _audio = components.AudioPlaybackController()
              ..progress.addListener(_updated);
            unawaited(
              audio.prepare(source.path).catchError((
                Object error,
                StackTrace stack,
              ) {
                _log('audio metadata read failed', error: error, stack: stack);
              }),
            );
          }
        }
      }),
    );
    _poster = resolve(true);
  }

  @override
  void didUpdateWidget(_MediaNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.node.attrs['src'] != _name) {
      oldWidget.host._media.remove(oldWidget.view.node.attrs['src']);
      _video?.dispose();
      _video = null;
      _audio?.dispose();
      _audio = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (identical(widget.host._media[_name], this)) {
      widget.host._media.remove(_name);
    }
    _video?.state.removeListener(_updated);
    _video?.geometry.removeListener(_updated);
    _video?.progress.removeListener(_updated);
    _audio?.progress.removeListener(_updated);
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  void _select() {
    if (widget.host.readOnly) {
      if (widget.view.node.type == 'image') widget.host.previewImage(_name);
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

  void _initializeVideo(String path) {
    if (_video != null) return;
    _video = MVideoPlaybackController(
      source: path.startsWith('http://') || path.startsWith('https://')
          ? VideoSource.network(Uri.parse(path))
          : VideoSource.file(path),
      portFactory: components.videoPlayerPortFactory,
      autoPlay: false,
    );
    _video!.state.addListener(_updated);
    _video!.geometry.addListener(_updated);
    _video!.progress.addListener(_updated);
    final video = _video!;
    unawaited(
      () async {
        await video.initialize();
        // Mount the texture before seeking so paused AVPlayer/ExoPlayer decodes
        // its initial picture without autoplay or an audible playback pulse.
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && _video == video) {
          await revealVideoFirstFrame(video);
        }
      }().catchError((Object error, StackTrace stack) {
        _log('video preview frame failed', error: error, stack: stack);
      }),
    );
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

  Future<void> resumeAt(Duration position) async {
    await _video?.seekTo(position);
    await _video?.play();
    _keepControls();
  }

  Future<void> _fullscreen() async {
    final video = _video;
    if (video == null) return;
    final position = video.progress.value.position;
    await video.pause();
    _keepControls();
    final resume = await widget.host._configuration.onVideoFullscreen?.call(
      _name,
      position,
    );
    if (mounted && resume != null) await resumeAt(resume);
  }

  Widget _image(String path, {BoxFit fit = BoxFit.contain}) {
    if (path.startsWith('data:image/')) {
      try {
        return Image.memory(
          UriData.parse(path).contentAsBytes(),
          width: widget.view.width,
          fit: fit,
          errorBuilder: (_, _, _) => _missing(LucideIcons.image),
        );
      } on FormatException {
        return _missing(LucideIcons.image);
      }
    }
    return path.startsWith('http')
        ? Image.network(
            path,
            width: widget.view.width,
            fit: fit,
            errorBuilder: (_, _, _) => _missing(LucideIcons.image),
          )
        : Image(
            image: FastImage(path),
            width: widget.view.width,
            fit: fit,
            frameBuilder: (context, child, frame, synchronous) =>
                frame == null ? _missing(LucideIcons.image) : child,
            errorBuilder: (_, _, _) => _missing(LucideIcons.image),
          );
  }

  Widget _missing(IconData icon) => SizedBox(
    width: widget.view.width,
    height: widget.view.width * 2 / 3,
    child: ColoredBox(
      color: context.theme.colors.surfaceContainer,
      child: Icon(icon, color: context.theme.colors.onSurfaceVariant),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<({String path, String mime})?>(
    future: _source,
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
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _select,
          onDoubleTap: () =>
              type == 'image' ? widget.host.previewImage(_name) : _select(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      );
    },
  );
}

// highlight.js ids from the shared highlighter, shown by their usual names.
const _codeLanguageNames = {
  'arduino': 'Arduino',
  'bash': 'Bash',
  'c': 'C',
  'cpp': 'C++',
  'csharp': 'C#',
  'css': 'CSS',
  'diff': 'Diff',
  'go': 'Go',
  'graphql': 'GraphQL',
  'ini': 'INI',
  'java': 'Java',
  'javascript': 'JavaScript',
  'json': 'JSON',
  'kotlin': 'Kotlin',
  'less': 'Less',
  'lua': 'Lua',
  'makefile': 'Makefile',
  'markdown': 'Markdown',
  'objectivec': 'Objective-C',
  'perl': 'Perl',
  'php': 'PHP',
  'php-template': 'PHP template',
  'python': 'Python',
  'python-repl': 'Python REPL',
  'r': 'R',
  'ruby': 'Ruby',
  'rust': 'Rust',
  'scss': 'SCSS',
  'shell': 'Shell',
  'sql': 'SQL',
  'swift': 'Swift',
  'typescript': 'TypeScript',
  'vbnet': 'VB.NET',
  'wasm': 'WebAssembly',
  'xml': 'HTML / XML',
  'yaml': 'YAML',
};

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
      final id => _codeLanguageNames[id] ?? id,
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
    final current = Text(_label(language), style: style);
    return Row(
      children: [
        if (widget.readOnly)
          Padding(padding: const .symmetric(horizontal: 4), child: current)
        else
          MenuAnchor(
            style: const MenuStyle(
              maximumSize: WidgetStatePropertyAll(Size(220, 320)),
            ),
            menuChildren: [
              for (final id in <String?>[
                null,
                'plaintext',
                ..._codeLanguageNames.keys,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  current,
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
          ),
        const Spacer(),
        chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? LucideIcons.check : LucideIcons.copy,
                size: 14,
                color: context.theme.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(_copied ? labels.codeCopied : labels.codeCopy, style: style),
            ],
          ),
          () => unawaited(_copy()),
        ),
      ],
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
