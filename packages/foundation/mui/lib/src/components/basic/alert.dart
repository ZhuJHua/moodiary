import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

const double _kAlertMaxWidth = 340;
const double _kAlertScreenPadding = 28;
const double _kActionHeight = 44;
const double _kActionGap = 8;
const double _kFieldHeight = 46;

abstract final class MAlert {
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

class _MAlertRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Color barrierColorValue;
  final String barrierLabelText;

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

  void setBarrierDismissible(bool value) {
    if (_barrierDismissible == value) return;
    _barrierDismissible = value;
    changedInternalState();
  }

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
    final curve = animation.status == AnimationStatus.reverse
        ? Curves.easeInCubic
        : Curves.easeOutCubic;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        final t = curve.transform(animation.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: inner),
        );
      },
      child: child,
    );
  }
}

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

bool _isLongForm(String message) =>
    message.contains('\n') || message.runes.length > 44;

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
