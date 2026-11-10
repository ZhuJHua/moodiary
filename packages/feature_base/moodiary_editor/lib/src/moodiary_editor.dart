import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_components/moodiary_components.dart' as components;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart' as models;
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'ime/ime_panel.dart';
import 'media.dart';
import 'toolbar/editor_command.dart';
import 'toolbar/editor_state.dart';
import 'toolbar/link_sheet.dart';
import 'typography.dart';

part 'editor/apple_tracking.dart';
part 'editor/header.dart';
part 'editor/host.dart';
part 'editor/media_controls.dart';
part 'editor/meta_options.dart';
part 'editor/nodes.dart';
part 'editor/style.dart';
part 'editor/transfer.dart';
part 'editor/view.dart';

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

  final void Function(List<String> images, int index, List<Object> heroTags)?
  onImageTap;

  final ValueChanged<String>? onUrlTap;

  final void Function(String src, String name, String? mime)? onAttachmentTap;

  final Future<Duration?> Function(String name, Duration position)?
  onVideoFullscreen;

  final Future<String?> Function(String dataUri, String name)? onSaveImage;

  final Future<List<DiaryLinkCandidate>> Function(String query)?
  onRequestLinkCandidates;

  final ValueChanged<String>? onOpenDiaryLink;

  final String? metaJson;

  final bool metaReady;

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
  final EditorTypography typography;

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
    this.metaReady = true,
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
    this.typography = const EditorTypography(),
    this.fontResolver,
    this.mediaResolver,
  });

  @override
  State<MoodiaryEditor> createState() => _MoodiaryEditorState();
}

bool _isSafeMediaName(String name) {
  if (name.contains('/') || name.contains('\\') || name.contains('..')) {
    return false;
  }
  if (name.startsWith('image-')) return name.length > 'image-'.length;
  if (name.startsWith('audio-')) return name.length > 'audio-'.length;
  if (name.startsWith('video-')) return name.length >= 42;
  if (name.startsWith('file-')) return name.length > 'file-'.length;
  return false;
}

abstract interface class EditorHost {
  ValueListenable<EditorState> get state;
  ValueListenable<EditorFocusTarget> get focusTarget;
  ValueListenable<EditorSearchState?> get search;
  Future<void> exec(EditorCommand command, Map<String, Object?>? args);
  Future<void> flush();
  Future<void> focus();
  Future<void> blur();
  Future<void> focusTitle();
  Future<void> holdSelection();
  Future<void> setPanelMode(bool value);
  Future<bool> suppressKeyboard(bool value);
  Future<void> dismissKeyboard();
  Future<void> scrollToHeading(int index);
  Future<double> getScrollY();
  Future<void> setScrollY(double value);
  Future<void> swapDocument({
    required String content,
    required String title,
    double scrollY = 0,
  });
  Future<void> resumeVideo(String name, Duration position);
}

enum EditorFocusTarget { none, editor, title }

typedef EditorSearchState = ({String query, int total, int current});

class MoodiaryEditorController {
  EditorHost? _host;

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

  bool Function()? dismissTransient;

  Future<void> editLink(BuildContext context) async {
    final host = _host;
    if (host is! MoodiaryEditorHost ||
        host.readOnly ||
        !host.bodyFocus.hasPrimaryFocus) {
      return;
    }
    final state = host.state.value, generation = host._generation;
    final input = await withInputSuspended(
      () => showLinkSheet(
        context,
        text: state.link?.text ?? state.selectedText,
        href: state.link?.href ?? '',
      ),
    );
    if (!context.mounted ||
        !identical(_host, host) ||
        generation != host._generation ||
        input == null) {
      return;
    }
    await exec(.setLink, {'text': input.text, 'href': input.href});
  }

  void _bind(EditorHost host) {
    final old = _host;
    if (old != null) _unbind(old);
    _host = host;
    host.state.addListener(_syncState);
    host.focusTarget.addListener(_syncFocus);
    host.search.addListener(_syncSearch);
    _syncState();
    _syncFocus();
    _syncSearch();
  }

  void _syncState() => _state.value = _host?.state.value ?? EditorState.empty;
  void _syncFocus() =>
      _focus.value = _host?.focusTarget.value ?? EditorFocusTarget.none;
  void _syncSearch() => _search.value = _host?.search.value;
  @visibleForTesting
  void bindHostForTesting(EditorHost host) => _bind(host);

  void _unbind(EditorHost host) {
    if (!identical(_host, host)) return;
    host.state.removeListener(_syncState);
    host.focusTarget.removeListener(_syncFocus);
    host.search.removeListener(_syncSearch);
    _host = null;
  }

  ValueListenable<EditorState> get state => _state;

  ValueListenable<EditorFocusTarget> get focusTarget => _focus;

  ValueListenable<EditorSearchState?> get search => _search;

  ValueListenable<bool> get searchOpen => _searchOpen;

  Future<void> exec(EditorCommand command, [Map<String, Object?>? args]) async {
    await _host?.exec(command, args);
  }

  Future<void> flush() async {
    await _host?.flush();
  }

  EditorFocusTarget _searchSource = .none;
  ft.Selection? _searchSelection;
  ft.Node? _searchDocument;
  TextSelection? _searchTitleSelection;
  void openSearch() {
    if (_searchOpen.value) return;
    _searchSource = _focus.value;
    if (_host case final MoodiaryEditorHost host) {
      _searchSelection = host.editor.state.selection;
      _searchDocument = host.editor.state.doc;
      _searchTitleSelection = host.title.selection;
    }
    unawaited(holdSelection());
    _searchOpen.value = true;
  }

  Future<void> closeSearch() async {
    _searchOpen.value = false;
    _search.value = null;
    await exec(.clearSearch);
    final source = _searchSource;
    _searchSource = .none;
    final selection = _searchSelection,
        document = _searchDocument,
        titleSelection = _searchTitleSelection;
    _searchSelection = null;
    _searchDocument = null;
    _searchTitleSelection = null;
    if (_focus.value != .none) return;
    if (_host case final MoodiaryEditorHost host
        when identical(document, host.editor.state.doc)) {
      if (selection != null) host.editor.setSelection(selection);
      if (titleSelection != null) host.title.selection = titleSelection;
    }
    if (source == .title) await focusTitle();
    if (source == .editor) await focus();
  }

  Future<void> focus() async {
    await _host?.focus();
  }

  Future<void> blur() async {
    await _host?.blur();
  }

  Future<void> focusTitle() async {
    await _host?.focusTitle();
  }

  Future<void> holdSelection() async {
    await _host?.holdSelection();
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
    await _host?.scrollToHeading(index);
  }

  Future<double> getScrollY() async {
    return (await _host?.getScrollY()) ?? 0;
  }

  Future<void> setScrollY(double value) async => _host?.setScrollY(value);
  Future<void> resumeVideo(String name, Duration position) async =>
      _host?.resumeVideo(name, position);
  Future<void> swapDocument({
    required String content,
    required String title,
    double scrollY = 0,
  }) async {
    await _host?.swapDocument(content: content, title: title, scrollY: scrollY);
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
      await _controller._host?.suppressKeyboard(suppressed) ?? false;

  @override
  Future<void> dismiss() async => _controller._host?.dismissKeyboard();
}

class _FocusedListenable extends ValueNotifier<bool> {
  _FocusedListenable(ValueListenable<EditorFocusTarget> source)
    : super(source.value != EditorFocusTarget.none) {
    source.addListener(() => value = source.value != EditorFocusTarget.none);
  }
}
