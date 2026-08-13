// 分层依赖检查：只能上层依赖下层，同层不互相依赖。另外三段无 baseline 的主题闸门
// （ThemeData 只在 mui 的 build.dart 里构造 / mui 零 cupertino / 业务代码零色板外颜色）
// 也挂在这里跑。依赖检查本身分三段——
//   1) 包级：各 pubspec 的 moodiary_* 依赖（foundation → core → ui → feature → apps）。
//      pub 只保证依赖图无环、不保证方向，这段补上方向约束。无 baseline，必须零违规。
//   2) Rust crate 级：moodiary_rust/rust/crates 下各 Cargo.toml 的 moodiary-* 依赖
//      （foundation → core → feature → bridge）。同样，cargo 只保证无环、不保证方向。
//   3) 文件级：mobile/lib 内部的 package:moodiary import（见 _layers）。
//
// 运行：dart run tool/check_layers.dart            // 检查，存在新增违规则 exit(1)
//      dart run tool/check_layers.dart --update-baseline  // 用当前文件级违规重写 baseline
//
// 文件级规则：每个文件按路径归入一层。一条 package:moodiary import 合法当且仅当
//   - 目标层严格低于源层，或
//   - 目标与源属于「同一模块」（feature 取到具体 feature 名；其余层取顶层目录名）。
// 跨 feature、或下层引上层，都是违规。tool/layer_baseline.txt 列出的存量违规会被放行。
import 'dart:io';

