import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/licenses.dart';

void main() {
  test('第三方许可清单能被 LicenseRegistry 读出来', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerThirdPartyLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    final ours = entries.where(
      (e) => e.packages.any((p) => p.endsWith('(Rust)') || p.endsWith('(npm)')),
    );

    expect(ours, isNotEmpty);
    expect(
      ours.any((e) => e.packages.any((p) => p.endsWith('(Rust)'))),
      isTrue,
      reason: 'Rust crates 没进清单，先跑 dart tool/task.dart licenses',
    );
    expect(
      ours.any((e) => e.packages.any((p) => p.endsWith('(npm)'))),
      isTrue,
      reason: '编辑器 npm 依赖没进清单',
    );
    for (final e in ours) {
      expect(e.paragraphs, isNotEmpty, reason: '${e.packages} 的正文是空的');
    }
  });
}
