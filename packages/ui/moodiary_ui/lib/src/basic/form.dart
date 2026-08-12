import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';

const double kMoodiaryFieldHeight = 48;

/// 圆角填充式输入框。取代仓内并存的三种写法（OutlineInputBorder 默认 4 圆角 /
/// 裸下划线 / 从不 filled），圆角与按钮同为 [AppBorderRadius.mediumBorderRadius]。
///
/// 字段名由 [label] 承担，静态置于框上方 —— 多字段表单里所有标签共用一条左基线，
/// 比会浮动的 M3 label 好扫。弹层标题已经点明唯一字段时（单输入弹窗）省略 [label]。
///
/// 尾部槽位一次只出现一个，优先级：[trailing] > 密码眼睛（[obscureText]）> 清除键。
class MoodiaryField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final double minHeight;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const MoodiaryField({
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
    this.minHeight = kMoodiaryFieldHeight,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  @override
  State<MoodiaryField> createState() => _MoodiaryFieldState();
}

class _MoodiaryFieldState extends State<MoodiaryField> {
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    // 只为了在有/无内容之间切换清除键，不参与校验。
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MoodiaryField oldWidget) {
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
    if (widget.controller.text.isEmpty) return null;
    return IconButton(
      icon: const Icon(LucideIcons.x, size: 18),
      color: scheme.onSurfaceVariant,
      visualDensity: .compact,
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: widget.controller.clear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final multiline = widget.maxLines > 1 && !widget.obscureText;

    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _obscured,
      maxLength: widget.maxLength,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: 1,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction ?? (multiline ? .newline : .done),
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      style: context.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      // 圆角填充式外观（filled / fillColor / contentPadding / 六种边框）已经整段
      // 搬进 `inputDecorationTheme`，见 core 的 mui_material_bridge.dart。
      // 这里只留**每个实例各不相同**的部分。
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: widget.errorText,
        counterText: '',
        constraints: multiline
            ? null
            : BoxConstraints(minHeight: widget.minHeight),
        suffixIcon: _buildTrailing(scheme),
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
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: .w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        field,
      ],
    );
  }
}

/// 表单分组标题。字段多到需要分节时才用（S3 的连接 / 凭证 / 选项）。
class MoodiaryFormSection extends StatelessWidget {
  final String label;

  const MoodiaryFormSection(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(left: 4, top: 4),
      child: Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: .w700,
          letterSpacing: 0.6,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}

/// 表单里的开关行。与 [MoodiaryField] 同宽同圆角同填充，读起来才属于这张表单
/// （[SwitchListTile] 是透明背景的列表行，混在填充式字段里像是掉进来的）。
class MoodiarySwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MoodiarySwitchField({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: AppBorderRadius.mediumBorderRadius,
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const .fromLTRB(16, 6, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
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

/// 表单末尾的破坏性动作行。刻意不放进底部动作条 —— 动作条只承载「取消 / 提交」
/// 这一对，破坏性操作混进去会让手指在错误的位置形成肌肉记忆。
class MoodiaryDangerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const MoodiaryDangerRow({
    super.key,
    required this.label,
    this.icon = LucideIcons.trash2,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.error.withValues(alpha: 0.08),
      borderRadius: AppBorderRadius.mediumBorderRadius,
      clipBehavior: .antiAlias,
      child: InkWell(
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
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: .w600,
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
