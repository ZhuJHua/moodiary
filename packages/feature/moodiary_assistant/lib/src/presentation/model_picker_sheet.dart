/// 会话开始前挑模型与思考强度的底部弹窗。
///
/// 用弹窗而不是锚定菜单，是因为中转站的模型能有几百个（openrouter 352 个）——
/// 那个体量必须有搜索框和一整屏的滚动区，挂在输入框上方的小浮层装不下。
library;

import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:mui/mui.dart';

/// 选择结果。
typedef ModelChoice = ({String modelId, String level});

/// 打开选择器。返回 null 表示用户取消（下拉 / 点遮罩 / 返回键），此时不应改动任何状态。
Future<ModelChoice?> showModelPicker(
  BuildContext context, {
  required String providerName,
  required List<ModelOption> options,
  required String modelId,
  String level = '',
  /// 编辑页只挑模型（那里定的是「默认模型」，思考强度是每次会话开始前才定的）。
  bool showEffort = true,
}) {
  return MSheet.show<ModelChoice>(
    context,
    builder: (sheetContext) => _ModelPickerBody(
      providerName: providerName,
      options: options,
      modelId: modelId,
      level: level,
      showEffort: showEffort,
    ),
  );
}

class _ModelPickerBody extends StatefulWidget {
  final String providerName;
  final List<ModelOption> options;
  final String modelId;
  final String level;
  final bool showEffort;

  const _ModelPickerBody({
    required this.providerName,
    required this.options,
    required this.modelId,
    required this.level,
    required this.showEffort,
  });

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  final _search = TextEditingController();

  late String _modelId = widget.modelId;
  late String _level = widget.level;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ModelOption? get _current {
    for (final o in widget.options) {
      if (o.id == _modelId) return o;
    }
    return null;
  }

  List<ModelOption> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.id.toLowerCase().contains(q) || o.label.toLowerCase().contains(q))
          o,
    ];
  }

  void _pickModel(ModelOption option) {
    setState(() {
      _modelId = option.id;
      // 档位表按模型给，换了模型旧档位可能整个不在表里（有的模型只有 high/max）。
      // 发一个模型不认的档位会被供应商直接拒，所以退回「关」。
      if (_level.isNotEmpty && !option.levels.contains(_level)) _level = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final visible = _visible;
    final levels = widget.showEffort
        ? (_current?.levels ?? const <String>[])
        : const <String>[];

    return MSheetScaffold<ModelChoice>(
      title: l10n.assistant.modelProviderPickModel,
      subtitle: widget.providerName,
      icon: LucideIcons.cpu,
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(
          label: l10n.common.ok,
          value: (modelId: _modelId, level: _level),
          isPrimary: true,
          enabled: _modelId.isNotEmpty,
        ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          if (widget.options.length > 6)
            Padding(
              padding: const .only(bottom: 8),
              child: MField(
                controller: _search,
                hintText: l10n.assistant.modelProviderSearchModelHint,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          // 列表自己滚，强度滑杆钉在下面不跟着走 —— 几百个模型时滑杆不该被翻没。
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: visible.isEmpty
                ? Padding(
                    padding: const .symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        l10n.assistant.modelProviderNoModelMatch,
                        style: typography.bodySmall.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final option = visible[index];
                      return _ModelTile(
                        option: option,
                        selected: option.id == _modelId,
                        onTap: () => _pickModel(option),
                      );
                    },
                  ),
          ),
          if (levels.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(height: 17, color: scheme.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.assistant.reasoningEffort,
                    style: typography.labelLarge.onSurfaceVariant,
                  ),
                ),
                Text(
                  // 直接用目录的原值（low / xhigh / max…）：那是一个开放集合，
                  // 手写映射表只会在出现新档位时悄悄漏掉。
                  _level.isEmpty ? l10n.assistant.reasoningOff : _level,
                  style: typography.labelLarge.emphasized.primary,
                ),
              ],
            ),
            Slider(
              // 0 号档位是「关」，之后依次是目录给出的档位。
              value: (_level.isEmpty ? 0 : levels.indexOf(_level) + 1)
                  .toDouble()
                  .clamp(0, levels.length.toDouble()),
              max: levels.length.toDouble(),
              divisions: levels.length,
              onChanged: (v) {
                final index = v.round();
                setState(() => _level = index <= 0 ? '' : levels[index - 1]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ModelOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModelTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n;
    final preset = option.preset;
    // 几百个模型里挑，光有名字判断不了。徽章全部来自目录，自定义供应商没有目录
    // 就只剩 id 一行 —— 那也是实话。
    final badges = <Widget>[
      if (preset != null) ...[
        if (preset.toolCall)
          _Badge(icon: LucideIcons.wrench, text: l10n.assistant.tool),
        if (preset.reasoning)
          _Badge(
            icon: LucideIcons.brain,
            text: l10n.assistant.modelProviderBadgeReasoning,
          ),
        if (preset.acceptsImage)
          _Badge(
            icon: LucideIcons.image,
            text: l10n.assistant.modelProviderBadgeVision,
          ),
        if (_formatContext(preset.contextLimit) case final ctx?)
          _Badge(icon: LucideIcons.chevronsUpDown, text: ctx),
        if (_formatPrice(preset.inputCost, preset.outputCost) case final price?)
          _Badge(icon: LucideIcons.banknote, text: price),
      ],
    ];

    return Padding(
      padding: const .only(bottom: 6),
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: onTap,
          child: Padding(
            padding: const .symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: selected
                                  ? typography.titleSmall.emphasized
                                        .onSecondaryContainer
                                  : typography.titleSmall.onSurface,
                            ),
                          ),
                          if (option.deprecated) ...[
                            const SizedBox(width: 6),
                            Text(
                              l10n.assistant.modelDeprecated,
                              style: typography.labelSmall.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      if (option.label != option.id)
                        Text(
                          option.id,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: typography.labelSmall.onSurfaceVariant,
                        ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: badges),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const .only(left: 8, top: 2),
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: .circular(6),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.theme.typography.labelSmall.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

String? _formatContext(int? n) {
  if (n == null || n <= 0) return null;
  if (n >= 1000000) {
    final m = n / 1000000;
    return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
  }
  if (n >= 1000) return '${(n / 1000).round()}K';
  return '$n';
}

String? _formatPrice(num? input, num? output) {
  if (input == null && output == null) return null;
  String f(num? v) => v == null ? '?' : '\$${_trimNum(v)}';
  return '${f(input)}/${f(output)}';
}

String _trimNum(num v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
