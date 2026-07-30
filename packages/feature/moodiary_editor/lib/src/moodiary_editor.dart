import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'editor_local_server.dart';
import 'media.dart';
import 'transport/editor_transport.dart';

/// 编辑器主题种子：种子色 + Material 3 变体名（由宿主 app 注入，见 [MoodiaryEditor.seedResolver]）。
typedef EditorSeed = ({Color seed, String variant});

/// 当前激活的自定义字体：家族名 + 字体文件磁盘路径（由宿主 app 注入，见 [MoodiaryEditor.fontResolver]）。
/// webview 经本地服务按需读该字体文件，用 @font-face 加载，使编辑器正文与 App 同字体。
typedef EditorFont = ({String family, String path});

/// 双链 `[[` 候选：目标日记业务 id + 显示标签（标题或日期）。宿主从仓库提供，见
/// [MoodiaryEditor.onRequestLinkCandidates]。
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

/// 基于 TipTap 的编辑器（嵌入式，仅渲染正文；AppBar / 阅读态元信息由 Flutter 原生承载）。
/// webview 经 [EditorTransport] 抽象：Android/iOS/macOS 走 webview_flutter，Windows 走
/// flutter_inappwebview（WebView2，中文输入法候选窗定位正确）；Linux 暂不支持。
/// 页面（assets/editor/ 多文件产物）与正文媒体统一由 [EditorLocalServer]（静态服务，基于
/// Rust(hyper) [IHttpServer]，127.0.0.1 随机端口 + 随机 token）供给。
///
/// Bridge：Flutter → JS 走 [EditorTransport.run] 调 `window.MoodiaryBridge.*`（[_run]）；
/// JS → Flutter 走 [kEditorChannel]（webview_flutter 命名 channel / inappwebview callHandler，
/// web 侧统一调 `window.MoodiaryEditor.postMessage`），统一回到 [_onMessage]。
/// 引导数据（平台 / 可编辑 / 主题 / placeholder / mediaBase）经 base64url 挂在页面 URL 的
/// `?boot=` 上 —— web 侧 readBoot 同步解析，首帧即用。正文媒体以文件名落库，显示时由 web 侧
/// 拼上 boot.mediaBase 前缀，经本地服务按需从磁盘读字节（支持 HTTP Range；音视频用原生
/// `<audio>`/`<video>` 在 webview 内内联播放，视频海报用同名 `?poster=1` 取缩略图）—— 懒加载、二进制、省内存。
class MoodiaryEditor extends StatefulWidget {
  final MoodiaryEditorController? controller;

  /// 初始内容：TipTap 文档 JSON 串（tiptap 日记）或旧 markdown 文本（只读查看，编辑器自动识别）。
  final String initialContent;

  /// 初始标题（日记标题）；ready 后经 setTitle 推给 webview 顶部标题区。不进正文文档。
  final String initialTitle;

  final bool readOnly;

  /// 正文空文档时的占位提示（对应 title 的「标题」占位）；仅可编辑态显示（web 侧
  /// Placeholder 扩展 showOnlyWhenEditable 默认 true）。经 boot.placeholder 下发。
  final String placeholder;

  final ValueChanged<String>? onChanged;

  /// 顶部标题区输入回调：入参为当前标题串。宿主据此写入 Diary.title（不进正文、不进 content JSON）。
  final ValueChanged<String>? onTitleChanged;

  /// 滚动时「当前顶部可见标题」下标变化回调（文档序，-1 表示无）；供目录（TOC）高亮当前项。
  final ValueChanged<int>? onActiveHeadingChanged;

  final VoidCallback? onReady;

  /// 点击正文图片回调：入参为全文图片列表（存储文件名或外链 URL）与被点下标，
  /// 供宿主开原生画廊左右翻页。可不传（不预览）。
  final void Function(List<String> images, int index)? onImageTap;

  /// 编辑器内触发"插入图片"回调：上层弹原生选图、存盘，再 insertMedia 插入。
  final VoidCallback? onPickImage;

  /// 编辑器内触发"插入音频 / 视频"回调：上层弹原生选取、存盘，再 insertAudio/insertVideo 插入。
  final VoidCallback? onPickAudio;
  final VoidCallback? onPickVideo;

  /// 正文视频请求全屏：webview 内不做全屏（两端平台差异都试过，观感不过关），改为把播放
  /// **交接**给宿主的原生播放器 —— 与「点图 → 原生画廊」同一条路子。
  /// 入参为裸文件名与当前位置；返回退出时的位置，编辑器据此回灌给正文里那个 `<video>`
  /// （返回 null 表示不回灌）。
  final Future<Duration?> Function(String name, Duration position)? onVideoFullscreen;