/// 层级表：index 越小越底层。每层可含多个「模块」（同层不同模块之间禁止互引）。
const List<List<String>> _layers = [
  ['gen', 'l10n'], // 0 生成产物（叶子）
  ['core'], // 1 基础设施
  ['data'], // 2 model + repository
  ['component'], // 3 业务无关 UI
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

/// 包层级：index 越小越底层。apps（mobile/desktop）是顶层聚合。
const Map<String, int> _pkgLayers = {
  'foundation': 0,
  'core': 1,
  'ui': 2,
  'feature': 3,
  'app': 4,
};

/// core 层内部次序（同层允许依赖，但只能单向）。见 CLAUDE.md 的依赖说明。
const Map<String, int> _coreOrder = {
  'moodiary_models': 0,
  'moodiary_core': 1,
  'moodiary_data': 2,
  'moodiary_migration': 2,
  'moodiary_preferences': 3,
};

/// 同层例外白名单：feature 之间唯一保留的边（diary 内嵌编辑器）。
const Set<String> _sameLayerAllowed = {'moodiary_diary -> moodiary_editor'};

final RegExp _pkgDepRe = RegExp(r'^\s{2}(moodiary_[a-z_]+):', multiLine: true);

/// 校验包级依赖方向，返回违规描述（空表示通过）。
List<String> _checkPackageLayers() {
  // 包名 -> 所属层名。
  final layerOf = <String, String>{};
  final depsOf = <String, List<String>>{};

  void collect(String pubspecPath, String layer) {
    final f = File(pubspecPath);
    if (!f.existsSync()) return;
    final text = f.readAsStringSync();
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(text)?.group(1);
    if (name == null) return;
    layerOf[name] = layer;
    // 只看正式依赖；dev_dependencies（lint/test 工具）不参与方向约束。
    final main = text
        .split(RegExp(r'^dev_dependencies:', multiLine: true))
        .first;
    depsOf[name] = _pkgDepRe.allMatches(main).map((m) => m.group(1)!).toList();
  }

  for (final dir in Directory('packages').listSync().whereType<Directory>()) {
    final layer = dir.path.split(Platform.pathSeparator).last;
    if (!_pkgLayers.containsKey(layer)) continue;
    for (final pkg in dir.listSync().whereType<Directory>()) {
      collect('${pkg.path}/pubspec.yaml', layer);
    }
  }
  collect('mobile/pubspec.yaml', 'app');

  final out = <String>[];
  for (final entry in depsOf.entries) {
    final src = entry.key;
    final srcLayer = _pkgLayers[layerOf[src]]!;
    for (final dst in entry.value) {
      final dstLayerName = layerOf[dst];
      if (dstLayerName == null) {
        out.add('$src -> $dst（依赖了不在 workspace 里的 moodiary_* 包）');
        continue;
      }
      final dstLayer = _pkgLayers[dstLayerName]!;
      if (dstLayer < srcLayer) continue;
      if (dstLayer > srcLayer) {
        out.add('$src（${layerOf[src]}）-> $dst（$dstLayerName）：下层依赖上层');
        continue;
      }
      // 同层。
      if (_sameLayerAllowed.contains('$src -> $dst')) continue;
      if (layerOf[src] == 'core') {
        final s = _coreOrder[src], d = _coreOrder[dst];
        if (s != null && d != null && d < s) continue;
        out.add('$src -> $dst：core 层内部次序违规（见 _coreOrder）');
      } else {
        out.add('$src -> $dst：同层互引（${layerOf[src]} 层不允许）');
      }
    }
  }
  out.sort();
  return out;
}

/// Rust crate 层级：index 越小越底层。bridge（moodiary_rust 本体）是顶层聚合。
const Map<String, int> _rustLayers = {'foundation': 0, 'core': 1, 'feature': 2};

const String _rustRoot = 'packages/foundation/moodiary_rust/rust';
final RegExp _cargoDepRe = RegExp(
  r'^\s*(moodiary-[a-z-]+)\s*=',
  multiLine: true,
);

/// 校验 Rust crate 依赖方向，返回违规描述（空表示通过）。
/// bridge crate（rust/Cargo.toml）可以依赖任何层，不参与源侧检查。
List<String> _checkRustLayers() {
  final crates = Directory('$_rustRoot/crates');
  if (!crates.existsSync()) return const [];

  final layerOf = <String, String>{};
  final depsOf = <String, List<String>>{};

  for (final layerDir in crates.listSync().whereType<Directory>()) {
    final layer = layerDir.path.split(Platform.pathSeparator).last;
    if (!_rustLayers.containsKey(layer)) continue;
    for (final crate in layerDir.listSync().whereType<Directory>()) {
      final f = File('${crate.path}/Cargo.toml');
      if (!f.existsSync()) continue;
      final text = f.readAsStringSync();
      final name = RegExp(
        r'^name\s*=\s*"([^"]+)"',
        multiLine: true,
      ).firstMatch(text)?.group(1);
      if (name == null) continue;
      layerOf[name] = layer;
      // dev-dependencies（测试用）不参与方向约束。
      final main = text
          .split(RegExp(r'^\[dev-dependencies\]', multiLine: true))
          .first;
      depsOf[name] = _cargoDepRe
          .allMatches(main)
          .map((m) => m.group(1)!)
          .toList();
    }
  }

  final out = <String>[];
  for (final entry in depsOf.entries) {
    final src = entry.key;
    final srcLayer = _rustLayers[layerOf[src]]!;
    for (final dst in entry.value) {
      final dstLayerName = layerOf[dst];
      if (dstLayerName == null) {
        out.add('$src -> $dst（依赖了不在 crates/ 里的 moodiary-* crate）');
        continue;
      }
      final dstLayer = _rustLayers[dstLayerName]!;
      if (dstLayer < srcLayer) continue;
      if (dstLayer > srcLayer) {
        out.add('$src（${layerOf[src]}）-> $dst（$dstLayerName）：下层依赖上层');
      } else {
        out.add('$src -> $dst：同层互引（${layerOf[src]} 层不允许）');
      }
    }
  }
  out.sort();
  return out;
}

/// mui 的定位已从「替代 material」改成「**补充** material」（2026-08-13）：
/// 配色是 `ColorScheme`、排版是 `TextTheme`，本包不再自建一套，所以 material
/// 不但允许而且是前提。
///
/// 仍然禁 cupertino：全仓零 cupertino import，mui 不该是第一个开口子的地方。
const String _muiRoot = 'packages/foundation/mui/lib';
final RegExp _muiForbiddenRe = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:flutter/(cupertino)\.dart['"]''',
  multiLine: true,
);

List<String> _checkMuiPurity() {
  final dir = Directory(_muiRoot);
  if (!dir.existsSync()) return const [];

  final out = <String>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll('\\', '/');
    final content = entity.readAsStringSync();
    for (final m in _muiForbiddenRe.allMatches(content)) {
      out.add('$rel -> package:flutter/${m.group(1)}.dart');
    }
  }
  out.sort();
  return out;
}

