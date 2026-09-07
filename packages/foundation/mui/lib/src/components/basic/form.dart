import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

const double kMoodiaryFieldHeight = 48;

enum MFieldVariant {
  filled,

  plain,
}

class MField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final int? maxLength;

  final int? maxLines;

  final bool expands;

  final double minHeight;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final MFieldVariant variant;

  final bool showClear;

  final EdgeInsetsGeometry? contentPadding;

  const MField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.expands = false,
    this.minHeight = kMoodiaryFieldHeight,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
    this.variant = MFieldVariant.filled,
    this.showClear = true,
    this.contentPadding,
  }) : assert(
         !expands || maxLines == null,
         'expands 与 maxLines 互斥：撑满高度时行数由父级的高度决定',
       );

  @override
  State<MField> createState() => _MFieldState();
}

class _MFieldState extends State<MField> {
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Widget? _buildTrailing(ColorScheme scheme) {
    if (widget.trailing != null) return widget.trailing;
    if (!widget.enabled) return null;
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(_obscured ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
        color: scheme.onSurfaceVariant,
        visualDensity: .compact,
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }
    if (!widget.showClear) return null;
    if (widget.controller.text.isEmpty) return null;
    return IconButton(
      icon: const Icon(LucideIcons.x, size: 18),
      color: scheme.onSurfaceVariant,
      visualDensity: .compact,
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: () {
        widget.controller.clear();
        widget.onChanged?.call('');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final multiline =
        !widget.obscureText && (widget.expands || (widget.maxLines ?? 2) > 1);
    final plain = widget.variant == MFieldVariant.plain;
    final InputBorder? noBorder = plain ? InputBorder.none : null;

    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _obscured,
      maxLength: widget.maxLength,
      maxLines: widget.obscureText
          ? 1
          : (widget.expands ? null : widget.maxLines),
      minLines: widget.expands ? null : 1,
      expands: widget.expands && !widget.obscureText,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction ?? (multiline ? .newline : .done),
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      style: context.theme.typography.bodyLarge.onSurface,
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: widget.errorText,
        counterText: '',
        constraints: multiline || plain
            ? null
            : BoxConstraints(minHeight: widget.minHeight),
        suffixIcon: _buildTrailing(scheme),
        filled: plain ? false : null,
        isCollapsed: plain ? true : null,
        contentPadding: plain
            ? (widget.contentPadding ?? EdgeInsets.zero)
            : widget.contentPadding,
        border: noBorder,
        enabledBorder: noBorder,
        disabledBorder: noBorder,
        focusedBorder: noBorder,
        errorBorder: noBorder,
        focusedErrorBorder: noBorder,
      ),
    );

    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const .only(left: 4, bottom: 6),
          child: Text(
            widget.label!,
            style: context
                .theme
                .typography
                .labelMedium
                .emphasized
                .onSurfaceVariant,
          ),
        ),
        field,
      ],
    );
  }
}

class MFormSection extends StatelessWidget {
  final String label;

  const MFormSection(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(left: 4, top: 4),
      child: Text(
        label,
        style: context.theme.typography.labelMedium.emphasized.primary.copyWith(
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class MSwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MSwitchField({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: MuiRadius.md,
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const .fromLTRB(16, 6, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.theme.typography.bodyLarge.onSurface,
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class MDangerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const MDangerRow({
    super.key,
    required this.label,
    this.icon = LucideIcons.trash2,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Material(
      color: scheme.error.withValues(alpha: 0.08),
      borderRadius: MuiRadius.md,
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: .center,
            children: [
              Icon(icon, size: 16, color: scheme.error),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.theme.typography.labelLarge.emphasized.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
