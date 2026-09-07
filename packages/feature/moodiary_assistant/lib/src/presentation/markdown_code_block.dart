import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MarkdownCodeBlock extends StatefulWidget {
  final String name;
  final String code;

  const MarkdownCodeBlock({super.key, required this.name, required this.code});

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final theme = context.theme.isDark ? darkCodeTheme : lightCodeTheme;

    final base = context.theme.typography.bodyMedium.onSurface.copyWith(
      fontFamily: 'JetBrainsMono',
      package: 'gpt_markdown',
    );

    final language = resolveCodeLanguage(widget.name);
    TextSpan? highlighted;
    if (language != null) {
      final renderer = TextSpanRenderer(base, theme);
      codeHighlighter
          .highlight(code: widget.code, language: language)
          .render(renderer);
      highlighted = renderer.span;
    }

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
                  language ?? widget.name,
                  style: context.theme.typography.labelMedium.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  visualDensity: .compact,
                  textStyle:
                      context.theme.typography.labelMedium.onSurfaceVariant,
                ),
                onPressed: _copy,
                icon: Icon(
                  _copied ? LucideIcons.check : LucideIcons.copy,
                  size: 15,
                ),
                label: Text(
                  _copied ? l10n.assistant.copied : l10n.assistant.copyTooltip,
                ),
              ),
            ],
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SingleChildScrollView(
            scrollDirection: .horizontal,
            padding: const .all(14),
            child: highlighted == null
                ? Text(widget.code, style: base)
                : Text.rich(highlighted),
          ),
        ],
      ),
    );
  }
}
