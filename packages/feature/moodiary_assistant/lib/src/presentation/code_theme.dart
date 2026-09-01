import 'package:mui/mui.dart';
import 'package:re_highlight/languages/arduino.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/less.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/objectivec.dart';
import 'package:re_highlight/languages/perl.dart';
import 'package:re_highlight/languages/php-template.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python-repl.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/vbnet.dart';
import 'package:re_highlight/languages/wasm.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';

/// 助手代码块的语法高亮 —— 与编辑器**同源**。
///
/// 编辑器那边是 lowlight 3.3.0（highlight.js 11.11.1）；这边是 re_highlight 0.0.3，
/// 它是 highlight.js **11.9.0** 的 Dart 直译，token 名（`.hljs-*` 那一套 scope）因此
/// 与编辑器同一代。刻意不用官方点名的 `highlight` 包：那份译自 highlight.js 9 时代，
/// scope 名还是 `function` / `class` 那批旧的，且上游 highlight.dart 已停止维护
/// （re_highlight 的 README 说它就是为此而生）。
///
/// 语言集也照抄编辑器：lowlight 的 `common` 那 37 种，一个不多一个不少。
/// re_highlight 的 `all.dart` 会把 197 种语法规则全拖进包里，没有 common 那一档。
// `langXxx` 是 `final Mode`（不是 const），这张表跟着只能是 final。
final Map<String, Mode> _commonLanguages = {
  'arduino': langArduino,
  'bash': langBash,
  'c': langC,
  'cpp': langCpp,
  'csharp': langCsharp,
  'css': langCss,
  'diff': langDiff,
  'go': langGo,
  'graphql': langGraphql,
  'ini': langIni,
  'java': langJava,
  'javascript': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'less': langLess,
  'lua': langLua,
  'makefile': langMakefile,
  'markdown': langMarkdown,
  'objectivec': langObjectivec,
  'perl': langPerl,
  'php': langPhp,
  'php-template': langPhpTemplate,
  'plaintext': langPlaintext,
  'python': langPython,
  'python-repl': langPythonRepl,
  'r': langR,
  'ruby': langRuby,
  'rust': langRust,
  'scss': langScss,
  'shell': langShell,
  'sql': langSql,
  'swift': langSwift,
  'typescript': langTypescript,
  'vbnet': langVbnet,
  'wasm': langWasm,
  'xml': langXml,
  'yaml': langYaml,
};

/// 引擎是无状态的，注册一次全局复用（37 份语法规则解析一遍要钱）。
final Highlight codeHighlighter = Highlight()
  ..registerLanguages(_commonLanguages);

/// ``` 后面那个词能不能认出来。认得出返回**正式名**（`rs` → `rust`），认不出返回 null。
String? resolveCodeLanguage(String? language) {
  final name = language?.trim().toLowerCase();
  if (name == null || name.isEmpty) return null;
  return codeHighlighter.getLanguage(name)?.name?.toLowerCase();
}

/// GitHub 明暗两套，直接用 re_highlight 自带的（`styles/github.dart` /
/// `styles/github-dark.dart`，MIT）—— 与编辑器 `moodiary-editor.css` 里那份手抄的
/// `.hljs-*` 同宗同源，色值取自同一套 GitHub 色板。
///
/// **刻意不自己写一份。** 这两张表是 highlight.js 11 的 github 主题按 scope 生成的，
/// 我们抄一遍只会在下次 re_highlight 同步上游时变成陈旧副本。编辑器那份 CSS 就是前车
/// 之鉴：它停在 hljs 9/10 的 scope 划分上，`title.class_` / `variable.language_` /
/// `operator` / `selector-pseudo` / `meta-keyword` / `template-tag` 都没着色，而引擎
/// （lowlight 3.3.0 = hljs 11.11.1）是会吐这些 scope 的。
///
/// **只取 token 的颜色，`root` 用不上**：面板底色跟随主题（`surfaceContainerHigh`），
/// 与编辑器一致 —— 那边整块也是 `--app-surface`。上游的 `#ffffff` / `#0d1117` 硬用进来，
/// 换壁纸档或强调色档时页面里就会开一个纯白/纯黑的洞。
/// （`root` 留在表里是因为它本来就是上游那张表的一部分；`TextSpanRenderer` 只按 scope 查表，
/// 从来不读它。）
const Map<String, TextStyle> lightCodeTheme = githubTheme;
const Map<String, TextStyle> darkCodeTheme = githubDarkTheme;
