import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

const double kMoodiaryFieldHeight = 48;

/// 输入框的外观档。
enum MFieldVariant {
  /// 圆角填充式：底色 / 内边距 / 六条边框全部来自 `inputDecorationTheme`。
  filled,

  /// 无背景：宿主自己画了容器（聊天输入面板、AppBar 里的搜索框），
  /// 字直接落在宿主的面上。
  ///
  /// **必须同时撤掉六条边框，只撤 `border` 不管用** —— `InputDecorator` 先解析
  /// 状态边框（enabled / focused / disabled / error / focusedError），
  /// 只有它们全为 null 才回落到 `decoration.border`，而主题把五条都填满了。
  /// 同理 `filled: false` 也漏不得：`applyDefaults` 是 `filled ?? theme.filled`，
  /// 不写就继承 true。这两个坑合起来的症状是「写了 border: .none 却还有个药丸」。
  plain,
}

/// 圆角填充式输入框。取代仓内并存的三种写法（OutlineInputBorder 默认 4 圆角 /
/// 裸下划线 / 从不 filled），圆角与按钮同为 [MuiRadius.md]。
///
/// 字段名由 [label] 承担，静态置于框上方 —— 多字段表单里所有标签共用一条左基线，
/// 比会浮动的 M3 label 好扫。弹层标题已经点明唯一字段时（单输入弹窗）省略 [label]。
///
/// 尾部槽位一次只出现一个，优先级：[trailing] > 密码眼睛（[obscureText]）> 清除键
/// （[showClear] 只管最后这一个，关掉它不影响眼睛）。
class MField extends StatefulWidget {
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
  final MFieldVariant variant;

  /// 关掉内置清除键（[trailing] 与密码眼睛不受影响）。聊天输入框、并排的数值格
  /// 都不该有它。
  final bool showClear;

  /// 覆盖主题的内边距。[MFieldVariant.plain] 下不传即为零。
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
  });

  @override
  State<MField> createState() => _MFieldState();
}

class _MFieldState extends State<MField> {
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    // 只为了在有/无内容之间切换清除键，不参与校验。
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
      // 清空后要**手动**补一次 onChanged：`TextField.onChanged` 只在用户输入时触发，
      // 程序改 controller 不算。少了这一句，「清除」会让搜索类页面停在旧结果上。
      onPressed: () {
        widget.controller.clear();
        widget.onChanged?.call('');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final multiline = widget.maxLines > 1 && !widget.obscureText;
    final plain = widget.variant == MFieldVariant.plain;
    final InputBorder? noBorder = plain ? InputBorder.none : null;

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
      style: context.theme.typography.bodyLarge.onSurface,
      // 圆角填充式外观（filled / fillColor / contentPadding / 六种边框）已经整段
      // 搬进 `inputDecorationTheme`，见 mui 的 themes/build.dart。
      // 这里只留**每个实例各不相同**的部分。
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: widget.errorText,
        counterText: '',
        // plain 档不给最小高度：宿主已经决定了这块地方多高。
        constraints: multiline || plain
            ? null
            : BoxConstraints(minHeight: widget.minHeight),
        suffixIcon: _buildTrailing(scheme),
        // 下面六项在 filled 档全传 null，也就是照旧继承主题。
        // 见 [MFieldVariant.plain] 上的注释：六条边框缺一条都白撤。
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

/// 表单分组标题。字段多到需要分节时才用（S3 的连接 / 凭证 / 选项）。
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

/// 表单里的开关行。与 [MField] 同宽同圆角同填充，读起来才属于这张表单
/// （[SwitchListTile] 是透明背景的列表行，混在填充式字段里像是掉进来的）。
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

/// 表单末尾的破坏性动作行。刻意不放进底部动作条 —— 动作条只承载「取消 / 提交」
/// 这一对，破坏性操作混进去会让手指在错误的位置形成肌肉记忆。
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
