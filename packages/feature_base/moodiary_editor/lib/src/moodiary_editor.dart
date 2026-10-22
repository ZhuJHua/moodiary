import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:mui/mui.dart';

import 'editor_page.dart';
import 'ime/ime_panel.dart';
import 'media.dart';
import 'toolbar/editor_command.dart';
import 'toolbar/editor_state.dart';
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

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onTitleChanged;

  final ValueChanged<int>? onActiveHeadingChanged;

  final void Function(List<String> images, int index)? onImageTap;

  final ValueChanged<String>? onUrlTap;

  final void Function(String src, String name, String? mime)? onAttachmentTap;

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

  final bool firstLineIndent;

  final double fontScale;

  final EditorRoles Function(Brightness brightness)? rolesResolver;

  final EditorFont? Function()? fontResolver;

  final MediaResolver? mediaResolver;

  const MoodiaryEditor({
    super.key,
    this.controller,
    this.initialContent = '',
    this.initialTitle = '',
    this.readOnly = false,
    this.onChanged,
    this.onTitleChanged,
    this.onActiveHeadingChanged,
    this.onImageTap,
    this.onUrlTap,
    this.onAttachmentTap,
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
    this.firstLineIndent = false,
    this.fontScale = 1.0,
    this.rolesResolver,
    this.fontResolver,
    this.mediaResolver,
  });

  @override
  State<MoodiaryEditor> createState() => _MoodiaryEditorState();
}

class _MoodiaryEditorState extends State<MoodiaryEditor> {
  // Android WebView 的选择手柄由原生主题绘制，颜色只能推给原生
  static final _selectionHandle = SelectionHandleApi();
  static int? _handleColor;

  static final _keyboard = EditorKeyboardApi();
  static int? _keyboardViewId;

  EditorTransport? _transport;
  bool _jsReady = false;
  bool _activated = false;
  Timer? _readyTimeout;

  final Completer<void> _fontReady = Completer<void>();

  bool _prepareStarted = false;

  String? _loadError;

  String? _lastStateRaw;

  final _flushes = <String, Completer<void>>{};
  int _flushSeq = 0;

