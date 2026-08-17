import 'dart:async';

import 'package:mui/mui.dart';

/// 松手后按压态多留一会儿。没有它的话，快速点一下的高亮只存在不到一帧，
/// 用户看不到任何反馈。
const Duration _kReleaseDelay = Duration(milliseconds: 50);

/// 嵌套上报的接口。见 [MInkWell] 类注释的第二点。
abstract class _MInkWellPressedHost {
  void onDescendantPressedChanged(bool pressed);
}

class _MInkWellScope extends InheritedWidget {
  const _MInkWellScope({required this.host, required super.child});

  final _MInkWellPressedHost host;

  static _MInkWellPressedHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MInkWellScope>()?.host;

  @override
  bool updateShouldNotify(_MInkWellScope oldWidget) =>
      !identical(host, oldWidget.host);
}

/// 全仓统一的按压反馈。**取代 `InkWell` / `InkResponse`。**
///
/// 与 Material 那套的三点不同，每一点都是为了解决仓里真实碰到的问题：
///
/// 1. **按压视觉是自己子树里的一层遮罩，不是祖先 Material 上的 ink feature。**
///    `InkWell` 的高亮画进最近的祖先 `Material` 的 `_RenderInkFeatures`，
///    所以任何自带不透明底色的东西（浮起来的面板、药丸、卡片）都会把它盖住 ——
///    要让它显出来就得在底色那一层再铺一个 `Material`。改成遮罩之后，
///    **按压反馈与背景解耦，不需要任何 Material**。
///
/// 2. **嵌套时内层赢。** 一个可点的行里再放一颗可点的按钮，两者都会收到指针，
///    `InkWell` 的结果是行和按钮一起高亮。这里内层按下会经
///    [_MInkWellScope] 上报给外层，外层据此**抑制自己的高亮**
///    （见 [_MInkWellState._shouldRenderPressed]），只留下真正被按的那一个。
///
/// 3. **一个回调都不传时整个退化成 [child]** —— 不建手势、不出反馈、也不吃指针。
///    调用点惯用的 `onTap: enabled ? handler : null` 因此自然表示「这行现在不可点」。
///
/// 水波纹本来就是关掉的（`splashFactory: NoSplash`），所以这里也没有扩散动画 ——
/// 按压反馈就是「状态驱动的色块变化」，与全仓一致。
class MInkWell extends StatefulWidget {
  final Widget child;

  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressUpCallback? onLongPressUp;

  final HitTestBehavior? behavior;

  /// 裁剪与遮罩的形状。[shape] 是它的通用形态，两者只能给一个。
  final BorderRadiusGeometry? borderRadius;
  final ShapeBorder? shape;

  /// false 同时关掉点击与按压效果。
  final bool enabled;

  /// 覆盖默认遮罩色。默认是 `onSurface` 按 [MuiStateTokens.pressedOpacity]
  /// 取透明度 —— 与 `ThemeData.highlightColor` 同一个值。
  ///
  /// 落在 primary 一类深底上时传一个自己的，否则暗色遮罩在暗底上看不出来。
  final Color? overlayColor;

  const MInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressUp,
    this.behavior,
    this.borderRadius,
    this.shape,
    this.enabled = true,
    this.overlayColor,
  }) : assert(
         borderRadius == null || shape == null,
         'borderRadius 与 shape 只能给一个。',
       );

  @override
  State<MInkWell> createState() => _MInkWellState();
}

class _MInkWellState extends State<MInkWell> implements _MInkWellPressedHost {
  bool _selfPressed = false;
  int _pressedDescendants = 0;

  /// 松手延时。**必须可取消**：`Future.delayed` 那种写法在 widget 销毁后计时器
  /// 还挂着，`flutter_test` 会直接判 “A Timer is still pending”。
  Timer? _releaseTimer;

  _MInkWellPressedHost? _parent;

  bool get _isInteractive =>
      widget.onTap != null ||
      widget.onLongPress != null ||
      widget.onLongPressStart != null ||
      widget.onLongPressUp != null;

  /// 自己或子树里有人按着 —— 要往上报的就是这个。
  bool get _isPressedAnywhere => _selfPressed || _pressedDescendants > 0;

