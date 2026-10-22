import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:mui/mui.dart';

import 'ime_height.dart';

// 原生 EventChannel 只认一个监听方，所有容器共用这一个广播流
final _nativeKeyboardEvents = keyboardEvents();

enum ImePanelType { none, keyboard, custom }

abstract interface class ImeTarget {
  ValueListenable<bool> get focused;

  Future<bool> suppressKeyboard(bool suppressed);

  Future<void> dismiss();
}

class ImePanelController<T> extends ChangeNotifier {
  _ImePanelContainerState<T>? _state;

  ImePanelType _type = .none;
  T? _panel;

  ImePanelType get type => _type;

  T? get panel => _panel;

  void showPanel(T panel) => _state?._switchTo(.custom, panel: panel);

  void showKeyboard() => _state?._switchTo(.keyboard);

  void hide() => _state?._switchTo(.none);

  // 收起键盘或面板并释放焦点，等键盘真正退场再返回，弹层就不会跟着键盘位移
  Future<void> release() async => _state?._release();

  Future<void> keyboardGone() async => _state?._untilKeyboardGone();

  void _sync(ImePanelType type, T? panel) {
    if (_type == type && _panel == panel) return;
    _type = type;
    _panel = panel;
    notifyListeners();
  }

  void _attach(_ImePanelContainerState<T> state) => _state = state;

  // 异步通知，避开卸载中的 build
  void _detach(_ImePanelContainerState<T> state) {
    if (!identical(_state, state)) return;
    _state = null;
    if (_type == .none) return;
    scheduleMicrotask(() {
      if (_state == null) _sync(.none, null);
    });
  }
}

class ImePanelContainer<T> extends StatefulWidget {
  final ImePanelController<T> controller;
  final ImeTarget target;

  final Widget Function(BuildContext context, T panel) panelBuilder;

  final bool Function(T panel)? compact;

  final Color? backgroundColor;

  @visibleForTesting
  final Stream<KeyboardEvent>? keyboardEvents;

  const ImePanelContainer({
    super.key,
    required this.controller,
    required this.target,
    required this.panelBuilder,
    this.compact,
    this.backgroundColor,
    this.keyboardEvents,
  });

  @override
  State<ImePanelContainer<T>> createState() => _ImePanelContainerState<T>();
}