  InputSuspension? _overlay;

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
      if (!widget.readOnly) unawaited(_attachKeyboard());
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
    _syncHandleColor();
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
    unawaited(_overlay?.resume());
    widget.controller?._unbind(this);
    final viewId = _transport?.nativeViewId;
    if (viewId != null && viewId == _keyboardViewId) {
      _keyboardViewId = null;
      unawaited(_keyboard.detach());
    }
    _transport?.dispose();
    super.dispose();
  }

  static bool get _nativeKeyboard => Platform.isAndroid || Platform.isIOS;

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
    try {
      final page = await resolveEditorPage();
      if (!mounted) return;
      await _buildController(page);
    } catch (e, s) {
      _log('webview controller build failed', error: e, stack: s, level: 1000);
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    _startReadyTimeout();
  }

  Future<void> _buildController(EditorPage page) async {
    final transport = createEditorTransport();
    await transport.prepare(
      page: page,
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
      case 'boot':
        if (payload is Map && payload['reqId'] is String) {
          unawaited(_respond(payload['reqId'] as String, _bootPayload()));
        }
        return;
      case 'resolveMedia':
        if (payload is Map && payload['reqId'] is String) {
          unawaited(
            _handleResolveMedia(
              payload['reqId'] as String,
              payload['items'] is List ? payload['items'] as List : const [],
            ),
          );
        }
        return;
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
        widget.onChanged?.call(payload is String ? payload : '');
        return;
      case 'titleChange':
        widget.onTitleChanged?.call(payload is String ? payload : '');
        return;
      case 'focusChange':
        if (payload == 'editor' || payload == 'title') {
          unawaited(_attachKeyboard());
        }
        widget.controller?._focus.value = switch (payload) {
          'editor' => EditorFocusTarget.editor,
          'title' => EditorFocusTarget.title,
          _ => EditorFocusTarget.none,
        };
        return;
      case 'state':
        if (payload is! Map) return;
        final raw = jsonEncode(payload);
        if (raw == _lastStateRaw) return;
        _lastStateRaw = raw;
        widget.controller?._state.value = EditorState.fromJson(
          Map<String, Object?>.from(payload),
        );
        return;
      case 'flushed':
        if (payload is Map) _flushes.remove(payload['reqId'])?.complete();
        return;
      case 'editorTap':
        widget.controller?.panel.showKeyboard();
        return;
      case 'overlay':
        if (payload is Map && payload['open'] == true) {
          _overlay ??= widget.controller?.suspendInput();
        } else {
          unawaited(_overlay?.resume());
          _overlay = null;
        }
        return;
      case 'urlTap':
        if (payload is Map && payload['href'] is String) {
          widget.onUrlTap?.call(payload['href'] as String);
        }
        return;
      case 'attachmentTap':
        if (payload is Map) {
          final src = payload['src'];
          final name = payload['name'];
          final mime = payload['mime'];
          if (src is String && _isSafeMediaName(src)) {
            widget.onAttachmentTap?.call(
              src,
              name is String ? name : src,
              mime is String ? mime : null,
            );
          }
        }
        return;
      case 'copy':
        if (payload is Map && payload['text'] is String) {
          unawaited(Clipboard.setData(.new(text: payload['text'] as String)));
          toast.success(message: l10n.common.copied);
        }
        return;
      case 'contentError':
        _log('content rejected by editor: $payload', level: 1000);
        return;
      case 'searchState':
        if (payload is Map) {
          final query = payload['query'];
          final total = payload['total'];
          final current = payload['current'];
          widget.controller?._search.value = (
            query: query is String ? query : '',
            total: total is num ? total.toInt() : 0,
            current: current is num ? current.toInt() : 0,
          );
        }
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

  Map<String, dynamic> _bootPayload() => {
    'editable': !widget.readOnly,
    'locale': LocaleSettings.currentLocale.languageCode,
    'theme': _themePayload(),
  };

  Future<void> _respond(String reqId, Object? value) => _run(
    'window.MoodiaryBridge.respond('
    '${jsonEncode(reqId)},${jsonEncode(jsonEncode(value))})',
  );

  Future<void> _handleResolveMedia(String reqId, List<dynamic> items) async {
    final resolver = widget.mediaResolver;
    final urls = <String, String?>{};
    await Future.wait([
      for (final item in items.whereType<Map<dynamic, dynamic>>())
        () async {
          final name = item['name'];
          if (name is! String) return;
          final poster = item['poster'] == true;
          String? url;
          if (resolver != null && _isSafeMediaName(name)) {
            try {
              final resolved = await resolver(name, poster: poster);
              if (resolved != null) url = Uri.file(resolved.path).toString();
            } catch (e, s) {
              _log(
                'media resolve failed: $name',
                error: e,
                stack: s,
                level: 1000,
              );
            }
          }
          urls[poster ? '$name#poster' : name] = url;
        }(),
    ]);
    if (mounted) await _respond(reqId, urls);
  }

  // video- 长度须 ≥42：宿主 substring(6, 42) 取 uuid 依赖该长度
  static bool _isSafeMediaName(String name) {
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      return false;
    }
    if (name.startsWith('image-')) return name.length > 'image-'.length;
    if (name.startsWith('audio-')) return name.length > 'audio-'.length;
    if (name.startsWith('video-')) return name.length >= 42;
    if (name.startsWith('file-')) return name.length > 'file-'.length;
    return false;
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
      await _setMeta();
      await _setLinks();
    }
    if (!mounted) return;
    if (!widget.readOnly) unawaited(_attachKeyboard());
    setState(() => _activated = true);
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
      if (font != null) 'fontUrl': Uri.file(font.path).toString(),
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

  void _syncHandleColor() {
    if (!Platform.isAndroid) return;
    final argb = context.theme.colors.primary.toARGB32();
    if (argb == _handleColor) return;
    _handleColor = argb;
    unawaited(_selectionHandle.setColor(argb));
  }

  Future<void> _setTheme() async {
    await _run(
      'window.MoodiaryBridge.setTheme(${jsonEncode(_themePayload())})',
    );
  }

  Future<void> _setContent(String content) async {
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
    await _focusWebView();
    await _run('window.MoodiaryBridge.focus()');
  }

  Future<void> _focusWebView() async {
    if (await _attachKeyboard()) await _keyboard.focusWebView();
  }

  Future<void> _blur() async {
    await _run('window.MoodiaryBridge.blur()');
  }

  Future<void> _holdSelection() async {
    await _run('window.MoodiaryBridge.holdSelection()');
  }

  Future<void> _focusTitle() async {
    await _focusWebView();
    await _run('window.MoodiaryBridge.focusTitle()');
  }

  Future<void> _exec(EditorCommand command, Map<String, Object?>? args) async {
    await _run(
      'window.MoodiaryBridge.exec(${jsonEncode(command.name)}'
      '${args == null ? '' : ',${jsonEncode(args)}'})',
    );
  }

  Future<void> _flush() async {
    if (_transport == null || !_jsReady) return;
    final reqId = 'f${_flushSeq++}';
    final done = _flushes[reqId] = Completer<void>();
    await _run('window.MoodiaryBridge.flush(${jsonEncode(reqId)})');
    await done.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => _flushes.remove(reqId),
    );
  }

  Future<void> _setPanelMode(bool value) async {
    await _run('window.MoodiaryBridge.setPanelMode($value)');
  }

  // 原生键盘只服务一个 WebView：就绪即 attach 以赶在键盘动画前，聚焦时再夺回
  Future<bool> _attachKeyboard() async {
    final viewId = _transport?.nativeViewId;
    if (!_nativeKeyboard || viewId == null) return false;
    if (_keyboardViewId == viewId) return true;
    try {
      await _keyboard.attach(viewId);
    } on PlatformException catch (e, s) {
      _log('keyboard attach failed', error: e, stack: s, level: 1000);
      return false;
    }
    _keyboardViewId = viewId;
    return true;
  }

  Future<bool> _suppressKeyboard(bool suppressed) async {
    if (!await _attachKeyboard()) return false;
    if (suppressed) await _setPanelMode(true);
    final ok = await _keyboard.setKeyboardSuppressed(suppressed);
    if (!suppressed) await _setPanelMode(false);
    return ok;
  }

  Future<void> _dismissKeyboard() async {
    widget.controller?._focus.value = .none;
    await _setPanelMode(false);
    await _blur();
    // iOS 的收起标记不会自行清除，安卓的是一次性的
    if (Platform.isIOS && await _attachKeyboard()) {
      await _keyboard.setKeyboardSuppressed(false);
    }
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
            ),
        ],
      ),
    );
  }
}

