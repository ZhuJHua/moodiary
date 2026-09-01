import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/presentation/code_theme.dart';
import 'package:moodiary_assistant/src/presentation/markdown_code_block.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

/// 编辑器（lowlight 3.3.0 的 `common`）注册的那 37 种。助手这边必须一模一样 ——
/// 「与编辑器同源」是选 re_highlight 的全部理由，语言集分叉就等于白选。
const _editorCommonLanguages = {
  'arduino',
  'bash',
  'c',
  'cpp',
  'csharp',
  'css',
  'diff',
  'go',
  'graphql',
  'ini',
  'java',
  'javascript',
  'json',
  'kotlin',
  'less',
  'lua',
  'makefile',
  'markdown',
  'objectivec',
  'perl',
  'php',
  'php-template',
  'plaintext',
  'python',
  'python-repl',
  'r',
  'ruby',
  'rust',
  'scss',
  'shell',
  'sql',
  'swift',
  'typescript',
  'vbnet',
  'wasm',
  'xml',
  'yaml',
};

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) {
    // 明暗要挂在 MaterialApp 的 `theme` 上：`context.theme` 是 `Theme.of(context)` 的
    // 派生视图，MaterialApp 会在自己下面重挂一层 Theme，套在外面的那层盖不住。
    final data = buildMuiTheme(brightness: brightness);
    return TranslationProvider(
      child: MuiTheme(
        data: data,
        child: MaterialApp(
          theme: data,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  const code = 'fn main() {\n    // note\n    let x = "hi";\n}';

  /// 代码区那个 Text 里所有 span 的文字与样式，按出现顺序摊平。
  List<(String, TextStyle?)> spansOf(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Text),
      ),
    );
    final out = <(String, TextStyle?)>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) out.add((span.text!, span.style));
        span.children?.forEach(walk);
      }
    }

    final span = text.textSpan;
    if (span != null) {
      walk(span);
    } else {
      out.add((text.data!, text.style));
    }
    return out;
  }

  test('语言集与编辑器的 lowlight common 一模一样', () {
    expect(codeHighlighter.listLanguages().toSet(), _editorCommonLanguages);
  });

  test('语言名按别名/大小写解析到正式名，认不出给 null', () {
    expect(resolveCodeLanguage('RS'), 'rust');
    expect(resolveCodeLanguage('js'), 'javascript');
    for (final unknown in [null, '', '   ', 'wingdings']) {
      expect(resolveCodeLanguage(unknown), isNull, reason: '$unknown');
    }
  });

  testWidgets('原文逐字保留，且关键字与注释各自上了主题里的色', (tester) async {
    await tester.pumpWidget(
      host(const MarkdownCodeBlock(name: 'rust', code: code)),
    );
    final spans = spansOf(tester);

    expect(spans.map((it) => it.$1).join(), code);
    expect(
      spans.firstWhere((it) => it.$1.trim() == 'fn').$2?.color,
      lightCodeTheme['keyword']!.color,
    );
    expect(
      spans.firstWhere((it) => it.$1.contains('note')).$2?.color,
      lightCodeTheme['comment']!.color,
    );
  });

  testWidgets('深色下换成深色那套', (tester) async {
    await tester.pumpWidget(
      host(
        const MarkdownCodeBlock(name: 'rust', code: code),
        brightness: Brightness.dark,
      ),
    );
    expect(
      spansOf(tester).firstWhere((it) => it.$1.trim() == 'fn').$2?.color,
      darkCodeTheme['keyword']!.color,
    );
  });

  testWidgets('认不出的语言退回纯文本，标签回落用户写的那个词', (tester) async {
    await tester.pumpWidget(
      host(const MarkdownCodeBlock(name: 'wingdings', code: code)),
    );
    expect(spansOf(tester).single.$1, code);
    expect(find.text('wingdings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