class _ImePanelContainerState<T> extends State<ImePanelContainer<T>>
    with WidgetsBindingObserver {
  ImePanelType _type = .none;
  ImePanelType _lastType = .none;
  T? _panel;

  double? _measured;

  bool _keyboardChangedByItself = false;

  // 主动收键盘后、收起事件到来前的可见事件是过时的
  bool _awaitingHide = false;
  bool _ignoreFocus = false;

  Completer<void>? _keyboardGone;

  StreamSubscription<KeyboardEvent>? _keyboardSub;
  Timer? _ensureTimer;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    widget.target.focused.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
    _keyboardSub = (widget.keyboardEvents ?? _nativeKeyboardEvents).listen(
      _onKeyboardEvent,
    );
  }

  @override
  void didUpdateWidget(covariant ImePanelContainer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (oldWidget.target != widget.target) {
      oldWidget.target.focused.removeListener(_onFocusChanged);
      widget.target.focused.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    if (_type == .custom) unawaited(widget.target.suppressKeyboard(false));
    widget.controller._detach(this);
    widget.target.focused.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_keyboardSub?.cancel());
    _ensureTimer?.cancel();
    _keyboardGone?.complete();
    super.dispose();
  }

  bool get _landscape {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  double get _insets => MediaQuery.viewInsetsOf(context).bottom;

  double get _safeBottom => MediaQuery.viewPaddingOf(context).bottom;

  double _panelHeight() {
    final cached =
        validImeHeight(_measured) ?? ImeHeightCache.read(landscape: _landscape);
    return max(
      resolveImePanelHeight(cached, MediaQuery.sizeOf(context).height),
      _safeBottom,
    );
  }

  void _onFocusChanged() {
    if (_ignoreFocus || !mounted) return;
    if (widget.target.focused.value) {
      if (_type == .none) _switchTo(.keyboard, fromFocus: true);
    } else if (_type != .none) {
      _switchTo(.none, fromFocus: true);
    }
  }

  void _onKeyboardEvent(KeyboardEvent event) {
    if (!mounted) return;
    if (!event.visible) _awaitingHide = false;
    if (event.floating) {
      if (event.visible && _type == .custom && !_awaitingHide) {
        _switchTo(.keyboard, fromFocus: true);
      }
      return;
    }
    if (event.visible) {
      final total = event.height + (Platform.isAndroid ? _safeBottom : 0);
      if (event.isStart) {
        _remember(total);
        if ((_type == .custom && !_awaitingHide) ||
            (_type == .none && widget.target.focused.value)) {
          _switchTo(.keyboard, fromFocus: true);
        } else if (_type == .keyboard) {
          _keyboardChangedByItself = true;
          setState(() {});
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _keyboardChangedByItself = false,
          );
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final stable = _insets;
          if (stable > 0) _remember(stable);
          if (_type == .keyboard && _lastType == .custom) {
            setState(() => _lastType = .keyboard);
          }
        });
      }
    } else if (_type == .keyboard && (_android || !event.isStart)) {
      // 安卓收起动画开始时 insets 已是终态，当场处理；iOS 聚焦过程中 willHide 会抖，等动画结束
      final userHide =
          _android && WidgetsBinding.instance.lifecycleState == .resumed;
      _switchTo(.none, fromFocus: !userHide);
    }
  }

  void _remember(double height) {
    if (height <= 0) return;
    _measured = height;
    ImeHeightCache.write(height, landscape: _landscape);
  }

  bool get _keyboardOnScreen => View.of(context).viewInsets.bottom > 0;

  static bool get _android => defaultTargetPlatform == .android;

  @override
  void didChangeMetrics() {
    if (_keyboardGone != null && !_keyboardOnScreen) {
      _keyboardGone!.complete();
      _keyboardGone = null;
    }
    if (_type != .keyboard) return;
    _ensureKeyboardVisible();
  }

  Future<void> _release() async {
    if (_type != .none) {
      await _switchTo(.none);
    } else if (widget.target.focused.value) {
      await widget.target.dismiss();
    }
    await _untilKeyboardGone();
  }

  Future<void> _untilKeyboardGone() async {
    if (!mounted || !_keyboardOnScreen) return;
    await (_keyboardGone ??= Completer<void>()).future;
  }

  // 安卓小窗、悬浮或硬件键盘不占 viewInsets 原生也可能不报：两次都为 0 就退回 none，焦点保留
  void _ensureKeyboardVisible() {
    _ensureTimer?.cancel();
    _ensureTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || _type != .keyboard || _insets > 0) return;
      _ensureTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted || _type != .keyboard || _insets > 0) return;
        _switchTo(.none, fromFocus: true);
      });
    });
  }

  Future<void> _switchTo(
    ImePanelType type, {
    T? panel,
    bool fromFocus = false,
  }) async {
    final previous = _type;
    if (previous == type && panel == _panel) return;
    if (type != .custom) {
      _awaitingHide = false;
    } else if (previous == .keyboard) {
      _awaitingHide = true;
    }
    _lastType = previous;
    _type = type;
    _panel = type == .custom ? panel : null;
    widget.controller._sync(_type, _panel);
    setState(() {});
    if (!fromFocus) {
      _ignoreFocus = true;
      try {
        switch (type) {
          case .custom:
            if (previous != .custom) {
              await widget.target.suppressKeyboard(true);
            }
          case .keyboard:
            await widget.target.suppressKeyboard(false);
          case .none:
            await widget.target.dismiss();
        }
      } finally {
        _ignoreFocus = false;
      }
    } else if (previous == .custom) {
      // iOS 的零高 inputView 标记不复位，之后每次聚焦都拿到零高键盘
      unawaited(widget.target.suppressKeyboard(false));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _type == .keyboard) _ensureKeyboardVisible();
    });
  }

  double _keyboardPlaceholder() {
    var height = _insets;
    if (_lastType == .custom) height = max(height, _panelHeight());
    return max(height, _safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panel;
    final Widget child = switch (_type) {
      .custom when panel != null && (widget.compact?.call(panel) ?? false) =>
        SizedBox(
          width: double.infinity,
          height: _safeBottom,
          child: widget.panelBuilder(context, panel),
        ),
      .custom when panel != null => SizedBox(
        width: double.infinity,
        height: _panelHeight(),
        child: widget.panelBuilder(context, panel),
      ),
      .keyboard => SizedBox(
        width: double.infinity,
        height: _keyboardPlaceholder(),
      ),
      _ => SizedBox(width: double.infinity, height: max(_insets, _safeBottom)),
    };
    final duration = _keyboardChangedByItself
        ? const Duration(milliseconds: 50)
        : const Duration(milliseconds: 200);
    return ColoredBox(
      color: widget.backgroundColor ?? Colors.transparent,
      child: AnimatedSize(
        alignment: .topCenter,
        duration: duration,
        curve: Curves.linear,
        child: child,
      ),
    );
  }
}