enum EditorFocusTarget { none, editor, title }

typedef EditorSearchState = ({String query, int total, int current});

class MoodiaryEditorController {
  _MoodiaryEditorState? _host;

  final _state = ValueNotifier<EditorState>(.empty);
  final _focus = ValueNotifier<EditorFocusTarget>(.none);
  final _search = ValueNotifier<EditorSearchState?>(null);
  final _searchOpen = ValueNotifier<bool>(false);

  late final ImeTarget imeTarget = _EditorImeTarget(this);

  final panel = ImePanelController<EditorPanel>();

  int _suspensions = 0;
  EditorFocusTarget _resumeTo = .none;
  Future<void> _suspended = Future.value();

  bool get panelOpen => panel.type == .custom && panel.panel != .block;

  void _bind(_MoodiaryEditorState state) => _host = state;

  void _unbind(_MoodiaryEditorState state) {
    if (identical(_host, state)) _host = null;
  }

  ValueListenable<EditorState> get state => _state;

  ValueListenable<EditorFocusTarget> get focusTarget => _focus;

  ValueListenable<EditorSearchState?> get search => _search;

  ValueListenable<bool> get searchOpen => _searchOpen;

  Future<void> exec(EditorCommand command, [Map<String, Object?>? args]) async {
    await _host?._exec(command, args);
  }

