import 'dart:convert';
import 'dart:io';

const _width = 860.0;
const _pad = 20.0;
const _chipHeight = 44.0;
const _gap = 10.0;
const _fontSize = 14.0;
const _amountSize = 12.0;

// 灰阶配色与 App 的 MuiAccent.neutral() 同源（SchemeMonochrome，source #000000）。
// 不画底色：透明背景，跟 README 里其它几张图一致
const _light = _Palette(
  chip: '#F4F4F4',
  chipTop: '#E8E8E8',
  border: '#C6C6C6',
  name: '#1B1B1B',
  amount: '#777777',
  caption: '#474747',
);

const _dark = _Palette(
  chip: '#1F1F1F',
  chipTop: '#2A2A2A',
  border: '#474747',
  name: '#E2E2E2',
  amount: '#919191',
  caption: '#C6C6C6',
);

class _Palette {
  final String chip;
  final String chipTop;
  final String border;
  final String name;
  final String amount;
  final String caption;

  const _Palette({
    required this.chip,
    required this.chipTop,
    required this.border,
    required this.name,
    required this.amount,
    required this.caption,
  });
}

class _Sponsor {
  final String name;
  final String? github;
  final double amount;

  const _Sponsor({required this.name, this.github, required this.amount});
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
  final sponsors =
      (json['sponsors'] as List)
          .map(
            (e) => _Sponsor(
              name: (e as Map<String, dynamic>)['name'] as String,
              github: e['github'] as String?,
              amount: (e['amount'] as num).toDouble(),
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  for (final (name, palette) in [('light', _light), ('dark', _dark)]) {
    final out = File('${root.path}/res/sponsor/sponsors_$name.svg');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(_render(sponsors, currency, palette));
    stdout.writeln('已生成 ${out.path}');
  }

  final total = sponsors.fold<double>(0, (sum, s) => sum + s.amount);
  stdout.writeln('${sponsors.length} 位捐助者，合计 ${_money(total)} $currency');
}

String _render(List<_Sponsor> sponsors, String currency, _Palette palette) {
  final rows = <List<(_Sponsor, double)>>[];
  var row = <(_Sponsor, double)>[];
  var used = 0.0;

  for (final sponsor in sponsors) {
    final chipWidth = _chipWidth(sponsor, currency);
    if (row.isNotEmpty && used + _gap + chipWidth > _width - _pad * 2) {
      rows.add(row);
      row = [];
      used = 0;
    }
    row.add((sponsor, chipWidth));
    used += (used == 0 ? 0 : _gap) + chipWidth;
  }
  if (row.isNotEmpty) rows.add(row);

  final height =
      _pad * 2 + rows.length * _chipHeight + (rows.length - 1) * _gap + 26;

  // 画布宽取最宽那行实际占的宽度：字宽是估的，让画布跟着内容走才不会被裁
  double lineWidth(List<(_Sponsor, double)> line) =>
      line.fold<double>(0, (sum, e) => sum + e.$2) + (line.length - 1) * _gap;
  final contentWidth = rows.map(lineWidth).reduce((a, b) => a > b ? a : b);
  final canvas = contentWidth + _pad * 2;

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
    for (final (sponsor, chipWidth) in line) {
      final isTop = sponsor.amount >= 20;
      buffer
        ..writeln(
          '<rect x="${_f(x)}" y="${_f(y)}" width="${_f(chipWidth)}" '
          'height="${_chipHeight.toInt()}" rx="${(_chipHeight / 2).toInt()}" '
          'fill="${isTop ? palette.chipTop : palette.chip}" '
          'stroke="${palette.border}" stroke-width="1"/>',
        )
        ..writeln(
          '<text x="${_f(x + 16)}" y="${_f(y + _chipHeight / 2 + 5)}" '
          'font-size="$_fontSize" font-weight="${isTop ? 600 : 500}" '
          'fill="${palette.name}">${_escape(sponsor.name)}</text>',
        )
        ..writeln(
          '<text x="${_f(x + chipWidth - 16)}" '
          'y="${_f(y + _chipHeight / 2 + 4)}" font-size="$_amountSize" '
          'text-anchor="end" fill="${palette.amount}">'
          '${_money(sponsor.amount)}</text>',
        );
      x += chipWidth + _gap;
    }
    y += _chipHeight + _gap;
  }

  final total = sponsors.fold<double>(0, (sum, s) => sum + s.amount);
  buffer
    ..writeln(
      '<text x="${_f(canvas / 2)}" y="${_f(height - _pad + 2)}" '
      'font-size="12" text-anchor="middle" fill="${palette.caption}">'
      '${sponsors.length} sponsors · ${_money(total)} $currency · thank you</text>',
    )
    ..writeln('</svg>');
  return buffer.toString();
}

double _chipWidth(_Sponsor sponsor, String currency) {
  final name = _textWidth(sponsor.name, _fontSize);
  final amount = _textWidth(_money(sponsor.amount), _amountSize);
  return 16 + name + 12 + amount + 16;
}

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

String _f(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(1);

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
