part of '../moodiary_editor.dart';

class _MediaPlayback extends ChangeNotifier {
  _MediaPlayback(this.host, this.type, this.name, this.source) {
    unawaited(_initialize());
  }

  final MoodiaryEditorHost host;
  final String type, name;
  final Future<({String path, String mime})?> source;
  MVideoPlaybackController? video;
  components.AudioPlaybackController? audio;
  bool disposed = false;
  int views = 0;
  bool _retained = false;

  Future<void> _initialize() async {
    final resolved = await source;
    if (disposed || resolved == null) return;
    if (type == 'audio') {
      final controller = audio = host._audioControllerFactory();
      controller.progress.addListener(_updated);
      notifyListeners();
      try {
        await controller.prepare(resolved.path);
      } catch (error, stack) {
        _log('audio metadata read failed', error: error, stack: stack);
      }
    } else {
      final path = resolved.path;
      final controller = video = MVideoPlaybackController(
        source: VideoSource.fromPath(path),
        portFactory: host._videoPortFactory,
        autoPlay: false,
      );
      controller.state.addListener(_updated);
      controller.geometry.addListener(_updated);
      controller.progress.addListener(_updated);
      notifyListeners();
      await controller.initialize();
      await WidgetsBinding.instance.endOfFrame;
      if (disposed) return;
      try {
        if (views > 0 && !_retained) await revealVideoFirstFrame(controller);
      } catch (error, stack) {
        _log('video preview frame failed', error: error, stack: stack);
      }
    }
  }

  void _updated() {
    if (disposed) return;
    final audioProgress = audio?.progress.value;
    final videoState = video?.state.value;
    _retained |=
        audioProgress?.playing == true ||
        (audioProgress?.position ?? Duration.zero) > Duration.zero ||
        videoState?.isPlayIntent == true ||
        videoState is VideoPaused ||
        videoState is VideoCompleted ||
        videoState is VideoSeeking && videoState.target > Duration.zero;
    notifyListeners();
  }

  Future<void> pause() async {
    if (disposed) return;
    await audio?.pause();
    if (!disposed) await video?.pause();
  }

  Future<void> resumeAt(Duration position) async {
    if (disposed || video == null) return;
    _retained = true;
    await video!.seekTo(position);
    if (!disposed) await video!.play();
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    video?.state.removeListener(_updated);
    video?.geometry.removeListener(_updated);
    video?.progress.removeListener(_updated);
    audio?.progress.removeListener(_updated);
    video?.dispose();
    audio?.dispose();
    super.dispose();
  }
}

extension _HostMedia on MoodiaryEditorHost {
  Future<({String path, String mime})?> _resolveMedia(
    ft.Node node, {
    bool poster = false,
  }) {
    final name = node.attrs['src'] as String? ?? '';
    final key = (name, poster), cached = _mediaSources.get((name, poster));
    if (cached != null) return Future.value(cached);
    final pending = _mediaRequests.get(key);
    if (pending != null) return pending;
    final request = _loadMedia(node, poster: poster);
    _mediaRequests.put(key, request);
    unawaited(
      request.whenComplete(() {
        if (identical(_mediaRequests.get(key), request)) {
          _mediaRequests.remove(key);
        }
      }),
    );
    return request;
  }

  Future<({String path, String mime})?> _loadMedia(
    ft.Node node, {
    required bool poster,
  }) async {
    final name = node.attrs['src'] as String? ?? '';
    final key = (name, poster);
    final generation = _generation;
    ({String path, String mime})? source;
    if (isNetworkMedia(name) ||
        node.type == 'image' && name.startsWith('data:image/')) {
      source = poster ? null : (path: name, mime: '');
    } else {
      if (!_isSafeMediaName(name)) return null;
      try {
        source = await _configuration.mediaResolver?.call(name, poster: poster);
      } catch (error, stack) {
        _log(
          'media resolve failed: $name',
          error: error,
          stack: stack,
          level: 1000,
        );
      }
    }
    if (!_disposed && generation == _generation && source != null) {
      _mediaSources.put(key, source);
    }
    return source;
  }

