import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 弹窗底部的一个动作。字段名对齐 [MoodiaryMenuEntry]，让菜单与弹窗共享同一套心智。
///
/// 三种呈现由两个布尔量决定：[isDestructive] → error 实心，[isPrimary] → primary
/// 实心，都不是则为中性键（取消）。
class MoodiaryAlertAction<T> {
  /// 点击后弹窗返回的值。
  final T? value;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final bool enabled;

  /// 点击拦截：返回 false 时弹窗不关闭。给自带校验的复合 [content] 用 —— 校验失败
  /// 应当留住弹窗并就地报错，不要「先关弹窗再 toast」。
  final bool Function()? onIntercept;

  const MoodiaryAlertAction({
    required this.label,
    this.value,
    this.isPrimary = false,
    this.isDestructive = false,
    this.enabled = true,
    this.onIntercept,
  });
}

/// 底部按钮的排布方式。
enum MoodiaryAlertActionsLayout {
  /// 两个动作且文案放得下时横排等宽，否则竖排。
  auto,
  horizontal,
  vertical,
}

const double _kAlertMaxWidth = 340;
const double _kAlertScreenPadding = 28;
const double _kActionHeight = 44;
const double _kActionGap = 8;
const double _kFieldHeight = 46;

/// 通用弹窗：圆角容器、内容居中、底部圆角按钮。
///
/// [actions] 的顺序是「从次要到主要」——横排时从左到右按原序（取消在左、主操作在
/// 右，沿用 M3 OverflowBar 的既有顺序），竖排时反序（主操作在上、取消在最下）。
///
/// 大多数场景用 [showMoodiaryConfirm] / [showMoodiaryPrompt] / [showMoodiaryNotice]
/// 三个便捷函数即可，本函数留给需要自定义 [content] 的复合弹窗。
Future<T?> showMoodiaryAlert<T>(
  BuildContext context, {
  String? title,
  String? message,
  Widget? content,
  IconData? icon,
  bool isDestructive = false,
  required List<MoodiaryAlertAction<T>> actions,
  MoodiaryAlertActionsLayout actionsLayout = MoodiaryAlertActionsLayout.auto,
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
Future<bool> showMoodiaryConfirm(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  IconData? icon,
  MoodiaryAlertActionsLayout actionsLayout = MoodiaryAlertActionsLayout.auto,
  bool barrierDismissible = true,
}) async {
  final l10n = context.l10n;
  final result = await showMoodiaryAlert<bool>(
    context,
    title: title,
    message: message,
    content: content,
    icon: icon,
    isDestructive: isDestructive,
    actionsLayout: actionsLayout,
    barrierDismissible: barrierDismissible,
    actions: [
      MoodiaryAlertAction(label: cancelLabel ?? l10n.cancel, value: false),
      MoodiaryAlertAction(
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
Future<void> showMoodiaryNotice(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? closeLabel,
  IconData? icon,
}) {
  return showMoodiaryAlert<void>(
    context,
    title: title,
    message: message,
    content: content,
    icon: icon,
    actions: [
      MoodiaryAlertAction(
        label: closeLabel ?? context.l10n.ok,
        isPrimary: true,
      ),
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
Future<String?> showMoodiaryPrompt(
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

// ─────────────────────────── 路由 ───────────────────────────

Future<T?> _push<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required bool barrierDismissible,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    _MoodiaryAlertRoute<T>(
      builder: builder,
      initialBarrierDismissible: barrierDismissible,
      barrierColorValue: context.colorScheme.scrim.withValues(alpha: 0.32),
      barrierLabelText: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// 自实现 PopupRoute 而非 [showDialog]：需要 200/130ms 的非对称进出、缩放 + 淡入，
/// 以及在异步提交期间临时关掉遮罩点击。参数与动效对齐 [showMoodiaryMenu]。
class _MoodiaryAlertRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Color barrierColorValue;
  final String barrierLabelText;
  final CapturedThemes capturedThemes;

  bool _barrierDismissible;

  _MoodiaryAlertRoute({
    required this.builder,
    required bool initialBarrierDismissible,
    required this.barrierColorValue,
    required this.barrierLabelText,
    required this.capturedThemes,
  }) : _barrierDismissible = initialBarrierDismissible;

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
      label: barrierLabelText,
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
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kAlertScreenPadding + viewPadding.left,
          24 + viewPadding.top,
          _kAlertScreenPadding + viewPadding.right,
          24 + (bottomInset > 0 ? 0 : viewPadding.bottom),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kAlertMaxWidth),
            child: Material(
              type: MaterialType.card,
              color: context.colorScheme.surfaceContainerHigh,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.24),
              surfaceTintColor: Colors.transparent,
              borderRadius: AppBorderRadius.xLargeBorderRadius,
              clipBehavior: Clip.antiAlias,
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
    final scheme = context.colorScheme;
    final textTheme = context.textTheme;
    final effectiveIcon =
        icon ?? (isDestructive ? Icons.warning_amber_rounded : null);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (effectiveIcon != null) ...[
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            if (message != null) ...[
              if (title != null) const SizedBox(height: 8),
              Text(
                message!,
                // 一句话居中；分段或长文左对齐 —— 「·」要点列表、免责声明这类多段
                // 正文居中后每行起点都在跳，读起来很费劲。
                textAlign: _isLongForm(message!)
                    ? TextAlign.start
                    : TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
  final List<MoodiaryAlertAction<T>> actions;
  final MoodiaryAlertActionsLayout actionsLayout;

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
      actions: _AlertActions(
        layout: actionsLayout,
        actions: [
          for (final action in actions)
            _ActionSpec(
              label: action.label,
              isPrimary: action.isPrimary,
              isDestructive: action.isDestructive,
              onPressed: action.enabled
                  ? () {
                      if (action.onIntercept?.call() == false) return;
                      Navigator.of(context).pop(action.value);
                    }
                  : null,
            ),
        ],
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
  void initState() {
    super.initState();
    // 只为了在有/无内容之间切换清除键，不参与校验。
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _value => widget.trim ? _controller.text.trim() : _controller.text;

  _MoodiaryAlertRoute<String>? get _route =>
      ModalRoute.of(context) as _MoodiaryAlertRoute<String>?;

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
    final scheme = context.colorScheme;
    final l10n = context.l10n;

    return PopScope(
      canPop: !_busy,
      child: _AlertShell(
        title: widget.title,
        message: widget.message,
        icon: widget.icon,
        isDestructive: widget.isDestructive,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AlertField(
              controller: _controller,
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
          ],
        ),
        actions: _AlertActions(
          layout: MoodiaryAlertActionsLayout.auto,
          actions: [
            _ActionSpec(
              label: widget.cancelLabel ?? l10n.cancel,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
            _ActionSpec(
              label: widget.confirmLabel ?? l10n.ok,
              isPrimary: !widget.isDestructive,
              isDestructive: widget.isDestructive,
              busy: _busy,
              onPressed: _busy ? null : _submit,
              busyColor: widget.isDestructive
                  ? scheme.onError
                  : scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆角填充式输入框。取代仓内并存的三种写法（OutlineInputBorder 默认 4 圆角 /
/// 裸下划线 / 从不 filled），圆角与按钮同为 [AppBorderRadius.mediumBorderRadius]。
class _AlertField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  const _AlertField({
    required this.controller,
    this.hintText,
    this.errorText,
    required this.enabled,
    required this.obscureText,
    this.maxLength,
    required this.maxLines,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: color == Colors.transparent
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      autofocus: true,
      enabled: enabled,
      obscureText: obscureText,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      minLines: 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.done,
      onSubmitted: onSubmitted,
      style: context.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        filled: true,
        isDense: true,
        counterText: '',
        fillColor: scheme.surfaceContainerHighest,
        constraints: maxLines > 1
            ? null
            : const BoxConstraints(minHeight: _kFieldHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        suffixIcon: (controller.text.isEmpty || obscureText || !enabled)
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: scheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: controller.clear,
              ),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        disabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(scheme.primary, 1.5),
        errorBorder: border(scheme.error, 1),
        focusedErrorBorder: border(scheme.error, 1.5),
      ),
    );
  }
}

// ─────────────────────────── 按钮 ───────────────────────────

class _ActionSpec {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final bool busy;
  final Color? busyColor;
  final VoidCallback? onPressed;

  const _ActionSpec({
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
    this.busy = false,
    this.busyColor,
    this.onPressed,
  });
}

/// 排布规则：单个动作全宽；两个动作且量出来放得下时横排等宽（原序，取消在左）；
/// 其余一律竖排并反序，让主操作在上、取消在最下。
class _AlertActions extends StatelessWidget {
  final List<_ActionSpec> actions;
  final MoodiaryAlertActionsLayout layout;

  const _AlertActions({required this.actions, required this.layout});

  bool _fitsInRow(BuildContext context, double maxWidth, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var total = _kActionGap * (actions.length - 1);
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      // 每颗按钮文字两侧至少各留 16。
      total += painter.width + 32;
    }
    return total <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = switch (layout) {
          MoodiaryAlertActionsLayout.horizontal => true,
          MoodiaryAlertActionsLayout.vertical => false,
          MoodiaryAlertActionsLayout.auto =>
            actions.length == 1 ||
                (actions.length == 2 &&
                    _fitsInRow(context, constraints.maxWidth, style)),
        };

        if (horizontal) {
          return Row(
            children: [
              for (final (index, action) in actions.indexed) ...[
                if (index > 0) const SizedBox(width: _kActionGap),
                Expanded(
                  child: _AlertButton(spec: action, textStyle: style),
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, action) in actions.reversed.indexed) ...[
              if (index > 0) const SizedBox(height: _kActionGap),
              _AlertButton(spec: action, textStyle: style),
            ],
          ],
        );
      },
    );
  }
}

class _AlertButton extends StatelessWidget {
  final _ActionSpec spec;
  final TextStyle? textStyle;

  const _AlertButton({required this.spec, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final Color background;
    final Color foreground;
    if (spec.isDestructive) {
      background = scheme.error;
      foreground = scheme.onError;
    } else if (spec.isPrimary) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    return FilledButton(
      onPressed: spec.onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size.fromHeight(_kActionHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: textStyle,
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
      ),
      child: spec.busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spec.busyColor ?? foreground,
              ),
            )
          : Text(spec.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
