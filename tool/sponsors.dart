import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _width = 860.0;
const _pad = 20.0;
const _chipHeight = 44.0;
const _gap = 10.0;
const _fontSize = 14.0;
const _iconSize = 16.0;
const _iconGap = 6.0;

// GitHub 官方 mark（octicons mark-github，16 栅格）
const _githubMark =
    'M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z';

// 灰阶配色与 App 的 MuiAccent.neutral() 同源（SchemeMonochrome，source #000000）。
// 不画底色：透明背景，跟 README 里其它几张图一致
const _light = _Palette(
  chip: '#F4F4F4',
  border: '#C6C6C6',
  name: '#1B1B1B',
  caption: '#474747',
);

const _dark = _Palette(
  chip: '#1F1F1F',
  border: '#474747',
  name: '#E2E2E2',
  caption: '#C6C6C6',
);

class _Palette {
  final String chip;
  final String border;
  final String name;
  final String caption;

  const _Palette({
    required this.chip,
    required this.border,
    required this.name,
    required this.caption,
  });
}

void main(List<String> args) {
  final root = Directory.current;
  final source = File('${root.path}/sponsors.json');
  if (!source.existsSync()) {
    stderr.writeln('找不到 sponsors.json，请在仓库根目录运行。');
    exit(1);
  }

  final json = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final currency = json['currency'] as String? ?? 'CNY';
  final sponsors = (json['sponsors'] as List).cast<Map<String, dynamic>>();
  final total = sponsors.fold<double>(
    0,
    (sum, s) => sum + (s['amount'] as num).toDouble(),
  );

  final entries = <(String, bool)>{
    for (final s in sponsors)
      if (s['github'] case final String github)
        (github, true)
      else if (s['name'] case final String name)
        (name, false),
  }.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  // 不分先后：按名单内容取种子打乱，同一份名单每次生成的顺序一致，CI 才能校验产物
  entries.shuffle(Random(_seed(entries.map((e) => e.$1).join('\n'))));

  for (final (name, palette) in [('light', _light), ('dark', _dark)]) {
    final out = File('${root.path}/res/sponsor/sponsors_$name.svg');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      _render(entries, sponsors.length, total, currency, palette),
    );
    stdout.writeln('已生成 ${out.path}');
  }
  stdout.writeln(
    '${sponsors.length} 位捐助者，合计 ${_money(total)} $currency，'
    '名单上 ${entries.length} 位',
  );
}

String _render(
  List<(String, bool)> entries,
  int sponsorCount,
  double total,
  String currency,
  _Palette palette,
) {
  final rows = <List<((String, bool), double)>>[];
  var row = <((String, bool), double)>[];
  var used = 0.0;

  for (final entry in entries) {
    final chipWidth =
        16 +
        (entry.$2 ? _iconSize + _iconGap : 0) +
        _textWidth(entry.$1, _fontSize) +
        16;
    if (row.isNotEmpty && used + _gap + chipWidth > _width - _pad * 2) {
      rows.add(row);
      row = [];
      used = 0;
    }
    row.add((entry, chipWidth));
    used += (used == 0 ? 0 : _gap) + chipWidth;
  }
  if (row.isNotEmpty) rows.add(row);

  final height =
      _pad * 2 + rows.length * _chipHeight + (rows.length - 1) * _gap + 26;

  // 画布宽取最宽那行实际占的宽度：字宽是估的，让画布跟着内容走才不会被裁
  double lineWidth(List<((String, bool), double)> line) =>
      line.fold<double>(0, (sum, e) => sum + e.$2) + (line.length - 1) * _gap;
  final contentWidth = rows.isEmpty
      ? 0.0
      : rows.map(lineWidth).reduce((a, b) => a > b ? a : b);
  final canvas = max(contentWidth, 320) + _pad * 2;

  final buffer = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="${_f(canvas)}" '
      'height="${height.toInt()}" viewBox="0 0 ${_f(canvas)} ${height.toInt()}" '
      'font-family="-apple-system, BlinkMacSystemFont, &#39;Segoe UI&#39;, '
      'Roboto, &#39;PingFang SC&#39;, &#39;Hiragino Sans GB&#39;, '
      '&#39;Microsoft YaHei&#39;, sans-serif">',
    )
    ..writeln(
      '<symbol id="gh" viewBox="0 0 16 16"><path fill="${palette.name}" '
      'd="$_githubMark"/></symbol>',
    );

  var y = _pad;
  for (final line in rows) {
    var x = (canvas - lineWidth(line)) / 2;
    for (final ((name, isGithub), chipWidth) in line) {
      buffer.writeln(
        '<rect x="${_f(x)}" y="${_f(y)}" width="${_f(chipWidth)}" '
        'height="${_chipHeight.toInt()}" rx="${(_chipHeight / 2).toInt()}" '
        'fill="${palette.chip}" stroke="${palette.border}" stroke-width="1"/>',
      );
      var textX = x + 16;
      if (isGithub) {
        buffer.writeln(
          '<use href="#gh" x="${_f(textX)}" '
          'y="${_f(y + (_chipHeight - _iconSize) / 2)}" '
          'width="${_iconSize.toInt()}" height="${_iconSize.toInt()}"/>',
        );
        textX += _iconSize + _iconGap;
      }
      buffer.writeln(
        '<text x="${_f(textX)}" y="${_f(y + _chipHeight / 2 + 5)}" '
        'font-size="$_fontSize" font-weight="500" '
        'fill="${palette.name}">${_escape(name)}</text>',
      );
      x += chipWidth + _gap;
    }
    y += _chipHeight + _gap;
  }

  buffer
    ..writeln(
      '<text x="${_f(canvas / 2)}" y="${_f(height - _pad + 2)}" '
      'font-size="12" text-anchor="middle" fill="${palette.caption}">'
      '$sponsorCount sponsors · ${_money(total)} $currency · thank you</text>',
    )
    ..writeln('</svg>');
  return buffer.toString();
}

// String.hashCode 不保证跨 VM 版本稳定，自己算一个
int _seed(String text) => text.codeUnits.fold(
  0x811c9dc5,
  (h, c) => ((h ^ c) * 0x01000193) & 0x7fffffff,
);

// SVG 里量不到字宽：CJK 按一个字身、其余按 0.55 em 估，够排版用
double _textWidth(String text, double fontSize) {
  var units = 0.0;
  for (final rune in text.runes) {
    units += rune > 0x2E80 ? 1.04 : 0.62;
  }
  return units * fontSize;
}

String _money(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : value.toString();

String _f(double value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
