# 离线天气与定位改造 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除编辑日记时对和风天气 API 的依赖：天气改用内置 14 项预设 + 双滚轮底部弹层手选；地点改用系统级 `geocoding` 反查并以经纬度兜底。

**Architecture:** 保持 `Diary.weather`/`Diary.position` 字段格式不变（向后兼容旧数据）。新增独立的 `weather_presets`、`weather_picker_sheet`、`geo_format_util` 三个文件作为可独立测试的小单元。重写 `Api.updatePosition()` 与 `EditLogic.getPositionAndWeather()` 串联整个新流程。

**Tech Stack:** Flutter (Dart 3.8+), GetX 状态管理, `geolocator` (已在项目中), `geocoding` ^3.0.0 (新增), `CupertinoPicker` (Flutter 自带), `intl_*.arb` + `flutter gen-l10n`。

**Spec:** `docs/superpowers/specs/2026-05-16-offline-weather-location-design.md`

---

## 文件结构

| 路径 | 操作 | 责任 |
|---|---|---|
| `pubspec.yaml` | 改 | 新增 `geocoding: ^3.0.0` 依赖 |
| `lib/l10n/intl_zh.arb` | 改 | 新增 17 个 i18n key（14 个天气名 + 3 个弹层文案） |
| `lib/l10n/intl_en.arb` | 改 | 同上，英文 |
| `lib/l10n/app_localizations*.dart` | 自动重生 | `flutter gen-l10n` 输出 |
| `lib/common/values/weather_presets.dart` | **新建** | `WeatherPreset` 类 + `kWeatherPresets` 14 项常量 + `WeatherPresetL10n` 扩展 |
| `lib/utils/geo_format_util.dart` | **新建** | `formatCoords()` 和 `composePlacemark()` 纯函数（独立可测） |
| `lib/components/weather_picker_sheet.dart` | **新建** | `showWeatherPickerSheet()` + 内部 StatefulWidget（双 CupertinoPicker） |
| `lib/api/api.dart` | 改 | 重写 `updatePosition`（用 geocoding + 兜底）；删除 `updateWeather`；清理 import |
| `lib/pages/edit/edit_logic.dart` | 改 | 重写 `getPositionAndWeather`（并行启动定位 future + 弹层 + 合并写入） |
| `test/weather_presets_test.dart` | **新建** | 预设长度、code 与图标字体覆盖、l10n 命中 |
| `test/geo_format_util_test.dart` | **新建** | `formatCoords` 和 `composePlacemark` 各分支 |
| `lib/pages/edit/edit_view.dart` | **不动** | 触发逻辑不变 |
| `lib/persistence/pref.dart` | **不动** | qweather 配置项保留为死配置 |
| `lib/pages/diary_setting/*` | **不动** | qweather 设置 UI 保留 |

---

## Task 1: 添加 `geocoding` 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 dependencies 块加入 `geocoding`**

打开 `pubspec.yaml`，找到 `geolocator: 14.0.0`（约第 38 行），在它下面新增一行：

```yaml
  geolocator: 14.0.0
  geocoding: ^3.0.0
```

- [ ] **Step 2: 拉依赖**

```bash
cd D:/Code/Loong-s-Diary
flutter pub get
```

预期：输出末尾出现 `Got dependencies!` 或类似提示，无报错。

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add geocoding dependency for offline location reverse-lookup"
```

---

## Task 2: 新增 i18n key（中/英）并重新生成

**Files:**
- Modify: `lib/l10n/intl_zh.arb`
- Modify: `lib/l10n/intl_en.arb`
- Auto-regenerate: `lib/l10n/app_localizations*.dart`

- [ ] **Step 1: 在 `intl_zh.arb` 末尾（最后一个 key 后、`}` 前）插入 17 个 key**

```json
,
  "weatherSunny": "晴",
  "weatherCloudy": "多云",
  "weatherOvercast": "阴",
  "weatherShowerRain": "阵雨",
  "weatherLightRain": "小雨",
  "weatherModerateRain": "中雨",
  "weatherHeavyRain": "大雨",
  "weatherThunder": "雷阵雨",
  "weatherLightSnow": "小雪",
  "weatherModerateSnow": "中雪",
  "weatherHeavySnow": "大雪",
  "weatherFog": "雾",
  "weatherHaze": "霾",
  "weatherSandstorm": "沙尘暴",
  "weatherPickerTitle": "选择天气",
  "weatherPickerConfirm": "确认",
  "weatherPickerCancel": "取消"
