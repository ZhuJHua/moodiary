import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:mui/mui.dart';

import 'ime_height.dart';

// The native event channel takes one listener; every container shares it.
final _nativeKeyboardHeights = keyboardHeight();

enum ImePanelType { none, keyboard, custom }

abstract interface class ImeTarget {
  ValueListenable<bool> get focused;

  Future<bool> suppressKeyboard(bool suppressed);

  Future<void> dismiss();
}

class ImePanelController<T> extends ChangeNotifier {
  _ImePanelContainerState<T>? _state;
  bool _notificationPending = false;
  bool _disposed = false;

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
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationPending) return;
      _notificationPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationPending = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
  final Stream<double>? keyboardHeights;

  const ImePanelContainer({
    super.key,
    required this.controller,
    required this.target,
    required this.panelBuilder,
    this.compact,
    this.backgroundColor,
    this.keyboardHeights,
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

  // The system already animates the insets; animate only to or from a panel.
  bool _animate = false;

  // 主动收键盘后、收起事件到来前的可见事件是过时的
  bool _awaitingHide = false;
  bool _ignoreFocus = false;

  Completer<void>? _keyboardGone;

  double _lastKeyboardHeight = 0;
  // Final keyboard height from the native event, known as the animation starts.
  double? _target;
  StreamSubscription<double>? _heightSub;
  Timer? _ensureTimer, _rememberTimer;
  // A hide reported before the keyboard came back after a resume is stale.
  bool _shownSinceResume = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    widget.target.focused.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
    _heightSub = (widget.keyboardHeights ?? _nativeKeyboardHeights).listen(
      _onKeyboardHeight,
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
    unawaited(_heightSub?.cancel());
    _ensureTimer?.cancel();
    _rememberTimer?.cancel();
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

  // Switches as soon as the keyboard starts moving; the insets then only move
  // the placeholder.
  void _onKeyboardHeight(double height) {
    if (!mounted) return;
    if (height <= 0) {
      _target = null;
      _awaitingHide = false;
      if (_type == .keyboard) _keyboardHidden();
      return;
    }
    _target = height;
    _shownSinceResume = true;
    _remember(height);
    if ((_type == .custom && !_awaitingHide) ||
        (_type == .none && widget.target.focused.value)) {
      unawaited(_switchTo(.keyboard, fromFocus: true));
    } else if (_type == .keyboard && _lastType == .custom) {
      setState(() {});
    }
  }

  void _keyboardHidden() {
    final userHide =
        _android &&
        _shownSinceResume &&
        WidgetsBinding.instance.lifecycleState == .resumed;
    unawaited(_switchTo(.none, fromFocus: !userHide));
  }

  void _syncKeyboard(double height) {
    final previous = _lastKeyboardHeight;
    if (height == previous) return;
    _lastKeyboardHeight = height;
    if (height <= 0) {
      _awaitingHide = false;
      // The native event says when it really left; this may be an old hide
      // ending under a keyboard already on its way back.
      if (_type == .keyboard && previous > 0 && _target == null) {
        _keyboardHidden();
      }
      return;
    }
    if (height > previous) _shownSinceResume = true;
    // Without the native height, keep only a height the insets settle on.
    _rememberTimer?.cancel();
    _rememberTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || _target != null || _lastKeyboardHeight != height) return;
      _remember(height);
      if (_type == .keyboard) _settleFromPanel();
    });
    // A shrinking keyboard is on its way out, not coming back.
    if (height > previous &&
        ((_type == .custom && !_awaitingHide) ||
            (_type == .none && widget.target.focused.value))) {
      unawaited(_switchTo(.keyboard, fromFocus: true));
    }
    if (_type != .keyboard) return;
    if (_lastType == .custom) {
      if (height >= _handoffHeight()) _settleFromPanel();
    } else {
      _animate = false;
    }
  }

  double _handoffHeight() => _target ?? _panelHeight();

  // Coming from a panel the placeholder holds the panel height until the
  // keyboard covers it, then hands over to the insets.
  void _settleFromPanel() {
    if (_lastType != .custom) return;
    setState(() => _lastType = .keyboard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncKeyboard(_insets);
  }

  void _remember(double height) {
    if (height <= 0) return;
    _measured = height;
    ImeHeightCache.write(height, landscape: _landscape);
  }

  bool get _keyboardOnScreen => View.of(context).viewInsets.bottom > 0;

  static bool get _android => defaultTargetPlatform == .android;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != .resumed) _shownSinceResume = false;
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    _syncKeyboard(view.viewInsets.bottom / view.devicePixelRatio);
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

  // 悬浮或硬件键盘不占 viewInsets，保留焦点并收起占位。
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
    _animate = type == .custom || previous == .custom;
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
      // Restore the editor input connection when leaving a custom panel.
      unawaited(widget.target.suppressKeyboard(false));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _type == .keyboard) _ensureKeyboardVisible();
    });
  }

  double _keyboardPlaceholder() {
    var height = _insets;
    if (_lastType == .custom) height = max(height, _handoffHeight());
    return max(height, _safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panel;
    final (height, content) = switch (_type) {
      .custom when panel != null && (widget.compact?.call(panel) ?? false) => (
        _safeBottom,
        widget.panelBuilder(context, panel),
      ),
      .custom when panel != null => (
        _panelHeight(),
        widget.panelBuilder(context, panel),
      ),
      .keyboard => (_keyboardPlaceholder(), null),
      _ => (max(_insets, _safeBottom), null),
    };
    return ColoredBox(
      color: widget.backgroundColor ?? Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: height),
        duration: _animate ? const Duration(milliseconds: 200) : Duration.zero,
        builder: (context, value, child) => SizedBox(
          width: double.infinity,
          height: value,
          child: ClipRect(
            child: OverflowBox(
              alignment: .topCenter,
              minHeight: height,
              maxHeight: height,
              child: child,
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}