  Future<void> flush() async {
    await _host?._flush();
  }

  void openSearch() => _searchOpen.value = true;

  Future<void> closeSearch() async {
    _searchOpen.value = false;
    _search.value = null;
    await exec(.clearSearch);
  }

  Future<void> focus() async {
    await _host?._focus();
  }

  Future<void> blur() async {
    await _host?._blur();
  }

  Future<void> focusTitle() async {
    await _host?._focusTitle();
  }

  Future<void> holdSelection() async {
    await _host?._holdSelection();
  }

  InputSuspension suspendInput() {
    if (_suspensions++ == 0) {
      _resumeTo = _focus.value;
      _suspended = _suspend(_resumeTo);
    }
    return InputSuspension._(this, _suspended);
  }

  Future<T> withInputSuspended<T>(Future<T> Function() open) async {
    final suspension = suspendInput();
    try {
      await suspension.ready;
      return await open();
    } finally {
      await suspension.resume();
    }
  }

  Future<void> _suspend(EditorFocusTarget focus) async {
    final active = focus != .none || panel.type != .none;
    if (active) await holdSelection();
    FocusManager.instance.primaryFocus?.unfocus();
    if (active) await panel.release();
  }

  Future<void> _endSuspension() async {
    if (--_suspensions > 0) return;
    final target = _resumeTo;
    _resumeTo = .none;
    await _suspended;
    if (target == .none) return;
    // 弹层里的输入框下一帧才失焦并让 Flutter 收键盘，先等它收完，否则刚拉起的键盘会被一并收掉
    await _textFieldReleased();
    await panel.keyboardGone();
    // 权限框、相机等外部界面回来时窗口还没拿回焦点，此时拉不起键盘
    await _appResumed();
    if (_suspensions > 0 || _focus.value != .none) return;
    switch (target) {
      case .editor:
        await focus();
      case .title:
        await focusTitle();
      case .none:
    }
  }

  Future<void> scrollToHeading(int index) async {
    await _host?._scrollToHeading(index);
  }

  Future<double> getScrollY() async {
    return (await _host?._getScrollY()) ?? 0;
  }

  Future<void> swapDocument({
    required String content,
    required String title,
    double scrollY = 0,
  }) async {
    await _host?._swapDocument(
      content: content,
      title: title,
      scrollY: scrollY,
    );
  }
}

Future<void> _textFieldReleased() async {
  final manager = FocusManager.instance;
  bool editing() =>
      manager.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;
  if (!editing()) return;
  final released = Completer<void>();
  void onFocus() {
    if (!editing() && !released.isCompleted) released.complete();
  }

  manager.addListener(onFocus);
  await released.future;
  manager.removeListener(onFocus);
}

Future<void> _appResumed() async {
  if (WidgetsBinding.instance.lifecycleState == .resumed) return;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(onResume: resumed.complete);
  await resumed.future;
  listener.dispose();
}

final class InputSuspension {
  final MoodiaryEditorController _controller;
  final Future<void> ready;
  bool _resumed = false;

  InputSuspension._(this._controller, this.ready);

  Future<void> resume() async {
    if (_resumed) return;
    _resumed = true;
    await _controller._endSuspension();
  }
}

final class _EditorImeTarget implements ImeTarget {
  final MoodiaryEditorController _controller;

  _EditorImeTarget(this._controller);

  @override
  late final ValueListenable<bool> focused = _FocusedListenable(
    _controller._focus,
  );

  @override
  Future<bool> suppressKeyboard(bool suppressed) async =>
      await _controller._host?._suppressKeyboard(suppressed) ?? false;

  @override
  Future<void> dismiss() async => _controller._host?._dismissKeyboard();
}

class _FocusedListenable extends ValueNotifier<bool> {
  _FocusedListenable(ValueListenable<EditorFocusTarget> source)
    : super(source.value != EditorFocusTarget.none) {
    source.addListener(() => value = source.value != EditorFocusTarget.none);
  }
}