```

注意：插入到现有最后一个 key 之后，记得首字符是 `,`，并在最后一个新 key 后没有逗号；外层 `}` 保持原样。

- [ ] **Step 2: 在 `intl_en.arb` 同样位置插入对应英文**

```json
,
  "weatherSunny": "Sunny",
  "weatherCloudy": "Cloudy",
  "weatherOvercast": "Overcast",
  "weatherShowerRain": "Shower Rain",
  "weatherLightRain": "Light Rain",
  "weatherModerateRain": "Moderate Rain",
  "weatherHeavyRain": "Heavy Rain",
  "weatherThunder": "Thundershower",
  "weatherLightSnow": "Light Snow",
  "weatherModerateSnow": "Moderate Snow",
  "weatherHeavySnow": "Heavy Snow",
  "weatherFog": "Foggy",
  "weatherHaze": "Haze",
  "weatherSandstorm": "Sandstorm",
  "weatherPickerTitle": "Pick Weather",
  "weatherPickerConfirm": "Confirm",
  "weatherPickerCancel": "Cancel"
```

- [ ] **Step 3: 重新生成 l10n 代码**

```bash
flutter gen-l10n
```

预期：无报错。`lib/l10n/app_localizations.dart`、`app_localizations_zh.dart`、`app_localizations_en.dart` 应自动更新出 `String get weatherSunny` 等 getter。

- [ ] **Step 4: 验证生成结果**

```bash
grep -n "weatherSunny\|weatherPickerConfirm" "lib/l10n/app_localizations.dart" "lib/l10n/app_localizations_zh.dart" "lib/l10n/app_localizations_en.dart"
```

预期：每个文件都至少各打一行匹配。

- [ ] **Step 5: 提交**

```bash
git add lib/l10n/intl_zh.arb lib/l10n/intl_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart
git commit -m "i18n: add weather preset names and picker sheet labels"
```

---

## Task 3: 新建 `WeatherPreset` 模型 + 预设表（先写测试）

**Files:**
- Create: `lib/common/values/weather_presets.dart`
- Create: `test/weather_presets_test.dart`

- [ ] **Step 1: 写失败测试 — `test/weather_presets_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/common/values/weather_presets.dart';

