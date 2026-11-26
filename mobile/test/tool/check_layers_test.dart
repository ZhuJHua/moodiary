import 'package:flutter_test/flutter_test.dart';

import '../../../tool/check_layers.dart' as layers;

void main() {
  test('manual containers are production violations, not comment matches', () {
    final violations = layers.findManualRootContainerInDart(
      '  // ProviderContainer(\n/// UncontrolledProviderScope(\n'
          'ProviderContainer.test();\nMyProviderContainer();\n'
          'final root = ProviderContainer ();\nreturn UncontrolledProviderScope\n(\n'
          'final tearOff = ProviderContainer.new;\n'
          'final scopeTearOff = UncontrolledProviderScope.new;\n',
      'source',
    );
    expect(violations, [
      'source:5: ProviderContainer',
      'source:6: UncontrolledProviderScope',
      'source:8: ProviderContainer',
      'source:9: UncontrolledProviderScope',
    ]);
  });

  test('commented package URIs do not count as Dart dependency usage', () {
    expect(
      layers.referencedDartPkgsInSource(
        "// import 'package:commented_only/a.dart';\n"
        "/// See package:doc_only/b.dart\n"
        "import 'package:real_import/c.dart';\n"
        "export 'package:real_export/d.dart';\n",
      ),
      {'real_import', 'real_export'},
    );
  });

  test('production and development have different dependency consumers', () {
    const names = {
      'lib_pkg',
      'test_pkg',
      'hook_pkg',
      'lint_pkg',
      'moodiary_data',
      'unused_pkg',
    };
    final spec = [
      for (final section in [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
      ]) ...[
        '$section:',
        for (final name in {...names, 'external'}) '  $name: any',
      ],
    ].join('\n');
    expect(
      layers.findUnusedWorkspaceDeps(
        pkgName: 'root',
        pubspecContent: spec,
        workspacePackages: names,
        libReferencedPkgs: {'lib_pkg'},
        testReferencedPkgs: {'test_pkg'},
        hookReferencedPkgs: {'hook_pkg'},
        analysisOptionPkgs: {'lint_pkg'},
        allowedDevDeps: {'moodiary_data'},
      ),
      [
        'root: unused dependencies: test_pkg',
        'root: unused dependencies: moodiary_data',
        'root: unused dependencies: unused_pkg',
        'root: unused dev_dependencies: unused_pkg',
      ],
    );
  });

  test('generated DI parts belong to their owning app module', () {
    for (final (name, layer) in [('bootstrap', 0), ('app_startup', 5)]) {
      for (final suffix in ['.dart', '.g.dart']) {
        expect(layers.classifyAppFile('app/di/$name$suffix'), (
          layer: layer,
          module: 'app/di/$name',
        ));
      }
    }
  });

  test('app imports may go down or stay within their module', () {
    for (final (source, target, module) in [
      ('app/home/a.dart', 'app/settings/b.dart', 'app/settings'),
      ('app/router/router.dart', 'main.dart', 'main.dart'),
      ('app/media/a.dart', 'app/home/b.dart', 'app/home'),
    ]) {
      expect(
        layers.checkAppImport(source, target).single.key,
        '$source -> $module',
      );
    }
    expect(
      layers.checkAppImport('app/home/a.dart', 'app/media/b.dart'),
      isEmpty,
    );
    expect(
      layers.checkAppImport('app/settings/a.dart', 'app/settings/sub/b.dart'),
      isEmpty,
    );
  });

  test(
    'app import scanner resolves relative imports as well as package URIs',
    () {
      final targets = layers
          .appImportTargets(
            'app/home/diary_home_page.dart',
            "import 'dart:async';\n"
                "import 'package:mui/mui.dart';\n"
                "import '../settings/setting_routes.dart';\n"
                "export 'package:moodiary_mobile/app/locale.dart';\n",
            'moodiary_mobile',
          )
          .toList();
      expect(targets, ['app/settings/setting_routes.dart', 'app/locale.dart']);
      expect(
        layers
            .checkAppImport('app/home/diary_home_page.dart', targets.first)
            .single
            .key,
        'app/home/diary_home_page.dart -> app/settings',
      );
    },
  );
}
