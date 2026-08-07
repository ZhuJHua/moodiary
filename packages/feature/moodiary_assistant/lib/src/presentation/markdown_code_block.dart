import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 助手回复里的 ``` 代码块。替代 gpt_markdown 自带的 CodeField —— 那个把复制按钮
/// 写死成 `Icons.content_paste` / `Icons.done` 且文案是硬编码英文，两者都没有入参。
/// 传给 `GptMarkdown(codeBuilder:)`。
class MarkdownCodeBlock extends StatefulWidget {
  final String name;
  final String code;

  const MarkdownCodeBlock({super.key, required this.name, required this.code});

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Padding(
                padding: const .symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  widget.name,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  visualDensity: .compact,
                  textStyle: context.textTheme.labelMedium,
                ),
                onPressed: _copy,
                icon: Icon(
                  _copied ? LucideIcons.check : LucideIcons.copy,
                  size: 15,
                ),
                label: Text(
                  _copied ? l10n.assistantCopied : l10n.assistantCopyTooltip,
                ),
              ),
            ],
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SingleChildScrollView(
            scrollDirection: .horizontal,
            padding: const .all(14),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                package: 'gpt_markdown',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
