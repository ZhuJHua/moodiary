import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _width = 860.0;
const _pad = 20.0;
const _chipHeight = 44.0;
const _gap = 10.0;
const _fontSize = 14.0;

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

  final names = <String>{
    for (final s in sponsors)
      if (s['github'] case final String github)
        '@$github'
      else if (s['name'] case final String name)
        name,
  }.toList()..sort();
  // 不分先后：按名单内容取种子打乱，同一份名单每次生成的顺序一致，CI 才能校验产物
  names.shuffle(Random(_seed(names.join('\n'))));

  for (final (name, palette) in [('light', _light), ('dark', _dark)]) {
    final out = File('${root.path}/res/sponsor/sponsors_$name.svg');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      _render(names, sponsors.length, total, currency, palette),
    );
    stdout.writeln('已生成 ${out.path}');
  }
  stdout.writeln(
    '${sponsors.length} 位捐助者，合计 ${_money(total)} $currency，'
    '名单上 ${names.length} 位',
  );
}

String _render(
  List<String> names,
  int sponsorCount,
  double total,
  String currency,
  _Palette palette,
) {
  final rows = <List<(String, double)>>[];
  var row = <(String, double)>[];
  var used = 0.0;

  for (final name in names) {
    final chipWidth = 16 + _textWidth(name, _fontSize) + 16;
    if (row.isNotEmpty && used + _gap + chipWidth > _width - _pad * 2) {
      rows.add(row);
      row = [];
      used = 0;
    }
    row.add((name, chipWidth));
    used += (used == 0 ? 0 : _gap) + chipWidth;
  }
  if (row.isNotEmpty) rows.add(row);

  final height =
      _pad * 2 + rows.length * _chipHeight + (rows.length - 1) * _gap + 26;

  // 画布宽取最宽那行实际占的宽度：字宽是估的，让画布跟着内容走才不会被裁
  double lineWidth(List<(String, double)> line) =>
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
    );

  var y = _pad;
  for (final line in rows) {
    var x = (canvas - lineWidth(line)) / 2;
    for (final (name, chipWidth) in line) {
      buffer
        ..writeln(
          '<rect x="${_f(x)}" y="${_f(y)}" width="${_f(chipWidth)}" '
          'height="${_chipHeight.toInt()}" rx="${(_chipHeight / 2).toInt()}" '
          'fill="${palette.chip}" stroke="${palette.border}" stroke-width="1"/>',
        )
        ..writeln(
          '<text x="${_f(x + chipWidth / 2)}" y="${_f(y + _chipHeight / 2 + 5)}" '
          'font-size="$_fontSize" font-weight="500" text-anchor="middle" '
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
