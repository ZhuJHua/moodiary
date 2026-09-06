import 'dart:convert';
import 'dart:io';

/// 生成 README 顶部的 socialify 头图（res/social.svg）。
///
/// 需要 PATH 上有 rsvg-convert 与 magick（brew install librsvg imagemagick）。
const _brandDir = 'packages/feature_base/moodiary_components/assets/brand';
const _logoForLight = '$_brandDir/logo_light.svg';
const _logoForDark = '$_brandDir/logo_dark.svg';
const _output = 'res/social.svg';
const _logoPx = 256;

const _params = {
  'description': '1',
  'font': 'Jost',
  'name': '1',
  'pattern': 'Plus',
  'theme': 'Auto',
};

Future<void> main() async {
  for (final path in [_logoForLight, _logoForDark]) {
    if (!File(path).existsSync()) {
      stderr.writeln('找不到 $path，请在仓库根目录运行。');
      exit(1);
    }
  }

  final lightLogo = await _rasterize(File(_logoForLight).readAsStringSync());
  final darkLogo = await _rasterize(File(_logoForDark).readAsStringSync());

  final query = {..._params, 'logo': _dataUri(lightLogo)}.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  final uri = Uri.parse(
    'https://socialify.git.ci/ZhuJHua/moodiary/image?$query',
  );

  final client = HttpClient();
  final response = await (await client.getUrl(uri)).close();
  if (response.statusCode != 200) {
    stderr.writeln('socialify 返回 ${response.statusCode}');
    exit(1);
  }
  var svg = await response.transform(utf8.decoder).join();
  client.close();

  if (!svg.startsWith('<svg')) {
    stderr.writeln('socialify 没有返回 SVG：${svg.substring(0, 200)}');
    exit(1);
  }

  svg = _swapDarkCardLogo(svg, from: _dataUri(lightLogo), to: _dataUri(darkLogo));

  File(_output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(svg);
  stdout.writeln('已生成 $_output（${svg.length} 字节）');
}

Future<List<int>> _rasterize(String svg) async {
  final temp = await Directory.systemTemp.createTemp('moodiary_social');
  try {
    final input = File('${temp.path}/logo.svg')..writeAsStringSync(svg);
    final raw = '${temp.path}/raw.png';
    final out = '${temp.path}/logo.png';

    final render = await Process.run('rsvg-convert', [
      '-w',
      '$_logoPx',
      '-h',
      '$_logoPx',
      input.path,
      '-o',
      raw,
    ]);
    if (render.exitCode != 0) {
      stderr.writeln('rsvg-convert 失败：${render.stderr}');
      exit(1);
    }

    // logo 要以 data URI 进 query，socialify 那边超长直接 431；
    // 商标只有几种颜色，量化成调色板 PNG 能小一个数量级（12.5KB → 2.1KB）
    final quantize = await Process.run('magick', [
      raw,
      '-strip',
      '-colors',
      '64',
      'PNG8:$out',
    ]);
    if (quantize.exitCode != 0) {
      stderr.writeln('magick 失败：${quantize.stderr}');
      exit(1);
    }
    return File(out).readAsBytesSync();
  } finally {
    temp.deleteSync(recursive: true);
  }
}

String _dataUri(List<int> png) =>
    'data:image/png;base64,${base64Encode(png)}';

// theme=Auto 把明暗两张卡片都塞进同一个 SVG，用 CSS 切换，但两张共用请求里那一份 logo。
// 只把 card-dark 那一段里的换成深色主题那版。
String _swapDarkCardLogo(
  String svg, {
  required String from,
  required String to,
}) {
  const marker = 'class="card-dark"';
  final split = svg.indexOf(marker);
  if (split < 0) {
    stderr.writeln('没找到 $marker，socialify 的输出结构变了');
    exit(1);
  }
  final head = svg.substring(0, split);
  final tail = svg.substring(split);
  if (!tail.contains(from)) {
    stderr.writeln('深色卡片里没有那份 logo，无法替换');
    exit(1);
  }
  return head + tail.replaceAll(from, to);
}
