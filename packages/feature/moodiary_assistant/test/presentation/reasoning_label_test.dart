import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/reasoning_label.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  setUpAll(() => LocaleSettings.setLocale(AppLocale.zh));

  test('已知档位映射成中文', () {
    expect(reasoningLevelLabel('low', l10n), '低');
    expect(reasoningLevelLabel('max', l10n), '最高');
    expect(reasoningLevelLabel(reasoningOffValue, l10n), '不思考');
  });

  test('目录里冒出新档位时显示原值，而不是消失', () {
    expect(reasoningLevelLabel('xhigh', l10n), 'xhigh');
    expect(reasoningLevelLabel('ultra', l10n), 'ultra');
  });
}