  /// 拖拽 / 粘贴图片回调：入参 data URI + 原文件名，返回存盘文件名（失败返回 null），
  /// 编辑器据此兑现 web 侧上传 Promise。
  final Future<String?> Function(String dataUri, String name)? onSaveImage;

  /// 双链 `[[` 触发时按查询串搜索候选日记（id + 标签，按相关性排序、限量）；编辑器每次输入都调用，
  /// query 为空时宿主可回最近若干篇。不传则无候选。
  final Future<List<DiaryLinkCandidate>> Function(String query)?
  onRequestLinkCandidates;

  /// 点击双链 chip：入参为目标日记业务 id，上层据此导航。
  final ValueChanged<String>? onOpenDiaryLink;

  /// 工具栏首位「详情」按钮回调（打开元信息面板，宿主实现）。
  final VoidCallback? onOpenDetails;

  /// 自动保存状态，透传给编辑器右下角气泡：'saving' / 'saved' / 'failed' / 其它（不显示）。
  final String saveStatus;

  /// 全局「首行缩进」开关：随主题一起下发（见 [_seedTheme]），web 侧据此对正文段落切 CSS
  /// `text-indent`。变更时经 [didUpdateWidget] 实时推给已打开的编辑器。
  final bool firstLineIndent;

  /// 全局「字号」缩放（1.0 = 标准）：随主题一起下发，web 侧置 CSS `--app-font-scale`
  /// 缩放正文与标题根字号（层级/行内代码为 em，自动跟随）。变更同样实时推送。
  final double fontScale;

  /// 主题种子解析器（宿主 app 提供）：每次需要下发主题时实时读取当前种子色 + 变体；
  /// 明暗由 `Theme.of(context)` 推断。不传则用 Material 默认主色。
  final EditorSeed Function()? seedResolver;

  /// 当前自定义字体解析器（宿主 app 提供）：每次下发主题时实时读取当前激活字体（家族 + 磁盘路径）；
  /// 返回 null 表示用系统字体。用于把 App 的自定义字体带进 webview 编辑器正文。
  final EditorFont? Function()? fontResolver;

  /// 正文媒体磁盘解析器（宿主 app 提供）：注入给 [EditorLocalServer] 按需读盘供图。
  final MediaResolver? mediaResolver;

  /// 加载遮罩构建器（宿主 app 提供）；不传则用居中 [CircularProgressIndicator]。
  final WidgetBuilder? loadingBuilder;

  const MoodiaryEditor({
    super.key,
    this.controller,
    this.initialContent = '',
    this.initialTitle = '',
    this.readOnly = false,
    this.placeholder = '',
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
    this.onOpenDetails,
    this.saveStatus = 'idle',
    this.firstLineIndent = false,
    this.fontScale = 1.0,
    this.seedResolver,
    this.fontResolver,
    this.mediaResolver,
    this.loadingBuilder,
  });

  @override
  State<MoodiaryEditor> createState() => _MoodiaryEditorState();
}

class _MoodiaryEditorState extends State<MoodiaryEditor> {
  EditorTransport? _transport;
  bool _jsReady = false; // JS 端 MoodiaryBridge 已就绪
  bool _activated = false; // 内容已下发完毕，可撤掉遮罩
  Timer? _readyTimeout;

  /// 自定义字体加载完成（web 侧 fontReady 事件）。撤遮罩前等它（带超时），避免字体换脸闪动。
  final Completer<void> _fontReady = Completer<void>();

  bool _prepareStarted = false;


  /// 本地服务启动失败 / 平台不支持：无 webview 可挂，撤遮罩、显示错误占位（非空即进入错误态）。
  String? _loadError;

  /// 最近一次内容（来自 change 事件 / setContent），TipTap 文档 JSON 串。getContent 直接返回，免 JS 回程。
  late String _lastContent = widget.initialContent;

