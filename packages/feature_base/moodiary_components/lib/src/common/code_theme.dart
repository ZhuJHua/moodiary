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

final Map<String, (String, Mode)> _commonLanguages = {
  'arduino': ('Arduino', langArduino),
  'bash': ('Bash', langBash),
  'c': ('C', langC),
  'cpp': ('C++', langCpp),
  'csharp': ('C#', langCsharp),
  'css': ('CSS', langCss),
  'diff': ('Diff', langDiff),
  'go': ('Go', langGo),
  'graphql': ('GraphQL', langGraphql),
  'ini': ('INI', langIni),
  'java': ('Java', langJava),
  'javascript': ('JavaScript', langJavascript),
  'json': ('JSON', langJson),
  'kotlin': ('Kotlin', langKotlin),
  'less': ('Less', langLess),
  'lua': ('Lua', langLua),
  'makefile': ('Makefile', langMakefile),
  'markdown': ('Markdown', langMarkdown),
  'objectivec': ('Objective-C', langObjectivec),
  'perl': ('Perl', langPerl),
  'php': ('PHP', langPhp),
  'php-template': ('PHP template', langPhpTemplate),
  'plaintext': ('Plain text', langPlaintext),
  'python': ('Python', langPython),
  'python-repl': ('Python REPL', langPythonRepl),
  'r': ('R', langR),
  'ruby': ('Ruby', langRuby),
  'rust': ('Rust', langRust),
  'scss': ('SCSS', langScss),
  'shell': ('Shell', langShell),
  'sql': ('SQL', langSql),
  'swift': ('Swift', langSwift),
  'typescript': ('TypeScript', langTypescript),
  'vbnet': ('VB.NET', langVbnet),
  'wasm': ('WebAssembly', langWasm),
  'xml': ('HTML / XML', langXml),
  'yaml': ('YAML', langYaml),
};

final Map<String, String> codeLanguageNames = Map.unmodifiable({
  for (final entry in _commonLanguages.entries)
    if (entry.key != 'plaintext') entry.key: entry.value.$1,
});

final Highlight codeHighlighter = Highlight()
  ..registerLanguages(
    _commonLanguages.map((id, entry) => MapEntry(id, entry.$2)),
  );

String? resolveCodeLanguage(String? language) {
  final name = language?.trim().toLowerCase();
  if (name == null || name.isEmpty) return null;
  final mode = codeHighlighter.getLanguage(name);
  if (mode == null) return null;
  return codeHighlighter.listLanguages().firstWhere(
    (key) => identical(codeHighlighter.getLanguage(key), mode),
  );
}

const Map<String, TextStyle> lightCodeTheme = githubTheme;
const Map<String, TextStyle> darkCodeTheme = githubDarkTheme;
