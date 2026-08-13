import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

const double _kAlertMaxWidth = 340;
const double _kAlertScreenPadding = 28;
const double _kActionHeight = 44;
const double _kActionGap = 8;
const double _kFieldHeight = 46;

/// MAlert 的弹层入口。按组件归类的静态方法，替代原来的 show* 顶层函数。
abstract final class MAlert {
  /// 通用弹窗：圆角容器、内容居中、底部圆角按钮。
  ///
  /// [actions] 的顺序是「从次要到主要」——横排时从左到右按原序（取消在左、主操作在
  /// 右，沿用 M3 OverflowBar 的既有顺序），竖排时反序（主操作在上、取消在最下）。
  ///
  /// 大多数场景用 [MAlert.confirm] / [MAlert.prompt] / [MAlert.notice]
  /// 三个便捷函数即可，本函数留给需要自定义 [content] 的复合弹窗。
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? message,
    Widget? content,
    IconData? icon,
    bool isDestructive = false,
    required List<MAction<T>> actions,
    MActionsLayout actionsLayout = .auto,
    bool barrierDismissible = true,
  }) {
    return _push<T>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (_) => _AlertBody<T>(
        title: title,
        message: message,
        content: content,
        icon: icon,
        isDestructive: isDestructive,
        actions: actions,
        actionsLayout: actionsLayout,
      ),
    );
  }

  /// 二选一确认。返回 true 表示用户确认；取消、点遮罩、返回键都返回 false。
  ///
  /// [isDestructive] 会把确认键染成 error 色，并在未显式给 [icon] 时补一个警告图标 ——
  /// 破坏性操作在全仓必须一眼可辨，不再依赖各调用点手抄 `foregroundColor: error`。
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
    IconData? icon,
    MActionsLayout actionsLayout = .auto,
    bool barrierDismissible = true,
  }) async {
    final l10n = context.muiL10n;
    final result = await MAlert.show<bool>(
      context,
      title: title,
      message: message,
      content: content,
      icon: icon,
      isDestructive: isDestructive,
      actionsLayout: actionsLayout,
      barrierDismissible: barrierDismissible,
      actions: [
        MAction(label: cancelLabel ?? l10n.cancel, value: false),
        MAction(
          label: confirmLabel ?? l10n.ok,
          value: true,
          isPrimary: !isDestructive,
          isDestructive: isDestructive,
        ),
      ],
    );
    return result ?? false;
  }

  /// 单按钮提示。用于「结果报告」这类需要用户读完再关的内容；一次性提示请继续用 toast。
  static Future<void> notice(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String? closeLabel,
    IconData? icon,
  }) {
    return MAlert.show<void>(
      context,
      title: title,
      message: message,
      content: content,
      icon: icon,
      actions: [
        MAction(label: closeLabel ?? context.muiL10n.ok, isPrimary: true),
      ],
    );
  }

  /// 单输入弹窗。返回输入值；取消 / 点遮罩 / 返回键返回 null。
  ///
  /// 校验分两级：
  /// * [validator] 同步校验，返回非 null 时作为 errorText 显示并阻止关闭；
  /// * [onSubmit] 异步校验或提交，执行期间确认键转圈、取消键禁用、遮罩与返回键都被
  ///   挡住；返回 null 表示成功并关闭，返回字符串则作为错误提示保留弹窗与已输入内容。
  ///
  /// 输入框由弹窗自行创建与释放，调用方只拿到结果字符串，不必再管 controller 生命周期。
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
    bool isDestructive = false,
    bool obscureText = false,
    bool trim = true,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String value)? validator,
    Future<String?> Function(String value)? onSubmit,
    bool barrierDismissible = true,
  }) {
    return _push<String>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (_) => _PromptBody(
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
        obscureText: obscureText,
        trim: trim,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onSubmit: onSubmit,
      ),
    );
  }
}

// ─────────────────────────── 路由 ───────────────────────────

Future<T?> _push<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required bool barrierDismissible,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _MAlertRoute<T>(
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColorValue: context.theme.colors.scrim.withValues(alpha: 0.32),
      barrierLabelText: localizations.modalBarrierDismissLabel,
      routeLabelText: localizations.dialogLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// 自实现 PopupRoute 而非 [showDialog]：需要 200/130ms 的非对称进出、缩放 + 淡入，
/// 以及在异步提交期间临时关掉遮罩点击。参数与动效对齐 [MMenu.show]。
class _MAlertRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Color barrierColorValue;
  final String barrierLabelText;

  /// 路由名，读屏进入弹窗时播报。与 [barrierLabelText]（遮罩的「点这里关闭」）分开 ——
  /// 混用会让读屏把每张弹窗都念成「关闭」。
  final String routeLabelText;
  final CapturedThemes capturedThemes;

  bool _barrierDismissible;

  _MAlertRoute({
    required this.builder,
    required this._barrierDismissible,
    required this.barrierColorValue,
    required this.barrierLabelText,
    required this.routeLabelText,
    required this.capturedThemes,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 130);

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color get barrierColor => barrierColorValue;

  @override
  String get barrierLabel => barrierLabelText;

  /// 异步提交期间锁住遮罩；[changedInternalState] 会让 Navigator 重建 ModalBarrier。
  void setBarrierDismissible(bool value) {
    if (_barrierDismissible == value) return;
    _barrierDismissible = value;
    changedInternalState();
  }

  /// 带着活跃的输入法会话被 pop 会在 debug 触发 `_dependents.isEmpty` 断言，
  /// 所以按钮、遮罩、返回键三条关闭路径统一在这里收口。
  @override
  bool didPop(T? result) {
    FocusManager.instance.primaryFocus?.unfocus();
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: routeLabelText,
      child: capturedThemes.wrap(
        _AlertScaffold(
          viewPadding: viewPadding,
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, inner) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: inner),
        );
      },
      child: child,
    );
  }
}