  /// webview 内焦点位置（focusChange 事件维护）。
  EditorFocusTarget _focusTarget = EditorFocusTarget.none;

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
    // 阅读 / 编辑切换：复用同一 webview 实例，只切可编辑性，不重建。
    if (oldWidget.readOnly != widget.readOnly && _activated) {
      _setEditable(!widget.readOnly);
    }
    if (oldWidget.saveStatus != widget.saveStatus && _activated) {
      _setSaveStatus();
    }
    // 首行缩进 / 字号变化：随主题通道即时下发（复用 setTheme，不重建 webview）。
    if ((oldWidget.firstLineIndent != widget.firstLineIndent ||
            oldWidget.fontScale != widget.fontScale) &&
        _activated) {
      _setTheme();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次：构建 boot（需要 context 取主题）并启动本地服务；之后：主题变化推给网页。
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

  /// Android/iOS/macOS（webview_flutter）+ Windows（inappwebview）有实现；Linux 暂不支持。
  bool get _platformSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  /// 启动本地服务，拼出带 boot 的页面地址，再构建 webview。boot 字段与 web 侧 EditorBoot 对应。
  Future<void> _prepare() async {
    // 非支持平台（Linux）：给错误占位而非崩溃。
    if (!_platformSupported) {
      if (mounted) {
        setState(
          () => _loadError =
              '当前平台暂不支持编辑器 / Editor not supported on this platform.',
        );
      }
      return;
    }
    final boot = <String, dynamic>{
      'platform': (Platform.isAndroid || Platform.isIOS) ? 'mobile' : 'desktop',
      'editable': !widget.readOnly,
      'placeholder': widget.placeholder,
      'saveStatus': widget.saveStatus,
      // 首帧即用正确配色：web 侧据此用 material-color-utilities 生成整套配色。
      'theme': _seedTheme(),
    };
    final server = EditorLocalServer.instance;
    server.mediaResolver ??= widget.mediaResolver;
    server.fontResolver ??= widget.fontResolver;
    try {
      await server.ensureStarted();
    } catch (e, s) {
      _log('local server failed to start', error: e, stack: s, level: 1000);
      // 服务起不来就没有 webview 可挂：撤掉加载遮罩、给出错误占位，而非永久转圈。
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    if (!mounted) return;
    boot['mediaBase'] = server.mediaBase;
    boot['fontBase'] = server.fontBase;
    try {
      await _buildController(server.pageUri(boot));
    } catch (e, s) {
      _log('webview controller build failed', error: e, stack: s, level: 1000);
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    // 覆盖「webview 始终不回 ready」的失败路径，到点 _activate 撤遮罩、露出错误 UI。
    _startReadyTimeout();
  }

  /// 经 [EditorTransport] 配置 webview 并加载页面。JS 通道 / 各项设置 / document-start shim
  /// 都在 transport 内于加载前完成，页面首帧脚本即可见到 `window.MoodiaryEditor`。prepare
  /// 完成后 setState 挂载 [EditorTransport.buildView]；ready 回调里的 [_run] 即可用。
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

  /// 命名 [JavaScriptChannel] 回调：raw 即 web 侧 postMessage 的 JSON 字符串。
  void _onMessage(String raw) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _log('bad JS message (not JSON): $raw', error: e, level: 900);
      return;
    }
    final type = (data['type'] as String?) ?? '';
    // payload 形态随事件而异：change/error 为字符串，saveImage 为对象。
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
      case 'details':
        widget.onOpenDetails?.call();
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
          // 旧版页面资源只带单图 src 的兜底。
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
    }
  }

  /// 拉取双链候选并经 `resolveLinkCandidates(reqId, json)` 回传 web 侧（json 为 [{id,label}] 串）；
  /// 失败用空列表回传，避免 web 侧 Promise 永挂。
  /// 交接给宿主的原生播放器，回来把位置灌回 webview。
  /// 位置在桥上走秒（double）—— webview 侧 currentTime 就是秒，避免两侧各做一次换算。
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

  /// 存盘后经 `resolveImage(id, name)` 兑现 web 侧上传 Promise；失败用空名兑现，
  /// 避免 Promise 永挂。
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

  /// 内容替换完成后才淡出遮罩，避免瞬间看到上一篇日记的内容。可编辑性 / 主题已在 boot 中下发。
  Future<void> _activate() async {
    if (_activated) return;
    await _setContent(widget.initialContent);
    await _setTitle(widget.initialTitle);
    // boot 在 _prepare 时捕获了 editable / theme 快照；加载窗口内若 readOnly / 主题变了，
    // didUpdateWidget / didChangeDependencies 因 _activated 尚未置位而跳过，故在此用当前
    // widget 值对齐（幂等，开销可忽略）。
    await _setEditable(!widget.readOnly);
    await _setTheme();
    await _setSaveStatus();
    // 有自定义字体时等 web 侧 fontReady（boot 即开始加载）再撤遮罩，字体换脸发生在遮罩后面；
    // 超时兜底防坏字体文件卡死。仅正常 ready 路径等（ready 超时兜底进来的 webview 已经不健康）。
    if (_jsReady &&
        widget.fontResolver?.call() != null &&
        !_fontReady.isCompleted) {
      await _fontReady.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (!mounted) return;
      // 等待期间（可达 2s）readOnly / 主题等可能已变，而 didUpdateWidget / didChangeDependencies
      // 因未激活被跳过 —— 用当前 widget 值重推对齐，避免揭幕后停在旧快照。
      await _setEditable(!widget.readOnly);
      await _setTheme();
      await _setSaveStatus();
    }
    if (!mounted) return;
    setState(() => _activated = true);
    widget.onReady?.call();
  }

