import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'editor_local_server.dart';
import 'media.dart';
import 'transport/editor_transport.dart';

typedef EditorRoles = Map<String, String>;

typedef EditorFont = ({String family, String path});

typedef DiaryLinkCandidate = ({String id, String label});

void _log(String msg, {Object? error, StackTrace? stack, int level = 0}) {
  developer.log(
    msg,
    name: 'MoodiaryEditor',
    error: error,
    stackTrace: stack,
    level: level,
  );
}

class MoodiaryEditor extends StatefulWidget {
  final MoodiaryEditorController? controller;

  final String initialContent;

  final String initialTitle;

  final bool readOnly;

  final String placeholder;

  final String titlePlaceholder;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onTitleChanged;

  final ValueChanged<int>? onActiveHeadingChanged;

  final VoidCallback? onReady;

  final void Function(List<String> images, int index)? onImageTap;

  final VoidCallback? onPickImage;

  final VoidCallback? onPickAudio;
  final VoidCallback? onPickVideo;

  final Future<Duration?> Function(String name, Duration position)?
  onVideoFullscreen;

  final Future<String?> Function(String dataUri, String name)? onSaveImage;

  final Future<List<DiaryLinkCandidate>> Function(String query)?
  onRequestLinkCandidates;

  final ValueChanged<String>? onOpenDiaryLink;

  final String? metaJson;

  final String? linksJson;

  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;
  final VoidCallback? onPickCategory;
  final VoidCallback? onAddTag;
  final ValueChanged<int>? onRemoveTag;

  final ValueChanged<String>? onChangeMood;

  final ValueChanged<String>? onChangeWeather;

  final VoidCallback? onClearWeather;

  final VoidCallback? onFetchWeather;

  final VoidCallback? onFetchPosition;

  final VoidCallback? onLocateForPlaces;

  final ValueChanged<String>? onPickPlace;

  final VoidCallback? onNewPlace;

  final VoidCallback? onManagePlaces;

  final VoidCallback? onClearPosition;

  final VoidCallback? onOpenGraph;

  final String saveStatus;

  final bool firstLineIndent;

  final double fontScale;

  final EditorRoles Function(Brightness brightness)? rolesResolver;

  final EditorFont? Function()? fontResolver;

  final MediaResolver? mediaResolver;

  final Future<String?> Function(String name)? mediaNameResolver;

  final String audioDefaultName;

  final WidgetBuilder? loadingBuilder;

  const MoodiaryEditor({
    super.key,
    this.controller,
    this.initialContent = '',
    this.initialTitle = '',
    this.readOnly = false,
    this.placeholder = '',
    this.titlePlaceholder = '',
    this.onChanged,
    this.onTitleChanged,
    this.onActiveHeadingChanged,
    this.onReady,
    this.onImageTap,
    this.onPickImage,
    this.onPickAudio,
    this.onPickVideo,
    this.onVideoFullscreen,
    this.onSaveImage,
    this.onRequestLinkCandidates,
    this.onOpenDiaryLink,
    this.metaJson,
    this.linksJson,
    this.onPickDate,
    this.onPickTime,
    this.onPickCategory,
    this.onAddTag,
    this.onRemoveTag,
    this.onChangeMood,
    this.onChangeWeather,
    this.onClearWeather,
    this.onFetchWeather,
    this.onFetchPosition,
    this.onLocateForPlaces,
    this.onPickPlace,
    this.onNewPlace,
    this.onManagePlaces,
    this.onClearPosition,
    this.onOpenGraph,
    this.saveStatus = 'idle',
    this.firstLineIndent = false,
    this.fontScale = 1.0,
    this.rolesResolver,
    this.fontResolver,
    this.mediaResolver,
    this.mediaNameResolver,
    this.audioDefaultName = '',
    this.loadingBuilder,
  });

  @override
  State<MoodiaryEditor> createState() => _MoodiaryEditorState();
}

class _MoodiaryEditorState extends State<MoodiaryEditor> {
  EditorTransport? _transport;
  bool _jsReady = false;
  bool _activated = false;
  Timer? _readyTimeout;

  final Completer<void> _fontReady = Completer<void>();

  bool _prepareStarted = false;

  String? _loadError;