  /// 真正画出高亮的条件：**子树里没人按着**。内层赢，外层让位。
  bool get _shouldRenderPressed =>
      widget.enabled && _selfPressed && _pressedDescendants == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _MInkWellScope.maybeOf(context);
    if (identical(next, _parent)) return;
    // 换爹的瞬间要把在途的「按着」从旧的身上摘掉、挂到新的身上，
    // 否则旧的计数永远减不回去，会一直以为子树里有人按着。
    final reporting = _isPressedAnywhere;
    if (reporting) _parent?.onDescendantPressedChanged(false);
    _parent = next;
    if (reporting) _parent?.onDescendantPressedChanged(true);
  }

  @override
  void didUpdateWidget(covariant MInkWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _selfPressed) _setPressed(false);
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    if (_isPressedAnywhere) _parent?.onDescendantPressedChanged(false);
    super.dispose();
  }

  @override
  void onDescendantPressedChanged(bool pressed) {
    if (!mounted) return;
    final was = _isPressedAnywhere;
    setState(() {
      _pressedDescendants += pressed ? 1 : -1;
      assert(_pressedDescendants >= 0, 'MInkWell 的子树按压计数被减穿了');
    });
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _setPressed(bool value) {
    if (!mounted || _selfPressed == value) return;
    final was = _isPressedAnywhere;
    setState(() => _selfPressed = value);
    if (was != _isPressedAnywhere) {
      _parent?.onDescendantPressedChanged(_isPressedAnywhere);
    }
  }

  void _scheduleRelease() {
    if (!_selfPressed) return;
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_kReleaseDelay, () {
      _releaseTimer = null;
      _setPressed(false);
    });
  }

  void _cancelRelease() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
  }

  void _press() {
    _cancelRelease();
    _setPressed(true);
  }

  void _release() {
    _cancelRelease();
    _setPressed(false);
  }

  void _onTap() {
    widget.onTap?.call();
    _scheduleRelease();
  }

  void _onLongPress() {
    widget.onLongPress?.call();
    _release();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    widget.onLongPressStart?.call(details);
    _release();
  }

  Widget _withOverlay(Widget child) {
    final scheme = context.theme.colors;
    final color =
        widget.overlayColor ??
        scheme.onSurface.withValues(alpha: context.theme.states.pressedOpacity);
    return Stack(
      children: [
        child,
        Positioned.fill(
          // 遮罩不吃指针 —— 它只是画上去的一层。
          child: IgnorePointer(
            child: ColoredBox(
              color: _shouldRenderPressed ? color : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = widget.behavior ?? HitTestBehavior.opaque;
    Widget result = _withOverlay(widget.child);

    if (_isInteractive) {
      final hasTap = widget.onTap != null;
      final hasLongPress =
          widget.onLongPress != null ||
          widget.onLongPressStart != null ||
          widget.onLongPressUp != null;
      result = GestureDetector(
        behavior: behavior,
        onTapDown: hasTap ? (_) => _press() : null,
        onTap: hasTap ? _onTap : null,
        onTapCancel: hasTap ? _release : null,
        // 有 tap 时按下的高亮已经由 onTapDown 给了，再挂一次会打架。
        onLongPressDown: hasLongPress && !hasTap ? (_) => _press() : null,
        onLongPress: widget.onLongPress != null ? _onLongPress : null,
        onLongPressStart: hasLongPress ? _onLongPressStart : null,
        onLongPressUp: widget.onLongPressUp,
        onLongPressCancel: hasLongPress ? _release : null,
        child: result,
      );
      // 禁用时连指针都不收，免得子树里别的手势替它响应。
      if (!widget.enabled) result = IgnorePointer(child: result);
    }
    // 一个回调都没有：不建手势、也不吃指针，让点击穿过去。

    final borderRadius = widget.borderRadius;
    final shape = widget.shape;
    if (borderRadius != null) {
      result = ClipRRect(borderRadius: borderRadius, child: result);
    } else if (shape != null) {
      result = ClipPath(
        clipper: ShapeBorderClipper(
          shape: shape,
          textDirection: Directionality.maybeOf(context),
        ),
        child: result,
      );
    }

    return _MInkWellScope(host: this, child: result);
  }
}