/// 居中 + 宽度上限 + 键盘避让。上限 340 是为了让平板/横屏下弹窗不被拉成长条
/// （M3 默认宽度是「屏宽 − 80」且无上限）。
class _AlertScaffold extends StatelessWidget {
  final EdgeInsets viewPadding;
  final Widget child;

  const _AlertScaffold({required this.viewPadding, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: .only(bottom: bottomInset),
      child: Padding(
        padding: .fromLTRB(
          _kAlertScreenPadding + viewPadding.left,
          24 + viewPadding.top,
          _kAlertScreenPadding + viewPadding.right,
          24 + (bottomInset > 0 ? 0 : viewPadding.bottom),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kAlertMaxWidth),
            child: Material(
              type: .card,
              color: context.theme.colors.surfaceContainerHigh,
              elevation: 8,
              shadowColor: context.theme.colors.shadow.withValues(alpha: 0.24),
              surfaceTintColor: Colors.transparent,
              borderRadius: MuiRadius.xl,
              clipBehavior: .antiAlias,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── 内容 ───────────────────────────

/// 换行或超过一屏宽的正文按长文处理（左对齐）。阈值取两行左右的字数。
bool _isLongForm(String message) =>
    message.contains('\n') || message.runes.length > 44;

/// 弹窗内部的通用骨架：图标 → 标题 → 正文 → 自定义内容 → 按钮，整体居中。
class _AlertShell extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final bool isDestructive;
  final Widget actions;

  const _AlertShell({
    this.title,
    this.message,
    this.content,
    this.icon,
    required this.isDestructive,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final effectiveIcon =
        icon ?? (isDestructive ? LucideIcons.triangleAlert : null);

    return SingleChildScrollView(
      child: Padding(
        padding: const .fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            if (effectiveIcon != null) ...[
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: isDestructive
                        ? scheme.errorContainer
                        : scheme.secondaryContainer,
                  ),
                  child: Icon(
                    effectiveIcon,
                    size: 22,
                    color: isDestructive
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (title != null)
              Text(
                title!,
                textAlign: .center,
                style: typography.titleLarge.emphasized.onSurface,
              ),
            if (message != null) ...[
              if (title != null) const SizedBox(height: 8),
              Text(
                message!,
                // 一句话居中；分段或长文左对齐 —— 「·」要点列表、免责声明这类多段
                // 正文居中后每行起点都在跳，读起来很费劲。
                textAlign: _isLongForm(message!) ? .start : .center,
                style: typography.bodyMedium.onSurfaceVariant,
              ),
            ],
            if (content != null) ...[
              if (title != null || message != null) const SizedBox(height: 16),
              content!,
            ],
            const SizedBox(height: 20),
            actions,
          ],
        ),
      ),
    );
  }
}

class _AlertBody<T> extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final bool isDestructive;
  final List<MAction<T>> actions;
  final MActionsLayout actionsLayout;

  const _AlertBody({
    this.title,
    this.message,
    this.content,
    this.icon,
    required this.isDestructive,
    required this.actions,
    required this.actionsLayout,
  });

  @override
  Widget build(BuildContext context) {
    return _AlertShell(
      title: title,
      message: message,
      content: content,
      icon: icon,
      isDestructive: isDestructive,
      actions: MActionBar<T>(
        layout: actionsLayout,
        height: _kActionHeight,
        gap: _kActionGap,
        actions: actions,
      ),
    );
  }
}

class _PromptBody extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? hintText;
  final String? confirmLabel;
  final String? cancelLabel;
  final IconData? icon;
  final bool isDestructive;
  final bool obscureText;
  final bool trim;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String value)? validator;
  final Future<String?> Function(String value)? onSubmit;

  const _PromptBody({
    required this.title,
    this.message,
    this.initialValue,
    this.hintText,
    this.confirmLabel,
    this.cancelLabel,
    this.icon,
    required this.isDestructive,
    required this.obscureText,
    required this.trim,
    this.maxLength,
    required this.maxLines,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onSubmit,
  });

  @override
  State<_PromptBody> createState() => _PromptBodyState();
}

class _PromptBodyState extends State<_PromptBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => widget.trim ? _controller.text.trim() : _controller.text;

  _MAlertRoute<String>? get _route =>
      ModalRoute.of(context) as _MAlertRoute<String>?;

  Future<void> _submit() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final value = _value;

    final syncError = widget.validator?.call(value);
    if (syncError != null) {
      setState(() => _error = syncError);
      return;
    }

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      if (mounted) Navigator.of(context).pop(value);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    _route?.setBarrierDismissible(false);
    String? failure;
    try {
      failure = await onSubmit(value);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _route?.setBarrierDismissible(true);
      }
    }
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(value);
    } else {
      setState(() => _error = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.muiL10n;

    return PopScope(
      canPop: !_busy,
      child: _AlertShell(
        title: widget.title,
        message: widget.message,
        icon: widget.icon,
        isDestructive: widget.isDestructive,
        content: MField(
          controller: _controller,
          autofocus: true,
          minHeight: _kFieldHeight,
          hintText: widget.hintText,
          errorText: _error,
          enabled: !_busy,
          obscureText: widget.obscureText,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onSubmitted: (_) => _submit(),
        ),
        actions: MActionBar<String>(
          layout: .auto,
          height: _kActionHeight,
          gap: _kActionGap,
          actions: [
            MAction(label: widget.cancelLabel ?? l10n.cancel, enabled: !_busy),
            MAction(
              label: widget.confirmLabel ?? l10n.ok,
              isPrimary: !widget.isDestructive,
              isDestructive: widget.isDestructive,
              busy: _busy,
              enabled: !_busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