  /// 仅下发「种子色 + 明暗 + 变体」；web 侧用 material-color-utilities 生成整套
  /// Material 3 配色（与 [ThemeManager.buildColorScheme] 同算法）再映射到编辑器配色。
  Map<String, dynamic> _seedTheme() {
    final resolved = widget.seedResolver?.call();
    final seed = resolved?.seed ?? Theme.of(context).colorScheme.primary;
    final variant = resolved?.variant ?? 'tonalSpot';
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 字体家族随主题一起下发：web 侧据此用 FontFace 加载（src 用 boot.fontBase），
    // 缺省（系统字体）不带该字段。字体文件由本地服务经 fontResolver 供给。
    final font = widget.fontResolver?.call();
    return {
      'seed': _hex(seed),
      'dark': dark,
      'variant': variant,
      if (font != null) 'font': font.family,
      if (font != null) 'fontV': _fontVersion(font),
      'firstLineIndent': widget.firstLineIndent,
      'fontScale': widget.fontScale,
    };
  }

  /// 字体 URL 破缓存串：family + 文件 mtime。字体响应带长缓存头（见 editor_local_server），
  /// 重导入同名字体靠 mtime 变化换 URL。
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

  Future<void> _setTheme() async {
    await _run('window.MoodiaryBridge.setTheme(${jsonEncode(_seedTheme())})');
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

  /// 页内双链跳转：同一 webview 原地换文档（正文 + 标题 + 滚动位置），不重建。
  /// undo 栈由 web 侧随 setContent 重置；可编辑性走 readOnly prop（didUpdateWidget）。
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

  /// 执行 JS（fire-and-forget）；JS 运行时异常由 [EditorTransport.run] 内部吞掉，
  /// 避免打断 10s 就绪超时兜底。
  Future<void> _run(String source) async {
    await _transport?.run(source);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final transport = _transport;
    final loadError = _loadError;

    return ColoredBox(
      color: surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (transport != null) transport.buildView(),
          // 本地服务启动失败 / 平台不支持：无 webview 可显示，给出错误占位（替代永久加载遮罩）。
          if (loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '编辑器加载失败 / Failed to load editor.\n$loadError',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          // 单一加载遮罩：盖住本地服务启动 + webview 加载 + 内容装载全过程，就绪后硬撤掉，
          // 消除「闪白 / 两次 loading」。
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

/// webview 内焦点位置（web 侧 focusChange 事件回传）。
enum EditorFocusTarget { none, editor, title }

/// [MoodiaryEditor] 的命令式句柄。
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

  /// 返回最近一次已知内容（TipTap 文档 JSON 串），无需 JS 回程。
  Future<String> getContent() async {
    return _state?._lastContent ?? '';
  }

  Future<void> focus() async {
    await _state?._focus();
  }

  /// 取消 webview 内一切焦点（正文 + 标题），软键盘随之收起。
  Future<void> blur() async {
    await _state?._blur();
  }

  /// 恢复标题输入框焦点。
  Future<void> focusTitle() async {
    await _state?._focusTitle();
  }

  /// 当前 webview 内焦点位置。由 web 侧 focusChange 事件维护，读取无 JS 回程。
  EditorFocusTarget get focusTarget =>
      _state?._focusTarget ?? EditorFocusTarget.none;

  bool get hasFocus => focusTarget != EditorFocusTarget.none;

  Future<void> insertMedia(String name, {String alt = ''}) async {
    await _state?._insertMedia(name, alt);
  }

  Future<void> insertAudio(String name) async {
    await _state?._insertAudio(name);
  }

  Future<void> insertVideo(String name) async {
    await _state?._insertVideo(name);
  }

  /// 目录跳转：滚动到第 [index] 个 heading（文档序，与 `DiaryContent` / `TiptapContent.headings` 一致）。
  Future<void> scrollToHeading(int index) async {
    await _state?._scrollToHeading(index);
  }

  /// 当前滚动位置（webview 视口 scrollTop）；未挂载 / 未就绪返回 0。
  Future<double> getScrollY() async {
    return (await _state?._getScrollY()) ?? 0;
  }

  /// 页内双链跳转：原地换文档（见 [_MoodiaryEditorState._swapDocument]）。
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