  void _probeDocumentImages(ft.Node doc) {
    final images = <String, ft.Node>{};
    doc.descendants((node, position, parent, index) {
      if (node.type == 'image') {
        final name = node.attrs['src'] as String? ?? '';
        if (_isSafeMediaName(name)) images.putIfAbsent(name, () => node);
      }
      return !node.isTextblock && node.type != 'image';
    });
    _pendingImageProbes = images.values.iterator;
    _imageProbeGeneration = _generation;
    _pumpImageProbes();
  }

  void _pumpImageProbes() {
    if (_disposed || _imageProbeGeneration != _generation) {
      _pendingImageProbes = null;
      return;
    }
    while (_activeImageProbes < 4) {
      final pending = _pendingImageProbes;
      if (pending == null) return;
      if (!pending.moveNext()) {
        _pendingImageProbes = null;
        return;
      }
      _activeImageProbes++;
      unawaited(
        _probeImage(pending.current, _generation).whenComplete(() {
          _activeImageProbes--;
          _pumpImageProbes();
        }),
      );
    }
  }

  Future<void> _probeImage(ft.Node node, int generation) async {
    try {
      final source = await _resolveMedia(node);
      if (_disposed || generation != _generation || source == null) return;
      if (isNetworkMedia(source.path) || source.path.startsWith('data:')) {
        return;
      }
      final probe = await _imageProbe(filePath: source.path);
      if (_disposed || generation != _generation) return;
      if (probe.width <= 0 || probe.height <= 0) return;
      _recordImageHeader(
        node.attrs['src'] as String,
        probe.width / probe.height,
      );
    } catch (_) {}
  }

  _MediaPlayback? _borrowMedia(ft.TiptapNodeView view) {
    if (_disposed ||
        !identical(editor.state.doc.nodeAt(view.position), view.node)) {
      return null;
    }
    final entry = _media.putIfAbsent(
      view.position,
      () => _MediaPlayback(
        this,
        view.node.type,
        view.node.attrs['src'] as String? ?? '',
        _resolveMedia(view.node),
      ),
    );
    entry.views++;
    return entry;
  }

  void _returnMedia(_MediaPlayback entry) {
    if (entry.disposed) return;
    entry.views--;
    if (entry.views == 0 && !entry._retained) {
      _media.removeWhere((_, value) => identical(value, entry));
      entry.dispose();
      if (identical(_fullscreenMedia, entry)) _fullscreenMedia = null;
    }
  }

  void _syncMedia() {
    if (_media.isEmpty) return;
    final transaction = editor.lastTransaction;
    if (transaction == null || !identical(transaction.before, _lastDocument)) {
      _releaseAllMedia();
      return;
    }
    final next = <int, _MediaPlayback>{};
    for (final entry in _media.entries) {
      final mapped = transaction.mapping.mapResult(entry.key);
      final node = mapped.deleted ? null : editor.state.doc.nodeAt(mapped.pos);
      if (node?.type == entry.value.type &&
          node?.attrs['src'] == entry.value.name) {
        next[mapped.pos] = entry.value;
      } else {
        entry.value.dispose();
      }
    }
    _media
      ..clear()
      ..addAll(next);
    if (_fullscreenMedia?.disposed == true) _fullscreenMedia = null;
  }

  void _releaseAllMedia() {
    for (final entry in _media.values) {
      entry.dispose();
    }
    _media.clear();
    _fullscreenMedia = null;
  }

  Future<void> _openMediaFullscreen(_MediaPlayback entry) async {
    if (entry.disposed || entry.video == null) return;
    _fullscreenMedia = entry;
    entry.views++;
    try {
      final position = entry.video!.progress.value.position;
      await entry.video!.pause();
      if (entry.disposed) return;
      final resume = await _configuration.onVideoFullscreen?.call(
        entry.name,
        position,
      );
      if (resume != null && !entry.disposed) await entry.resumeAt(resume);
    } finally {
      _returnMedia(entry);
    }
  }
}