  late String _lastContent = widget.initialContent;

  EditorFocusTarget _focusTarget = .none;

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);
  }

  @override
  void didUpdateWidget(MoodiaryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._unbind(this);
      widget.controller?._bind(this);
    }
    if (oldWidget.readOnly != widget.readOnly && _activated) {
      _setEditable(!widget.readOnly);
    }
    if (oldWidget.saveStatus != widget.saveStatus && _activated) {
      _setSaveStatus();
    }
    if (oldWidget.metaJson != widget.metaJson && _activated) {
      _setMeta();
    }
    if (oldWidget.linksJson != widget.linksJson && _activated) {
      _setLinks();
    }
    if ((oldWidget.firstLineIndent != widget.firstLineIndent ||
            oldWidget.fontScale != widget.fontScale) &&
        _activated) {
      _setTheme();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepareStarted) {
      _prepareStarted = true;
      _prepare();
    } else if (_activated) {
      _setTheme();
    }
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    widget.controller?._unbind(this);
    _transport?.dispose();
    super.dispose();
  }

  bool get _platformSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<void> _prepare() async {
    if (!_platformSupported) {
      if (mounted) {
        setState(() => _loadError = l10n.editor.unsupportedPlatform);
      }
      return;
    }
    final boot = <String, dynamic>{
      'platform': (Platform.isAndroid || Platform.isIOS) ? 'mobile' : 'desktop',
      'editable': !widget.readOnly,
      'placeholder': widget.placeholder,
      'titlePlaceholder': widget.titlePlaceholder,
      'saveStatus': widget.saveStatus,
      'theme': _themePayload(),
    };
    final server = getIt<EditorLocalServer>();
    server.mediaResolver ??= widget.mediaResolver;
    server.fontResolver ??= widget.fontResolver;
    server.mediaNameResolver ??= widget.mediaNameResolver;
    try {
      await server.ensureStarted();
    } catch (e, s) {
      _log('local server failed to start', error: e, stack: s, level: 1000);
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    if (!mounted) return;
    boot['mediaBase'] = server.mediaBase;
    boot['fontBase'] = server.fontBase;
    boot['mediaInfoBase'] = server.mediaInfoBase;
    boot['audioDefaultName'] = widget.audioDefaultName;
    try {
      await _buildController(server.pageUri(boot));
    } catch (e, s) {
      _log('webview controller build failed', error: e, stack: s, level: 1000);
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    _startReadyTimeout();
  }

  Future<void> _buildController(Uri pageUri) async {
    final transport = createEditorTransport();
    await transport.prepare(
      pageUri: pageUri,
      onMessage: _onMessage,
      onConsoleError: (m) => _log('JS console: $m', level: 1000),
      onWebError: (desc, code) =>
          _log('webResourceError: $desc (code $code)', level: 1000),
      debug: kDebugMode,
    );
    if (!mounted) {
      transport.dispose();
      return;
    }
    setState(() => _transport = transport);
  }

  void _startReadyTimeout() {
    _readyTimeout?.cancel();
    _readyTimeout = Timer(const Duration(seconds: 10), () {
      if (_jsReady || !mounted) return;
      _log(
        'TIMEOUT waiting for JS "ready" after 10s — '
        '页面或脚本可能挂了，检查 console / error 日志',
        level: 1000,
      );
      _activate();
    });
  }

  void _onMessage(String raw) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _log('bad JS message (not JSON): $raw', error: e, level: 900);
      return;
    }
    final type = (data['type'] as String?) ?? '';
    final payload = data['payload'];
    switch (type) {
      case 'ready':
        if (_jsReady) return;
        _jsReady = true;
        _readyTimeout?.cancel();
        _activate();
        return;
      case 'fontReady':
        if (!_fontReady.isCompleted) _fontReady.complete();
        return;
      case 'change':
        final content = payload is String ? payload : '';
        _lastContent = content;
        widget.onChanged?.call(content);
        return;
      case 'titleChange':
        widget.onTitleChanged?.call(payload is String ? payload : '');
        return;
      case 'focusChange':
        _focusTarget = switch (payload) {
          'editor' => EditorFocusTarget.editor,
          'title' => EditorFocusTarget.title,
          _ => EditorFocusTarget.none,
        };
        return;
      case 'activeHeading':
        final index = payload is int
            ? payload
            : (payload is num ? payload.toInt() : -1);
        widget.onActiveHeadingChanged?.call(index);
        return;
      case 'error':
        _log('JS error: $payload', level: 1000);
        return;
      case 'pickImage':
        widget.onPickImage?.call();
        return;
      case 'pickAudio':
        widget.onPickAudio?.call();
        return;
      case 'pickVideo':
        widget.onPickVideo?.call();
        return;
      case 'saveImage':
        if (payload is Map) {
          _handleSaveImage(Map<String, dynamic>.from(payload));
        }
        return;
      case 'imageTap':
        if (payload is Map) {
          final srcs = [...?(payload['srcs'] as List?)?.whereType<String>()];
          if (srcs.isNotEmpty) {
            final index = payload['index'];
            final i = index is num ? index.toInt() : 0;
            widget.onImageTap?.call(srcs, i < 0 || i >= srcs.length ? 0 : i);
            return;
          }
          final src = payload['src'];
          if (src is String && src.isNotEmpty) {
            widget.onImageTap?.call([src], 0);
          }
        }
        return;
      case 'videoFullscreen':
        if (payload is Map) {
          final name = payload['name'];
          final pos = payload['position'];
          if (name is String && name.isNotEmpty) {
            _handleVideoFullscreen(name, pos is num ? pos.toDouble() : 0);
          }
        }
        return;
      case 'requestLinkCandidates':
        if (payload is Map) {
          final reqId = payload['reqId'];
          final query = payload['query'];
          if (reqId is String) {
            _handleLinkCandidates(reqId, query is String ? query : '');
          }
        }
        return;
      case 'linkTap':
        if (payload is Map) {
          final id = payload['id'];
          if (id is String && id.isNotEmpty) widget.onOpenDiaryLink?.call(id);
        }
        return;
      case 'pickDate':
        widget.onPickDate?.call();
        return;
      case 'pickTime':
        widget.onPickTime?.call();
        return;
      case 'pickCategory':
        widget.onPickCategory?.call();
        return;
      case 'addTag':
        widget.onAddTag?.call();
        return;
      case 'removeTag':
        if (payload is Map) {
          final index = payload['index'];
          if (index is num) widget.onRemoveTag?.call(index.toInt());
        }
        return;
      case 'changeMood':
        if (payload is Map) {
          final mood = payload['mood'];
          if (mood is String && mood.isNotEmpty) {
            widget.onChangeMood?.call(mood);
          }
        }
        return;
      case 'changeWeather':
        if (payload is Map) {
          final code = payload['code'];
          if (code is String && code.isNotEmpty) {
            widget.onChangeWeather?.call(code);
          }
        }
        return;
      case 'clearWeather':
        widget.onClearWeather?.call();
        return;
      case 'fetchWeather':
        widget.onFetchWeather?.call();
        return;
      case 'fetchPosition':
        widget.onFetchPosition?.call();
        return;
      case 'locateForPlaces':
        widget.onLocateForPlaces?.call();
        return;
      case 'pickPlace':
        if (payload is Map) {
          final id = payload['id'];
          if (id is String && id.isNotEmpty) widget.onPickPlace?.call(id);
        }
        return;
      case 'newPlace':
        widget.onNewPlace?.call();
        return;
      case 'managePlaces':
        widget.onManagePlaces?.call();
        return;
      case 'clearPosition':
        widget.onClearPosition?.call();
        return;
      case 'openGraph':
        widget.onOpenGraph?.call();
        return;
    }
  }

  Future<void> _handleVideoFullscreen(String name, double seconds) async {
    final open = widget.onVideoFullscreen;
    if (open == null) return;
    final resumeAt = await open(
      name,
      Duration(milliseconds: (seconds * 1000).round()),
    );
    if (!mounted || resumeAt == null) return;
    await _run(
      'window.MoodiaryBridge.resumeVideo('
      '${jsonEncode(name)}, ${resumeAt.inMilliseconds / 1000})',
    );
  }

  Future<void> _handleLinkCandidates(String reqId, String query) async {
    List<DiaryLinkCandidate> list = const [];
    try {
      list = await widget.onRequestLinkCandidates?.call(query) ?? const [];
    } catch (e, s) {
      _log('onRequestLinkCandidates failed', error: e, stack: s, level: 1000);
    }
    final json = jsonEncode([
      for (final c in list) {'id': c.id, 'label': c.label},
    ]);
    await _run(
      'window.MoodiaryBridge.resolveLinkCandidates('
      '${jsonEncode(reqId)},${jsonEncode(json)})',
    );
  }

  Future<void> _handleSaveImage(Map<String, dynamic> p) async {
    final id = p['id'] as String?;
    final dataUri = p['dataUri'] as String?;
    final name = (p['name'] as String?) ?? '';
    if (id == null || dataUri == null) return;
    String? saved;
    try {
      saved = await widget.onSaveImage?.call(dataUri, name);
    } catch (e, s) {
      _log('onSaveImage failed', error: e, stack: s, level: 1000);
    }
    await _resolveImage(id, saved ?? '');
  }

  Future<void> _resolveImage(String id, String name) async {
    await _run(
      'window.MoodiaryBridge.resolveImage(${jsonEncode(id)},${jsonEncode(name)})',
    );
  }

  Future<void> _activate() async {
    if (_activated) return;
    await _setContent(widget.initialContent);
    await _setTitle(widget.initialTitle);
    await _setEditable(!widget.readOnly);
    await _setTheme();
    await _setSaveStatus();
    await _setMeta();
    await _setLinks();
    if (_jsReady &&
        widget.fontResolver?.call() != null &&
        !_fontReady.isCompleted) {
      await _fontReady.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (!mounted) return;
      await _setEditable(!widget.readOnly);
      await _setTheme();
      await _setSaveStatus();
      await _setMeta();
      await _setLinks();
    }
    if (!mounted) return;
    setState(() => _activated = true);
    widget.onReady?.call();
  }

  Map<String, dynamic> _themePayload() {
    final brightness = context.theme.brightness;
    final roles =
        widget.rolesResolver?.call(brightness) ?? _fallbackRoles(context);
    final font = widget.fontResolver?.call();
    return {
      'roles': roles,
      'dark': brightness == .dark,
      if (font != null) 'font': font.family,
      if (font != null) 'fontV': _fontVersion(font),
      'firstLineIndent': widget.firstLineIndent,
      'fontScale': widget.fontScale,
    };
  }

  static EditorRoles _fallbackRoles(BuildContext context) {
    final scheme = context.theme.colors;
    return {
      'surface': _hex(scheme.surface),
      'onSurface': _hex(scheme.onSurface),
      'onSurfaceVariant': _hex(scheme.onSurfaceVariant),
      'surfaceContainerLow': _hex(scheme.surfaceContainerLow),
      'surfaceContainer': _hex(scheme.surfaceContainer),
      'surfaceContainerHigh': _hex(scheme.surfaceContainerHigh),
      'surfaceContainerHighest': _hex(scheme.surfaceContainerHighest),
      'primary': _hex(scheme.primary),
      'onPrimary': _hex(scheme.onPrimary),
      'secondaryContainer': _hex(scheme.secondaryContainer),
      'onSecondaryContainer': _hex(scheme.onSecondaryContainer),
      'inverseSurface': _hex(scheme.inverseSurface),
      'onInverseSurface': _hex(scheme.onInverseSurface),
      'outlineVariant': _hex(scheme.outlineVariant),
      'error': _hex(scheme.error),
    };
  }

  static String _fontVersion(EditorFont font) {
    try {
      final mtime = File(font.path).statSync().modified.millisecondsSinceEpoch;
      return '${font.family}-$mtime';
    } catch (_) {
      return font.family;
    }
  }

  static String _hex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _setEditable(bool value) async {
    await _run('window.MoodiaryBridge.setEditable($value)');
  }

  Future<void> _setSaveStatus() async {
    await _run(
      'window.MoodiaryBridge.setSaveStatus(${jsonEncode(widget.saveStatus)})',
    );
  }

  Future<void> _setMeta() async {
    await _run(
      'window.MoodiaryBridge.setMeta(${jsonEncode(widget.metaJson ?? '')})',
    );
  }

  Future<void> _setLinks() async {
    await _run(
      'window.MoodiaryBridge.setLinks(${jsonEncode(widget.linksJson ?? '')})',
    );
  }

  Future<void> _setTheme() async {
    await _run(
      'window.MoodiaryBridge.setTheme(${jsonEncode(_themePayload())})',
    );
  }

  Future<void> _setContent(String content) async {
    _lastContent = content;
    await _run('window.MoodiaryBridge.setContent(${jsonEncode(content)})');
  }

  Future<void> _setTitle(String title) async {
    await _run('window.MoodiaryBridge.setTitle(${jsonEncode(title)})');
  }

  Future<void> _scrollToHeading(int index) async {
    await _run('window.MoodiaryBridge.scrollToHeading($index)');
  }

  Future<double> _getScrollY() async {
    final raw = await _transport?.runForResult(
      'window.MoodiaryBridge.getScrollY()',
    );
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  Future<void> _swapDocument({
    required String content,
    required String title,
    double scrollY = 0,
  }) async {
    await _setContent(content);
    await _setTitle(title);
    await _run('window.MoodiaryBridge.setScrollY($scrollY)');
  }

  Future<void> _focus() async {
    await _run('window.MoodiaryBridge.focus()');
  }

  Future<void> _blur() async {
    await _run('window.MoodiaryBridge.blur()');
  }

  Future<void> _focusTitle() async {
    await _run('window.MoodiaryBridge.focusTitle()');
  }

  Future<void> _insertMedia(String name, [String alt = '']) async {
    await _run(
      'window.MoodiaryBridge.insertMedia('
      '${jsonEncode(name)},${jsonEncode(alt)})',
    );
  }

  Future<void> _insertAudio(String name) async {
    await _run('window.MoodiaryBridge.insertAudio(${jsonEncode(name)})');
  }

  Future<void> _insertVideo(String name) async {
    await _run('window.MoodiaryBridge.insertVideo(${jsonEncode(name)})');
  }

  Future<void> _run(String source) async {
    await _transport?.run(source);
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.theme.colors.surface;
    final transport = _transport;
    final loadError = _loadError;

    return ColoredBox(
      color: surface,
      child: Stack(
        fit: .expand,
        children: [
          if (transport != null) transport.buildView(),
          if (loadError != null)
            Center(
              child: Padding(
                padding: const .all(24),
                child: Text(
                  context.l10n.editor.loadFailed(error: loadError),
                  textAlign: .center,
                ),
              ),
            )
          else if (!_activated)
            ColoredBox(
              color: surface,
              child:
                  widget.loadingBuilder?.call(context) ??
                  const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

enum EditorFocusTarget { none, editor, title }

class MoodiaryEditorController {
  _MoodiaryEditorState? _state;

  void _bind(_MoodiaryEditorState state) => _state = state;

  void _unbind(_MoodiaryEditorState state) {
    if (identical(_state, state)) _state = null;
  }

  bool get isReady => _state?._activated ?? false;

  Future<void> setContent(String content) async {
    await _state?._setContent(content);
  }

  Future<String> getContent() async {
    return _state?._lastContent ?? '';
  }

  Future<void> focus() async {
    await _state?._focus();
  }

  Future<void> blur() async {
    await _state?._blur();
  }

  Future<void> focusTitle() async {
    await _state?._focusTitle();
  }

  EditorFocusTarget get focusTarget => _state?._focusTarget ?? .none;

  bool get hasFocus => focusTarget != .none;

  Future<void> insertMedia(String name, {String alt = ''}) async {
    await _state?._insertMedia(name, alt);
  }

  Future<void> insertAudio(String name) async {
    await _state?._insertAudio(name);
  }

  Future<void> insertVideo(String name) async {
    await _state?._insertVideo(name);
  }

  Future<void> scrollToHeading(int index) async {
    await _state?._scrollToHeading(index);
  }

  Future<double> getScrollY() async {
    return (await _state?._getScrollY()) ?? 0;
  }

  Future<void> swapDocument({
    required String content,
    required String title,
    double scrollY = 0,
  }) async {
    await _state?._swapDocument(
      content: content,
      title: title,
      scrollY: scrollY,
    );
  }
}