/// 业务代码里的颜色与排版必须来自 mui 色板，不许有第二个来源。零 baseline。
///
/// 五条禁令各自堵一个真实回归：
///   * `Colors.*` —— 色板外的绝对色，深浅色切换时不跟着走；
///   * `Theme.of(context).colorScheme/textTheme` —— 走的是投影而不是真源，
///     且 material 的 `TextTheme` 只带一个颜色，表达不出「弱文字」；
///   * 裸 `TextStyle(` —— 脱离 15 级排版，用户调字号档时不跟着缩放；
///   * `fontWeight:` —— 可变字体下 `fontVariations` 的 wght 轴会吃掉它，
///     写了等于没写（`start_page.dart` 踩过）。字重只能走
///     `.regular/.medium/.semiBold/.bold` 四个 getter；
///   * `Color(0x…)` —— 同第一条。
///
/// 例外是**按文件**放行的，每一条都得有理由；行级 baseline 刻意不做，
/// 那会变成一张只增不减的欠条。
const Map<String, String> _themeAllowlist = {
  'packages/foundation/mui/lib/': 'mui 自己就是色板与 token 的定义处',
  'packages/foundation/mui/lib/src/themes/build.dart':
      '唯一的 material 投影点，按定义要落到绝对值',
  'mobile/lib/app/picker/': '第三方 AssetPicker/CameraPicker 自建 ThemeData，够不着 mui',
  'packages/feature/moodiary_share/lib/src/presentation/templates/':
      '分享卡片是固定设计稿（纸/墨配色），要导出成图片，不能跟随 App 主题',
  'packages/ui/moodiary_ui/lib/src/common/env_badge.dart': '开发环境角标，固定红',
  'packages/ui/moodiary_ui/lib/src/common/video/': '播放器暗房：控件叠在任意画面上，白色前景是对的',
  'packages/ui/moodiary_ui/lib/src/common/image_browser.dart': '图片浏览暗房，同上',
  'packages/core/moodiary_core/lib/src/values/colors.dart':
      '心情色带与分享卡片底色：业务语义色，全 App 唯一刻意不跟主题走的两组',
  'packages/ui/moodiary_ui/lib/src/common/category_color.dart':
      '分类哈希色板 + 由它派生前景色的唯一算处',
  'packages/ui/moodiary_ui/lib/src/common/color_picker.dart': '取色器本体展示的就是任意颜色',
  'packages/ui/moodiary_ui/lib/src/common/file_type_icon.dart':
      'Dosis 角标：字号由轮廓几何反算并钉死 noScaling，不走排版档',
  'packages/ui/moodiary_ui/lib/src/basic/expand_tap_area.dart': 'debugPaint 的辅助色',
  'mobile/lib/app/settings/presentation/widget/accent_sheet.dart':
      '配色档预览：白→黑的色块本身就是要展示的内容',
};

final List<(RegExp, String)> _themeBans = [
  (
    RegExp(r'(^|[^A-Za-z0-9_.])Colors\.(?!transparent)'),
    'Colors.* → context.theme.colors.<角色>',
  ),
  (
    RegExp(r'Theme\.of\([^)]*\)\.(colorScheme|textTheme)'),
    'Theme.of(...).colorScheme/textTheme → context.theme.colors / context.theme.typography',
  ),
  (
    RegExp(r'(^|[^A-Za-z0-9_])TextStyle\s*\('),
    '裸 TextStyle( → context.theme.typography.<级>.<角色>',
  ),
  (
    RegExp(r'fontWeight\s*:'),
    'fontWeight: → 排版角色的 .medium/.semiBold/.bold（可变字体下 fontWeight 会被 fontVariations 吃掉）',
  ),
  // 全透明（0x00……）放行：它不携带任何配色信息，是占位/命中区那类用法。
  (
    RegExp(r'(^|[^A-Za-z0-9_])Color\(0x(?!00)'),
    'Color(0x…) → context.theme.colors.<角色>',
  ),
];