void main() {
  group('kWeatherPresets', () {
    test('contains exactly 14 presets', () {
      expect(kWeatherPresets.length, 14);
    });

    test('every preset code exists in WeatherIcon.map', () {
      for (final preset in kWeatherPresets) {
        expect(
          WeatherIcon.map.containsKey(preset.code),
          true,
          reason: 'preset code ${preset.code} (${preset.nameKey}) '
              'is missing from WeatherIcon.map',
        );
      }
    });

    test('every preset has a non-empty nameKey', () {
      for (final preset in kWeatherPresets) {
        expect(preset.nameKey.isNotEmpty, true);
      }
    });

    test('preset codes are unique', () {
      final codes = kWeatherPresets.map((p) => p.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/weather_presets_test.dart
```

预期：编译错误 `Target of URI doesn't exist: 'package:moodiary/common/values/weather_presets.dart'`。

- [ ] **Step 3: 写最小实现 — `lib/common/values/weather_presets.dart`**

```dart
class WeatherPreset {
  final String code;
  final String nameKey;
  const WeatherPreset(this.code, this.nameKey);
}

const kWeatherPresets = <WeatherPreset>[
  WeatherPreset('100', 'weatherSunny'),
  WeatherPreset('101', 'weatherCloudy'),
  WeatherPreset('104', 'weatherOvercast'),
  WeatherPreset('300', 'weatherShowerRain'),
  WeatherPreset('305', 'weatherLightRain'),
  WeatherPreset('306', 'weatherModerateRain'),
  WeatherPreset('307', 'weatherHeavyRain'),
  WeatherPreset('302', 'weatherThunder'),
  WeatherPreset('400', 'weatherLightSnow'),
  WeatherPreset('401', 'weatherModerateSnow'),
  WeatherPreset('402', 'weatherHeavySnow'),
  WeatherPreset('501', 'weatherFog'),
  WeatherPreset('502', 'weatherHaze'),
  WeatherPreset('507', 'weatherSandstorm'),
];
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/weather_presets_test.dart
```

预期：4 个 test 全 PASS。如果 `every preset code exists in WeatherIcon.map` 失败，看错误里报的 code，到 `lib/common/values/icons.dart` 里确认 qweather 字体里实际有哪个，必要时换一个等效的 code（比如 `300` 没有就换 `301`）。

- [ ] **Step 5: 提交**

```bash
git add lib/common/values/weather_presets.dart test/weather_presets_test.dart
git commit -m "feat: add WeatherPreset model and 14 built-in presets"
```

---

## Task 4: 添加 `WeatherPresetL10n` 扩展（label 解析）

**Files:**
- Modify: `lib/common/values/weather_presets.dart`
- Modify: `test/weather_presets_test.dart`

- [ ] **Step 1: 追加测试 — `test/weather_presets_test.dart` 末尾**

在 `void main()` 的最后一个 group 后面（仍在 `main()` 内），追加：

```dart
  testWidgets('WeatherPresetL10n.label resolves every nameKey to a non-key string',
      (tester) async {
    await tester.pumpWidget(const _LabelHarness());
    final BuildContext context = tester.element(find.byType(SizedBox));

    for (final preset in kWeatherPresets) {
      final label = preset.label(context);
      expect(label.isNotEmpty, true,
          reason: '${preset.nameKey} returned empty label');
      expect(label, isNot(equals(preset.nameKey)),
          reason: '${preset.nameKey} fell through to default branch');
    }
  });
}

class _LabelHarness extends StatelessWidget {
  const _LabelHarness();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: SizedBox(),
    );
  }
}
```

并在文件顶部添加 import：

```dart
import 'package:flutter/material.dart';
import 'package:moodiary/l10n/app_localizations.dart';
```

注意：原本闭合 `main()` 的 `}` 移到这个 testWidgets 块之后。

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/weather_presets_test.dart
```

预期：编译错误 — 找不到 `label` 方法。

- [ ] **Step 3: 在 `lib/common/values/weather_presets.dart` 末尾追加扩展**

文件顶部加 import：

```dart
import 'package:flutter/material.dart';
import 'package:moodiary/l10n/l10n.dart';
```

文件末尾加：

```dart
extension WeatherPresetL10n on WeatherPreset {
  String label(BuildContext c) => switch (nameKey) {
        'weatherSunny' => c.l10n.weatherSunny,
        'weatherCloudy' => c.l10n.weatherCloudy,
        'weatherOvercast' => c.l10n.weatherOvercast,
        'weatherShowerRain' => c.l10n.weatherShowerRain,
        'weatherLightRain' => c.l10n.weatherLightRain,
        'weatherModerateRain' => c.l10n.weatherModerateRain,
        'weatherHeavyRain' => c.l10n.weatherHeavyRain,
        'weatherThunder' => c.l10n.weatherThunder,
        'weatherLightSnow' => c.l10n.weatherLightSnow,
        'weatherModerateSnow' => c.l10n.weatherModerateSnow,
        'weatherHeavySnow' => c.l10n.weatherHeavySnow,
        'weatherFog' => c.l10n.weatherFog,
        'weatherHaze' => c.l10n.weatherHaze,
        'weatherSandstorm' => c.l10n.weatherSandstorm,
        _ => nameKey,
      };
}
```

`l10n.dart` 提供 `BuildContext.l10n` 扩展（项目已有，可在 `grep -n "extension.*on BuildContext" lib/l10n/l10n.dart` 验证）。

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/weather_presets_test.dart
```

预期：所有 5 个测试 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/common/values/weather_presets.dart test/weather_presets_test.dart
git commit -m "feat: add WeatherPresetL10n extension for localized labels"
```

---

## Task 5: 新建 `geo_format_util.dart`（坐标格式化 + placemark 拼装）

**Files:**
- Create: `lib/utils/geo_format_util.dart`
- Create: `test/geo_format_util_test.dart`

- [ ] **Step 1: 写失败测试 — `test/geo_format_util_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:moodiary/utils/geo_format_util.dart';

Placemark _pm({
  String? country,
  String? administrativeArea,
  String? locality,
  String? subLocality,
}) {
  return Placemark(
    name: '',
    street: '',
    isoCountryCode: '',
    country: country ?? '',
    postalCode: '',
    administrativeArea: administrativeArea ?? '',
    subAdministrativeArea: '',
    locality: locality ?? '',
    subLocality: subLocality ?? '',
    thoroughfare: '',
    subThoroughfare: '',
  );
}

void main() {
  group('formatCoords', () {
    test('positive lat/lng → N, E', () {
      expect(formatCoords(31.234, 121.473), '31.23°N, 121.47°E');
    });
    test('negative lat/lng → S, W', () {
      expect(formatCoords(-23.5, -46.6), '23.50°S, 46.60°W');
    });
    test('zero → 0.00°N, 0.00°E', () {
      expect(formatCoords(0, 0), '0.00°N, 0.00°E');
    });
  });

  group('composePlacemark (Asian locale)', () {
    const zh = Locale('zh');

    test('full fields → admin + locality + subLocality joined by space', () {
      final p = _pm(
        country: '中国',
        administrativeArea: '上海市',
        locality: '上海市',
        subLocality: '浦东新区',
      );
      expect(composePlacemark(p, zh), '上海市 上海市 浦东新区');
    });

    test('missing subLocality → admin + locality only', () {
      final p = _pm(
        country: '中国',
        administrativeArea: '北京市',
        locality: '北京市',
      );
      expect(composePlacemark(p, zh), '北京市 北京市');
    });

    test('only country → returns country', () {
      final p = _pm(country: '中国');
      expect(composePlacemark(p, zh), '中国');
    });

    test('all empty → null', () {
      final p = _pm();
      expect(composePlacemark(p, zh), null);
    });
  });

  group('composePlacemark (non-Asian locale)', () {
    const en = Locale('en');

    test('locality + country → "City, Country"', () {
      final p = _pm(
        country: 'China',
        administrativeArea: 'Shanghai',
        locality: 'Shanghai',
      );
      expect(composePlacemark(p, en), 'Shanghai, China');
    });

    test('only admin + country → "Admin, Country"', () {
      final p = _pm(country: 'China', administrativeArea: 'Shanghai');
      expect(composePlacemark(p, en), 'Shanghai, China');
    });

    test('only country → returns country', () {
      final p = _pm(country: 'China');
      expect(composePlacemark(p, en), 'China');
    });

    test('all empty → null', () {
      final p = _pm();
      expect(composePlacemark(p, en), null);
    });
  });

  test('null locale falls back to non-Asian rules', () {
    final p = _pm(country: 'China', locality: 'Shanghai');
    expect(composePlacemark(p, null), 'Shanghai, China');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/geo_format_util_test.dart
```

预期：编译错误，`geo_format_util.dart` 不存在。

- [ ] **Step 3: 写实现 — `lib/utils/geo_format_util.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

String formatCoords(double lat, double lng) {
  final ns = lat >= 0 ? 'N' : 'S';
  final ew = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(2)}°$ns, '
      '${lng.abs().toStringAsFixed(2)}°$ew';
}

String? composePlacemark(Placemark p, Locale? locale) {
  bool ne(String? s) => s != null && s.isNotEmpty;

  final isAsian = locale != null &&
      const {'zh', 'ja', 'ko'}.contains(locale.languageCode);

  if (isAsian) {
    final parts = <String>[
      if (ne(p.administrativeArea)) p.administrativeArea!,
      if (ne(p.locality)) p.locality!,
      if (ne(p.subLocality)) p.subLocality!,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return ne(p.country) ? p.country : null;
  }

  if (ne(p.locality) && ne(p.country)) return '${p.locality}, ${p.country}';
  if (ne(p.administrativeArea) && ne(p.country)) {
    return '${p.administrativeArea}, ${p.country}';
  }
  return ne(p.country) ? p.country : null;
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/geo_format_util_test.dart
```

预期：所有 11 个 test PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/utils/geo_format_util.dart test/geo_format_util_test.dart
git commit -m "feat: add geo_format_util for coordinate formatting and placemark composition"
```

---

## Task 6: 重写 `Api.updatePosition`（用 geocoding + 兜底）

**Files:**
- Modify: `lib/api/api.dart`

- [ ] **Step 1: 调整 import**

打开 `lib/api/api.dart`，在 import 块中：
- 删除：`import 'package:moodiary/common/models/geo.dart';`（若 grep 确认仅 `updatePosition` 在用）
- 删除：`import 'package:latlong2/latlong.dart';`（若 grep 确认仅 `updateWeather` 在用 — 该方法将在 Task 7 删除）
- 新增：`import 'package:geocoding/geocoding.dart';`
- 新增：`import 'package:moodiary/utils/geo_format_util.dart';`

先用以下命令查清这两个 import 是否真的只在 `updatePosition` / `updateWeather` 内被引用：

```bash
grep -n "GeoResponse\|LatLng\b" lib/api/api.dart
```

如果除上述方法外还有调用，则保留对应 import。

- [ ] **Step 2: 用新版替换 `updatePosition` 方法体**

定位到 `static Future<List<String>?> updatePosition(BuildContext context) async {`（约第 69 行），把整个方法（到对应 `}` 为止，约第 120 行）替换为：

```dart
  static Future<List<String>?> updatePosition(BuildContext context) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && context.mounted) {
        toast.info(message: context.l10n.noticeEnableLocation);
        return null;
      }
      if (permission == LocationPermission.deniedForever && context.mounted) {
        toast.info(message: context.l10n.noticeEnableLocation2);
        return null;
      }
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    Position? position = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: true,
    );
    try {
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const AndroidSettings(
          forceLocationManager: true,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      return null;
    }
    if (position == null) return null;

    String displayName = formatCoords(position.latitude, position.longitude);
    try {
      final local = context.mounted ? Localizations.localeOf(context) : null;
      if (local != null) {
        await setLocaleIdentifier(local.toLanguageTag());
      }
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 4));
      if (placemarks.isNotEmpty) {
        displayName = composePlacemark(placemarks.first, local) ?? displayName;
      }
    } catch (_) {
      // 静默兜底为经纬度
    }

    return [
      position.latitude.toString(),
      position.longitude.toString(),
      displayName,
    ];
  }
```

- [ ] **Step 3: 编译检查**

```bash
flutter analyze lib/api/api.dart
```

预期：无 error；可能有 `unused_import` 提示 weather/geo model 仍未清理 — Task 7 一起处理。

- [ ] **Step 4: 提交**

```bash
git add lib/api/api.dart
git commit -m "refactor(api): rewrite updatePosition to use geocoding plugin with coordinate fallback"
```

---

## Task 7: 删除 `Api.updateWeather` 并清理无用 import

**Files:**
- Modify: `lib/api/api.dart`

- [ ] **Step 1: 删除 `updateWeather` 方法**

定位到 `static Future<List<String>?> updateWeather({` （约第 122 行），删除整个方法体（到下一个方法 `getGithubRelease` 之前的 `}`）。

- [ ] **Step 2: 清理无用 import**

跑 grep 复查现在还需要哪些之前的 import：

```bash
grep -n "Localizations\|HttpUtil\|PrefUtil\|WeatherResponse\|GeoResponse\|LatLng\|signature\|Hunyuan\|HitokotoResponse\|BingImage\|GithubRelease" lib/api/api.dart
```

按结果删除任何不再被使用的 import 行：
- 若无 `WeatherResponse` 引用 → 删 `import 'package:moodiary/common/models/weather.dart';`
- 若无 `GeoResponse` 引用 → 删 `import 'package:moodiary/common/models/geo.dart';`
- 若无 `LatLng` 引用 → 删 `import 'package:latlong2/latlong.dart';`
- 若无 `PrefUtil` 引用 → 删 `import 'package:moodiary/persistence/pref.dart';`

注意：`HttpUtil`、`Hunyuan`、`HitokotoResponse`、`BingImage`、`GithubRelease`、`signature` 等其它方法仍在用，保留对应 import。

- [ ] **Step 3: 编译检查**

```bash
flutter analyze lib/api/api.dart
```

预期：无 error，无 unused_import warning。

- [ ] **Step 4: 提交**

```bash
git add lib/api/api.dart
git commit -m "refactor(api): remove updateWeather and clean unused imports"
```

---

## Task 8: 新建 `weather_picker_sheet.dart`

**Files:**
- Create: `lib/components/weather_picker_sheet.dart`

- [ ] **Step 1: 写实现**

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/common/values/weather_presets.dart';
import 'package:moodiary/l10n/l10n.dart';

typedef WeatherPickerResult = ({WeatherPreset preset, int temp});

const int _kTempMin = -30;
const int _kTempMax = 50;
const double _kItemExtent = 36;

Future<WeatherPickerResult?> showWeatherPickerSheet({
  required BuildContext context,
  required WeatherPreset initialPreset,
  required int initialTemp,
}) {
  return showModalBottomSheet<WeatherPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => _WeatherPickerSheet(
      initialPreset: initialPreset,
      initialTemp: initialTemp,
    ),
  );
}

class _WeatherPickerSheet extends StatefulWidget {
  const _WeatherPickerSheet({
    required this.initialPreset,
    required this.initialTemp,
  });

  final WeatherPreset initialPreset;
  final int initialTemp;

  @override
  State<_WeatherPickerSheet> createState() => _WeatherPickerSheetState();
}

class _WeatherPickerSheetState extends State<_WeatherPickerSheet> {
  late int _presetIndex;
  late int _tempIndex;
  late final FixedExtentScrollController _presetCtrl;
  late final FixedExtentScrollController _tempCtrl;

  @override
  void initState() {
    super.initState();
    _presetIndex = kWeatherPresets
        .indexWhere((p) => p.code == widget.initialPreset.code);
    if (_presetIndex < 0) _presetIndex = 0;
    final clampedTemp = widget.initialTemp.clamp(_kTempMin, _kTempMax);
    _tempIndex = clampedTemp - _kTempMin;
    _presetCtrl = FixedExtentScrollController(initialItem: _presetIndex);
    _tempCtrl = FixedExtentScrollController(initialItem: _tempIndex);
  }

  @override
  void dispose() {
    _presetCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    Navigator.of(context).pop<WeatherPickerResult>((
      preset: kWeatherPresets[_presetIndex],
      temp: _kTempMin + _tempIndex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: 320,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.weatherPickerCancel),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.weatherPickerTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _onConfirm,
                    child: Text(l10n.weatherPickerConfirm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _presetCtrl,
                      itemExtent: _kItemExtent,
                      onSelectedItemChanged: (i) =>
                          setState(() => _presetIndex = i),
                      children: [
                        for (final p in kWeatherPresets)
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(WeatherIcon.map[p.code], size: 22),
                                const SizedBox(width: 8),
                                Text(p.label(context)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _tempCtrl,
                      itemExtent: _kItemExtent,
                      onSelectedItemChanged: (i) =>
                          setState(() => _tempIndex = i),
                      children: [
                        for (int t = _kTempMin; t <= _kTempMax; t++)
                          Center(child: Text('$t °C')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 编译检查**

```bash
flutter analyze lib/components/weather_picker_sheet.dart
```

预期：无 error。

- [ ] **Step 3: 提交**

```bash
git add lib/components/weather_picker_sheet.dart
git commit -m "feat: add weather picker bottom sheet with dual CupertinoPicker"
```

---

## Task 9: 重写 `EditLogic.getPositionAndWeather`

**Files:**
- Modify: `lib/pages/edit/edit_logic.dart`

- [ ] **Step 1: 调整 import**

在 `lib/pages/edit/edit_logic.dart` 顶部 import 区，新增：

```dart
import 'package:moodiary/common/values/weather_presets.dart';
import 'package:moodiary/components/weather_picker_sheet.dart';
```

如果文件原先 `import 'package:latlong2/latlong.dart';` 仅用于 `getPositionAndWeather` 内的 `LatLng(...)`，删除它（grep 整个文件确认无其它用法）：

```bash
grep -n "LatLng\b" lib/pages/edit/edit_logic.dart
```

- [ ] **Step 2: 用新版替换 `getPositionAndWeather` 方法**

定位到 `Future<void> getPositionAndWeather({required BuildContext context}) async {`（约第 542 行），整段（到 `_handleError` 之前的 `}`）替换为：

```dart
  Future<void> getPositionAndWeather({required BuildContext context}) async {
    state.isProcessing = true;
    update(['Weather']);

    final positionFuture = Api.updatePosition(context);
    final initialPreset = _resolveCurrentPreset();
    final initialTemp = _resolveCurrentTemp();

    if (!context.mounted) return;
    final result = await showWeatherPickerSheet(
      context: context,
      initialPreset: initialPreset,
      initialTemp: initialTemp,
    );

    if (result == null) {
      state.isProcessing = false;
      update(['Weather']);
      // positionFuture 仍会在后台完成，但其结果被忽略
      return;
    }

    if (!context.mounted) return;
    state.currentDiary.weather = [
      result.preset.code,
      result.temp.toString(),
      result.preset.label(context),
    ];

    try {
      final position = await positionFuture;
      if (position != null) state.currentDiary.position = position;
    } catch (_) {
      // 定位失败已在 Api.updatePosition 内 toast
    }

    state.isProcessing = false;
    update(['Weather']);
    if (context.mounted) {
      toast.success(message: context.l10n.weatherSuccess);
    }
  }

  WeatherPreset _resolveCurrentPreset() {
    final w = state.currentDiary.weather;
    if (w.isNotEmpty) {
      final code = w[0];
      for (final p in kWeatherPresets) {
        if (p.code == code) return p;
      }
    }
    return kWeatherPresets.first;
  }

  int _resolveCurrentTemp() {
    final w = state.currentDiary.weather;
    if (w.length >= 2) {
      final parsed = int.tryParse(w[1]);
      if (parsed != null) return parsed;
    }
    return 20;
  }
```

注意：`_handleError` 方法不再被调用，可以一并删除（紧接在新方法下方的 `void _handleError(...)`）。但**不要**删除其它仍在用的辅助方法 — `grep -n "_handleError" lib/pages/edit/edit_logic.dart` 应只剩定义本身，无其它引用，可安全删。

- [ ] **Step 3: 编译检查**

```bash
flutter analyze lib/pages/edit/edit_logic.dart
```

预期：无 error，无 unused_import warning。

- [ ] **Step 4: 提交**

```bash
git add lib/pages/edit/edit_logic.dart
git commit -m "refactor(edit): rewrite getPositionAndWeather to use offline weather picker"
```

---

## Task 10: 全量 analyze + 跑全部测试

**Files:** 无新增

- [ ] **Step 1: 全工程 analyze**

```bash
flutter analyze
```

预期：保持原有警告水平（即比对 Task 1 之前的 `flutter analyze` 输出，新增的代码不引入新 error/warning）。如有，按提示修。

- [ ] **Step 2: 跑全部 test**

```bash
flutter test
```

预期：原有 `lru_test`、`task_scheduler_test` 仍通过，新增 `weather_presets_test`（5 个）、`geo_format_util_test`（11 个）全部 PASS。

- [ ] **Step 3: 如发现问题修复后重测**

修复 → 再跑一遍 → 通过后 `git commit -m "fix: <具体修复说明>"`。如无问题跳过此步。

---

## Task 11: Android 真机手动验证（按规格 6 项）

**Files:** 无代码修改（除非发现 bug）

- [ ] **Step 1: 构建并安装到设备**

```bash
flutter run -d <你的 Android 15 设备 ID>
```

可先 `flutter devices` 列设备 ID。

- [ ] **Step 2: 验证表 — 逐项打勾，全部通过才算完成**

| # | 场景 | 期望表现 | 通过？ |
|---|---|---|---|
| 1 | 新建日记 → 点定位按钮 | 弹层从底部滑上，左侧天气滚轮、右侧温度滚轮，默认 晴/20°C | ☐ |
| 2 | 滑动选 "雷阵雨 / 25°C" → 确认 | 列表项显示 "上海市 浦东新区 25°C"（或你所在区） | ☐ |
| 3 | 再次打开 → 点取消 | 啥也没变，原天气保留 | ☐ |
| 4 | 关闭定位权限 → 点定位按钮 | 弹层照常打开，可只选天气；位置保留旧值 | ☐ |
| 5 | 飞行模式 → 点定位按钮 | 弹层正常，确认后位置显示成 "31.23°N, 121.47°E" 风格 | ☐ |
| 6 | 切换 App 到英文 locale → 重复 1 | 弹层文案 "Pick Weather/Confirm/Cancel"，天气名 "Sunny/Cloudy"，placemark 形如 "Pudong, Shanghai" | ☐ |

额外回归检查：

| # | 场景 | 期望表现 | 通过？ |
|---|---|---|---|
| 7 | 打开一篇老日记的详情页 | 城市名和天气图标/温度展示和改造前一致 | ☐ |
| 8 | 进入"分析"页和"地图"页 | 数据正常，无崩溃 | ☐ |

- [ ] **Step 3: 如发现 bug，定位 → 修复 → 跑 test → 重新验证**

修复后：

```bash
git add <changed-files>
git commit -m "fix: <具体说明>"
```

- [ ] **Step 4: 全部通过后做收尾提交**

如果手动测试中没有改动，无需 commit。可选：在分支上整理 commit 历史，或直接交给 PR 流程。

---

## 验收标准

- ✅ `flutter test` 全 PASS（含 16+2 个新增 test）
- ✅ `flutter analyze` 无新增 error/warning
- ✅ Android 15 真机上 8 项手动检查全 ☑
- ✅ 不再读 `qweatherKey` / `qweatherApiHost`（grep `lib/` 应只有设置页 UI 和 `pref.dart` 默认值还有引用，运行路径上无引用）
- ✅ 老日记数据加载正常（`Diary.weather` / `Diary.position` 字段兼容）
