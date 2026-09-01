import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:re_highlight/re_highlight.dart';

import 'code_theme.dart';

/// 助手回复里的 ``` 代码块。替代 gpt_markdown 自带的 CodeField —— 那个把复制按钮
/// 写死成 `Icons.content_paste` / `Icons.done` 且文案是硬编码英文，两者都没有入参。
///
/// 语法高亮 gpt_markdown **从来没有**（1.2.1 依然只依赖 flutter_math_fork，`CodeField`
/// 那句 "with syntax highlighting" 的文档注释是假的）。官方的说法是自己用 `codeBuilder`
/// 接一个第三方包，我们接的是 re_highlight —— 与编辑器同源，见 [code_theme.dart]。
///
/// **token 用 GitHub 明暗两套固定色板**（与编辑器同一套，见 [code_theme.dart]），
/// 但**面板底色跟随主题**（`surfaceContainerHigh`）—— 与编辑器的做法对齐：那边整块也是
/// `--app-surface`，只有 token 是固定色。主题自带的 `#ffffff` / `#0d1117` 不用，否则换
/// 壁纸档或强调色档时，页面里会突兀地开一个纯白/纯黑的洞。
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

    // 没被主题命中的 token（tag / params / property…）落到这个样式上，所以它得是正文色。
    // 命中的那些只覆盖颜色与字形，字体和字号仍从这里继承 —— re_highlight 把 span 挂成一棵
    // 树，子 span 的 style 是叠在祖先上的。
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
                  // 认出语法就报它的正式名（rs → rust），认不出才回落用户写的那个词。
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
