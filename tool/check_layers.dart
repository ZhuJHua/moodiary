// 分层依赖检查：只能上层依赖下层，同层不互相依赖。
//
// 运行：dart run tool/check_layers.dart            // 检查，存在新增违规则 exit(1)
//      dart run tool/check_layers.dart --update-baseline  // 用当前违规重写 baseline
//
// 规则：每个文件按路径归入一层（见 _layers）。一条 package:moodiary import 合法当且仅当
//   - 目标层严格低于源层，或
//   - 目标与源属于「同一模块」（feature 取到具体 feature 名；其余层取顶层目录名）。
// 跨 feature、或下层引上层，都是违规。tool/layer_baseline.txt 列出的存量违规会被放行。
import 'dart:io';

/// 层级表：index 越小越底层。每层可含多个「模块」（同层不同模块之间禁止互引）。
const List<List<String>> _layers = [
  ['gen', 'l10n'], // 0 生成产物（叶子）
  ['core'], // 1 基础设施
  ['data'], // 2 model + repository
  ['component', 'merge'], // 3 业务无关 UI / 一次性迁移工具
  ['feature'], // 4 各 feature（互为兄弟，禁止互引）
  ['app'], // 5 聚合层：router / shell / di
  ['main.dart'], // 6 入口
];

const String _baselinePath = 'tool/layer_baseline.txt';
final RegExp _importRe = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:moodiary/([^'"]+)['"]''',
  multiLine: true,
);

/// 文件相对 lib/ 的路径 -> (层 index, 模块标识)。模块标识用于同层判定。
({int layer, String module}) _classify(String rel) {
  final parts = rel.split('/');
  final top = parts[0];
  if (top == 'feature') {
    // feature/<name> 为一个模块；feature 内部（含 presentation/application/data）算同模块。
    final name = parts.length > 1 ? parts[1] : '?';
    return (layer: 4, module: 'feature/$name');
  }
  for (var i = 0; i < _layers.length; i++) {
    if (_layers[i].contains(top)) return (layer: i, module: top);
  }
  return (layer: -1, module: top); // 未归类（不应发生）
}

class Violation {
  final String src; // 源文件，相对 lib/
  final String dstModule; // 目标模块标识
  Violation(this.src, this.dstModule);
  String get key => '$src -> $dstModule';
}

void main(List<String> args) {
  final update = args.contains('--update-baseline');
  final libDir = Directory('mobile/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('找不到 mobile/lib/ 目录，请在仓库根目录运行。');
    exit(2);
  }

  final seen = <String>{};
  final violations = <Violation>[];
  var fileCount = 0;

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    fileCount++;
    final rel = entity.path.replaceFirst(RegExp(r'^mobile[/\\]lib[/\\]'), '');
    final srcN = _classify(rel.replaceAll('\\', '/'));
    final content = entity.readAsStringSync();
    for (final m in _importRe.allMatches(content)) {
      final target = m.group(1)!;
      final dstN = _classify(target);
      final bool ok;
      if (dstN.layer < srcN.layer) {
        ok = true; // 依赖更低层
      } else if (dstN.layer == srcN.layer) {
        ok = dstN.module == srcN.module; // 同层只允许同模块
      } else {
        ok = false; // 下层依赖上层
      }
      if (!ok) {
        final v = Violation(rel.replaceAll('\\', '/'), dstN.module);
        if (seen.add(v.key)) violations.add(v);
      }
    }
  }

  final baseline = _readBaseline();

  if (update) {
    final sorted = violations.map((v) => v.key).toList()..sort();
    File(_baselinePath).writeAsStringSync(
      '# 分层依赖检查 baseline（存量违规，逐步清零；只许变短不许变长）。\n'
      '# 由 `dart run tool/check_layers.dart --update-baseline` 生成。\n'
      '# 格式：<相对 lib/ 的源文件> -> <目标模块>\n\n'
      '${sorted.join('\n')}\n',
    );
    stdout.writeln('已写入 ${sorted.length} 条 baseline -> $_baselinePath');
    return;
  }

  final fresh = violations.where((v) => !baseline.contains(v.key)).toList();
  final stale = baseline.where((b) => !violations.any((v) => v.key == b)).toList();

  stdout.writeln(
    '扫描 $fileCount 个文件；违规 ${violations.length} 条'
    '（baseline 放行 ${violations.length - fresh.length}，新增 ${fresh.length}）。',
  );

  if (stale.isNotEmpty) {
    stdout.writeln('\n⚠️  baseline 中已修复（可删除）的陈旧条目 ${stale.length} 条：');
    for (final s in stale..sort()) {
      stdout.writeln('  - $s');
    }
    stdout.writeln('  → 跑 `dart tool/check_layers.dart --update-baseline` 收紧。');
  }

  if (fresh.isEmpty) {
    stdout.writeln('\n✅ 没有新增的分层违规。');
    return;
  }

  stderr.writeln('\n❌ 发现 ${fresh.length} 条新增分层违规（上层才能依赖下层，同层不互引）：');
  for (final v in fresh..sort((a, b) => a.key.compareTo(b.key))) {
    stderr.writeln('  ✗ ${v.key}');
  }
  stderr.writeln(
    '\n如确属合理的临时例外，运行 `dart tool/check_layers.dart --update-baseline` 加入 baseline；'
    '否则请把依赖方向改为「上层依赖下层」。',
  );
  exit(1);
}

Set<String> _readBaseline() {
  final f = File(_baselinePath);
  if (!f.existsSync()) return {};
  return f
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}