List<String> _checkThemePurity() {
  final out = <String>[];
  for (final root in ['mobile/lib', 'packages']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (!rel.contains('/lib/')) continue;
      if (rel.endsWith('.g.dart') || rel.endsWith('.freezed.dart')) continue;
      if (_themeAllowlist.keys.any(rel.startsWith)) continue;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final (re, hint) in _themeBans) {
          if (re.hasMatch(line)) out.add('$rel:${i + 1}: $hint\n      ${line.trim()}');
        }
      }
    }
  }
  out.sort();
  return out;
}

/// `ThemeData` 只许在桥里构造一次。共存期 material 主题是 [MuiThemeData] 的
/// 只读投影，多一个构造点就多一条绕过真源的路，而配色漂移是最难查的一类 bug。
///
/// 第三方作用域的主题不算（`AssetPicker.themeData(...).copyWith(...)` 之流走的是
/// 那个包自己的构造器，不匹配这条正则）。
const String _themeDataBridge =
    'packages/foundation/mui/lib/src/themes/build.dart';
final RegExp _themeDataRe = RegExp(r'(^|[^A-Za-z0-9_])ThemeData\s*\(');

List<String> _checkThemeDataConstruction() {
  final out = <String>[];
  for (final root in ['mobile/lib', 'packages']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (!rel.contains('/lib/') || rel == _themeDataBridge) continue;
      final content = entity.readAsStringSync();
      for (final line in content.split('\n')) {
        // 只看构造调用，跳过类型标注与返回类型（`ThemeData foo(` 不匹配）。
        if (_themeDataRe.hasMatch(line) && !line.contains('ThemeData(),')) {
          out.add('$rel: ${line.trim()}');
        }
      }
    }
  }
  out.sort();
  return out;
}

void main(List<String> args) {
  final update = args.contains('--update-baseline');
  final themeViolations = _checkThemeDataConstruction();
  if (themeViolations.isEmpty) {
    stdout.writeln('✅ ThemeData 只在 mui 的 buildMuiTheme 里构造。');
  } else {
    stderr.writeln('❌ 桥之外出现了 ${themeViolations.length} 处 ThemeData 构造：');
    for (final v in themeViolations) {
      stderr.writeln('  ✗ $v');
    }
    stderr.writeln('  → material 主题必须由 materialThemeFrom(MuiThemeData) 单向投影。');
    exit(1);
  }

  final themePurity = _checkThemePurity();
  if (themePurity.isEmpty) {
    stdout.writeln('✅ 业务代码的颜色与排版都来自主题。');
  } else {
    stderr.writeln('❌ 色板外的颜色/排版 ${themePurity.length} 处：');
    for (final v in themePurity) {
      stderr.writeln('  ✗ $v');
    }
    stderr.writeln('  → 见 _themeBans；确属固定设计稿的整文件例外加进 _themeAllowlist 并写明理由。');
    exit(1);
  }

  final muiViolations = _checkMuiPurity();
  if (muiViolations.isEmpty) {
    stdout.writeln('✅ mui 零 cupertino import。');
  } else {
    stderr.writeln('❌ mui 引入了 material/cupertino ${muiViolations.length} 处：');
    for (final v in muiViolations) {
      stderr.writeln('  ✗ $v');
    }
    stderr.writeln('  → mui 可以用 material，但不许碰 cupertino。');
    exit(1);
  }

  final pkgViolations = _checkPackageLayers();
  if (pkgViolations.isEmpty) {
    stdout.writeln('✅ 包级依赖方向检查通过。');
  } else {
    stderr.writeln('❌ 包级依赖方向违规 ${pkgViolations.length} 条：');
    for (final v in pkgViolations) {
      stderr.writeln('  ✗ $v');
    }
    if (!update) exit(1);
  }

  final rustViolations = _checkRustLayers();
  if (rustViolations.isEmpty) {
    stdout.writeln('✅ Rust crate 依赖方向检查通过。');
  } else {
    stderr.writeln('❌ Rust crate 依赖方向违规 ${rustViolations.length} 条：');
    for (final v in rustViolations) {
      stderr.writeln('  ✗ $v');
    }
    if (!update) exit(1);
  }

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
  final stale = baseline
      .where((b) => !violations.any((v) => v.key == b))
      .toList();

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
