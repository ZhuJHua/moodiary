import 'dart:io';

class Pkg {
  final String name;
  final String layer;
  final List<String> internal = [];
  final List<String> thirdParty = [];
  Pkg(this.name, this.layer);
}

const List<String> _layerOrder = [
  'apps',
  'feature',
  'ui',
  'core',
  'foundation',
];

final RegExp _topRe = RegExp(r'^([a-zA-Z0-9_]+):');
final RegExp _entryRe = RegExp(r'^  ([a-zA-Z0-9_]+):');

Pkg _parse(File file, String layer) {
  String? name;
  var section = '';
  final pkg = <String>[];
  final third = <String>[];
  for (final line in file.readAsLinesSync()) {
    final top = _topRe.firstMatch(line);
    if (top != null) {
      section = top.group(1)!;
      if (section == 'name') name = line.split(':')[1].trim();
      continue;
    }
    if (section != 'dependencies') continue;
    final m = _entryRe.firstMatch(line);
    if (m == null) continue;
    final dep = m.group(1)!;
    if (dep == 'flutter' || dep == 'flutter_localizations') continue;
    (dep.startsWith('moodiary_') || dep == 'mui' ? pkg : third).add(dep);
  }
  return Pkg(name!, layer)
    ..internal.addAll(pkg)
    ..thirdParty.addAll(third);
}

Map<String, Pkg> _scan() {
  final files = <File>[
    File('mobile/pubspec.yaml'),
    File('desktop/pubspec.yaml'),
    for (final layerDir in Directory(
      'packages',
    ).listSync().whereType<Directory>())
      for (final pkgDir in layerDir.listSync().whereType<Directory>())
        File('${pkgDir.path}/pubspec.yaml'),
  ];
  final pkgs = <String, Pkg>{};
  for (final f in files) {
    if (!f.existsSync()) continue;
    final path = f.path.replaceAll(r'\', '/');
    final layer = path.startsWith('packages/') ? path.split('/')[1] : 'apps';
    final p = _parse(f, layer);
    pkgs[p.name] = p;
  }
  return pkgs;
}

Map<String, Set<String>> _reach(Map<String, Pkg> pkgs) {
  final memo = <String, Set<String>>{};
  Set<String> go(String n) => memo[n] ??= {
    for (final d in pkgs[n]?.internal ?? const <String>[]) ...{d, ...go(d)},
  };
  pkgs.keys.forEach(go);
  return memo;
}

List<(String, String)> _edges(Map<String, Pkg> pkgs, {required bool reduce}) {
  final reach = _reach(pkgs);
  final edges = <(String, String)>[];
  for (final p in pkgs.values) {
    for (final v in p.internal) {
      if (reduce &&
          p.internal.any((w) => w != v && (reach[w]?.contains(v) ?? false))) {
        continue;
      }
      edges.add((p.name, v));
    }
  }
  return edges;
}

String _mermaid(Map<String, Pkg> pkgs, List<(String, String)> edges) {
  final b = StringBuffer('flowchart TD\n');
  for (final layer in _layerOrder) {
    final members = pkgs.values.where((p) => p.layer == layer).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (members.isEmpty) continue;
    b.writeln('  subgraph $layer');
    b.writeln('    direction LR');
    for (final p in members) {
      b.writeln('    ${p.name}');
    }
    b.writeln('  end');
  }
  for (final (u, v) in edges) {
    b.writeln('  $u --> $v');
  }
  return b.toString();
}

String _dot(Map<String, Pkg> pkgs, List<(String, String)> edges) {
  final b = StringBuffer('digraph moodiary {\n')
    ..writeln('  rankdir=TB;')
    ..writeln('  node [shape=box, fontname="monospace"];');
  for (final layer in _layerOrder) {
    final members = pkgs.values.where((p) => p.layer == layer).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (members.isEmpty) continue;
    b.writeln('  subgraph cluster_$layer {');
    b.writeln('    label="$layer";');
    for (final p in members) {
      b.writeln('    ${p.name};');
    }
    b.writeln('  }');
  }
  for (final (u, v) in edges) {
    b.writeln('  $u -> $v;');
  }
  b.writeln('}');
  return b.toString();
}

String _pubTable(Map<String, Pkg> pkgs, String? only) {
  final byDep = <String, List<String>>{};
  for (final p in pkgs.values) {
    for (final d in p.thirdParty) {
      byDep.putIfAbsent(d, () => []).add(p.name);
    }
  }
  final deps = byDep.keys.where((d) => only == null || d == only).toList()
    ..sort((a, b) {
      final c = byDep[b]!.length.compareTo(byDep[a]!.length);
      return c != 0 ? c : a.compareTo(b);
    });
  if (deps.isEmpty) return only == null ? '（无第三方依赖）\n' : '没有包声明 $only。\n';
  final w = deps.map((d) => d.length).reduce((a, b) => a > b ? a : b);
  final b = StringBuffer();
  for (final d in deps) {
    final owners = byDep[d]!..sort();
    b.writeln(
      '${d.padRight(w)}  ${owners.length.toString().padLeft(2)}  ${owners.join(', ')}',
    );
  }
  return b.toString();
}

void main(List<String> args) {
  if (!Directory('packages').existsSync()) {
    stderr.writeln('找不到 packages/ 目录，请在仓库根目录运行。');
    exit(2);
  }
  final full = args.contains('--full');
  final dot = args.contains('--dot');
  final pub = args.contains('--pub');
  final outIdx = args.indexOf('--out');
  final outFile = outIdx >= 0 && outIdx + 1 < args.length
      ? args[outIdx + 1]
      : null;

  final pkgs = _scan();
  final String output;
  if (pub) {
    final pos = args.where((a) => !a.startsWith('--') && a != outFile).toList();
    output = _pubTable(pkgs, pos.isEmpty ? null : pos.first);
  } else {
    final all = _edges(pkgs, reduce: false);
    final edges = full ? all : _edges(pkgs, reduce: true);
    output = dot ? _dot(pkgs, edges) : _mermaid(pkgs, edges);
    stderr.writeln(
      '${pkgs.length} 个包，${all.length} 条依赖边'
      '${full ? '' : '（传递归约后 ${edges.length} 条，--full 看全部）'}。',
    );
  }
  if (outFile != null) {
    File(outFile).writeAsStringSync(output);
    stderr.writeln('已写入 $outFile');
  } else {
    stdout.write(output);
  }
}
