# 离线天气与定位改造设计

**日期**：2026-05-16
**项目**：Loong-s-Diary（DenserMeerkat/June 个人化 fork）
**状态**：草稿，待实施

## 背景与动机

当前编辑日记时获取"天气"和"地点"都依赖和风天气（qweather）API，需要用户在设置页填写 `qweatherKey` 与 `qweatherApiHost`，对个人使用造成门槛。本次改造目标：

- **天气**：不再调用 qweather `/v7/weather/now`，改为内置预设 + 双滚轮底部弹层让用户手选天气类型与温度。
- **地点**：不再调用 qweather `/geo/v2/city/lookup` 反查城市名，改用系统级反查（Android `Geocoder` / iOS `CLGeocoder`）；失败时退回经纬度字符串显示。
- **数据格式与设置页保持向后兼容**，老日记数据无需迁移，旧的 qweather 配置项保留但不再生效。

## 范围

### 包含

- 新增 14 项天气预设常量
- 新增 CupertinoPicker 双滚轮底部弹层组件
- 重写 `Api.updatePosition()` 使用 `geocoding` 插件 + 经纬度兜底
- 删除 `Api.updateWeather()`
- 重写 `EditLogic.getPositionAndWeather()`：并行启动定位 + 弹层选天气，确认时合并写入
- 新增 i18n key（中/英）
- 新增 `geocoding: ^3.0.0` 依赖
- 单元测试覆盖预设表完整性、坐标格式化、placemark 拼装兜底

### 不包含（YAGNI）

- 不删除 qweather 图标字体（仍用于显示天气图标）
- 不删除 `weather.dart` / `geo.dart` 数据模型文件（仍可能被 Isar 序列化反射）
- 不改 Isar schema、不写迁移脚本
- 不删设置页的 `qweatherKey` / `qweatherApiHost` 配置项（用户决定保留）
- 不实现"自定义天气项"
- 不实现天气预测

## 关键决策

| 决策点 | 选项 | 理由 |
|---|---|---|
| 温度来源 | 用户在第二个滚轮里手动选 | 离线 API 无法自动获取 |
| 天气项数量 | 14 个标准款 | 覆盖日常但不让滚轮过长 |
| 城市名来源 | `geocoding` 插件 + 经纬度兜底 | 移动端体验近似原版，桌面端不阻塞 |
| 弹层布局 | 双滚轮并排 + 顶部确认/取消栏 | 一次性选完，符合"省地方又美观"诉求 |
| 定位触发 | 用户点按钮时自动后台触发 | 用户感知为"点一下选个天气"，定位悄悄完成 |
| 设置页改动 | 保留 qweather 配置项不动 | 最小改动 |

## 数据模型（保持不变）

```dart
// Diary（lib/common/models/isar/diary.dart）
weather:  List<String>   // [iconCode, temperature, displayText]
                         // 例：["100", "23", "晴"]
position: List<String>   // [latitude, longitude, displayName]
                         // 例：["31.22", "121.47", "上海市 浦东新区"]
                         //  或：["31.22", "121.47", "31.22°N, 121.47°E"]（兜底）
```

## 数据流

```
用户在编辑页点定位按钮
   │
   ├─ 后台并行：Geolocator.getCurrentPosition()
   │      └─ geocoding.placemarkFromCoordinates() → "上海市 浦东新区"
   │             └─ 失败/超时/桌面 → "31.23°N, 121.47°E" 兜底
   │
   └─ 立即弹出 CupertinoPicker 底部弹层（默认值：现有值或 晴/20°C）
            ↓ 用户滑动选择
            ↓ 点"确认"
       state.currentDiary.weather  = [preset.code, temp.toString(), preset.label(context)]
       state.currentDiary.position = await positionFuture （如有）
       update(['Weather'])
```

如果后台定位还没回来用户就点了确认：`await positionFuture` 在编辑流程内等待至定位完成或失败（GPS 取点 timeLimit 8s + geocoding timeout 4s，总上限约 12s 内即可返回）。失败/超时则保留原 position。

## 组件设计

### 1. `lib/common/values/weather_presets.dart`（新建）

```dart
class WeatherPreset {
  final String code;     // qweather 图标码，存到 diary.weather[0]
  final String nameKey;  // i18n key，便于 switch 解析
  const WeatherPreset(this.code, this.nameKey);
}

const kWeatherPresets = <WeatherPreset>[
  WeatherPreset('100', 'weatherSunny'),         // 晴
  WeatherPreset('101', 'weatherCloudy'),        // 多云
  WeatherPreset('104', 'weatherOvercast'),      // 阴
  WeatherPreset('300', 'weatherShowerRain'),    // 阵雨
  WeatherPreset('305', 'weatherLightRain'),     // 小雨
  WeatherPreset('306', 'weatherModerateRain'),  // 中雨
  WeatherPreset('307', 'weatherHeavyRain'),     // 大雨
  WeatherPreset('302', 'weatherThunder'),       // 雷阵雨
  WeatherPreset('400', 'weatherLightSnow'),     // 小雪
  WeatherPreset('401', 'weatherModerateSnow'),  // 中雪
  WeatherPreset('402', 'weatherHeavySnow'),     // 大雪
  WeatherPreset('501', 'weatherFog'),           // 雾
  WeatherPreset('502', 'weatherHaze'),          // 霾
  WeatherPreset('507', 'weatherSandstorm'),     // 沙尘暴
];

extension WeatherPresetL10n on WeatherPreset {
  String label(BuildContext c) => switch (nameKey) {
    'weatherSunny'        => c.l10n.weatherSunny,
    'weatherCloudy'       => c.l10n.weatherCloudy,
    'weatherOvercast'     => c.l10n.weatherOvercast,
    'weatherShowerRain'   => c.l10n.weatherShowerRain,
    'weatherLightRain'    => c.l10n.weatherLightRain,
    'weatherModerateRain' => c.l10n.weatherModerateRain,
    'weatherHeavyRain'    => c.l10n.weatherHeavyRain,
    'weatherThunder'      => c.l10n.weatherThunder,
    'weatherLightSnow'    => c.l10n.weatherLightSnow,
    'weatherModerateSnow' => c.l10n.weatherModerateSnow,
    'weatherHeavySnow'    => c.l10n.weatherHeavySnow,
    'weatherFog'          => c.l10n.weatherFog,
    'weatherHaze'         => c.l10n.weatherHaze,
    'weatherSandstorm'    => c.l10n.weatherSandstorm,
    _ => nameKey,
  };
}
```

### 2. `lib/components/weather_picker_sheet.dart`（新建）

签名：

```dart
typedef WeatherPickerResult = ({WeatherPreset preset, int temp});

Future<WeatherPickerResult?> showWeatherPickerSheet({
  required BuildContext context,
  required WeatherPreset initialPreset,
  required int initialTemp,
});
```

实现要点：
- 用 `showModalBottomSheet`（Material 风格） + 内部 `StatefulWidget`
- 弹层高度 ~280-320 px
- 顶部栏：左 `TextButton(取消)` 右 `TextButton(确认)`，分隔线下方为内容
- 内容区两个 `CupertinoPicker` 横向 `Row`：
  - 左：itemExtent 36，每项 = `Icon(WeatherIcon.map[preset.code]) + 文案`
  - 右：itemExtent 36，每项 = `"$value °C"`
- 温度范围 `-30..50`（含两端，共 81 项）
- "确认"返回 `(preset, temp)`，"取消"或返回手势 → `null`

### 3. `lib/api/api.dart`（重写 `updatePosition` + 删除 `updateWeather`）

```dart
static Future<List<String>?> updatePosition(BuildContext context) async {
  // 权限 + 定位逻辑保留原样
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

  // 反查（新逻辑）
  String displayName = _formatCoords(position.latitude, position.longitude);
  try {
    final local = context.mounted ? Localizations.localeOf(context) : null;
    if (local != null) {
      await setLocaleIdentifier(local.toLanguageTag());
    }
    final placemarks = await placemarkFromCoordinates(
      position.latitude, position.longitude,
    ).timeout(const Duration(seconds: 4));
    if (placemarks.isNotEmpty) {
      displayName = _composePlacemark(placemarks.first, local) ?? displayName;
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

static String _formatCoords(double lat, double lng) {
  final ns = lat >= 0 ? 'N' : 'S';
  final ew = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(2)}°$ns, '
         '${lng.abs().toStringAsFixed(2)}°$ew';
}

static String? _composePlacemark(Placemark p, Locale? locale) {
  bool ne(String? s) => s != null && s.isNotEmpty;
  final isAsianLang = locale != null &&
      const {'zh', 'ja', 'ko'}.contains(locale.languageCode);
  if (isAsianLang) {
    final parts = [
      if (ne(p.administrativeArea)) p.administrativeArea!,
      if (ne(p.locality))           p.locality!,
      if (ne(p.subLocality))        p.subLocality!,
    ];
    if (parts.isEmpty) {
      if (ne(p.country)) return p.country;
      return null;
    }
    return parts.join(' ');
  }
  // 英文/其它
  if (ne(p.locality) && ne(p.country)) return '${p.locality}, ${p.country}';
  if (ne(p.administrativeArea) && ne(p.country)) {
    return '${p.administrativeArea}, ${p.country}';
  }
  return ne(p.country) ? p.country : null;
}
```

完全删除 `Api.updateWeather()`，并清理 `weather.dart` / `geo.dart` import（如不再使用）。

### 4. `lib/pages/edit/edit_logic.dart`（重写 `getPositionAndWeather`）

```dart
Future<void> getPositionAndWeather({required BuildContext context}) async {
  state.isProcessing = true;
  update(['Weather']);

  // 后台并行启动定位
  final positionFuture = Api.updatePosition(context);

  // 解析当前已有的 preset 和 temp 作为弹层初始值
  final initialPreset = _resolveCurrentPreset();   // 找不到则取 kWeatherPresets[0]
  final initialTemp   = _resolveCurrentTemp();     // 找不到则 20

  final result = await showWeatherPickerSheet(
    context: context,
    initialPreset: initialPreset,
    initialTemp: initialTemp,
  );

  if (result == null) {
    state.isProcessing = false;
    update(['Weather']);
    // 用户取消，丢弃定位结果；positionFuture 仍会在后台完成（最长 ~8s），但其结果被忽略
    return;
  }

  state.currentDiary.weather = [
    result.preset.code,
    result.temp.toString(),
    result.preset.label(context),
  ];

  try {
    final position = await positionFuture;
    if (position != null) state.currentDiary.position = position;
  } catch (_) {
    // 定位侧异常已在 Api.updatePosition 内 toast，这里不重复报错
  }

  state.isProcessing = false;
  update(['Weather']);
  if (context.mounted) {
    toast.success(message: context.l10n.weatherSuccess);
  }
}
```

辅助方法 `_resolveCurrentPreset()` / `_resolveCurrentTemp()` 都是私有：扫 `state.currentDiary.weather`，匹配上就用，匹配不上回退默认。

### 5. `lib/pages/edit/edit_view.dart`（不动）

触发逻辑没变，继续用 `IconButton.filledTonal(... onPressed: () => logic.getPositionAndWeather(context: context))`。

## i18n 新增 key

`lib/l10n/intl_zh.arb`：

```json
{
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
}
```

`lib/l10n/intl_en.arb`：

```json
{
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
}
```

`lib/l10n/app_localizations*.dart` 通过 `flutter gen-l10n` 自动重新生成。

## 依赖变更

`pubspec.yaml` 新增：

```yaml
dependencies:
  geocoding: ^3.0.0
```

无需删除任何现有依赖（qweather 字体仍在用，`geolocator` 仍在用）。

## 错误处理与降级

| 场景 | 处理 |
|---|---|
| GPS 权限被拒绝 | 老的 `noticeEnableLocation` toast，弹层照常打开，用户可只选天气 |
| GPS 服务关闭 | `updatePosition` 返回 null，弹层照常打开，位置不更新 |
| `geocoding` 反查超时（>4s）/异常 | 静默兜底为经纬度字符串，无 toast 干扰 |
| 桌面端（Win/Linux）调用 geocoding | 抛错 → catch → 经纬度兜底 |
| 用户在弹层点"取消" | 丢弃天气和位置结果 |
| 弹层关闭时 positionFuture 仍未 resolve | 编辑流程 await 等待至 resolve；GPS timeLimit 8s + geocoding timeout 4s 共约 12s 上限。超时保留原 position |
| 编辑老日记打开弹层 | `_resolveCurrentPreset` 按 `weather[0]` 找匹配预设；找不到回退到首项 |

## 测试方案

### 单元测试

`test/weather_presets_test.dart`：
- `kWeatherPresets.length == 14`
- 每个 `code` 都在 `WeatherIcon.map` 里有键
- 每个 `nameKey` 都能被 `WeatherPresetL10n.label` switch 命中（不走 `_ => nameKey` 回退）

`test/api_position_test.dart`：
- `Api._formatCoords(31.234, 121.473)` → `"31.23°N, 121.47°E"`
- `Api._formatCoords(-23.5, -46.6)` → `"23.50°S, 46.60°W"`
- `Api._formatCoords(0, 0)` → `"0.00°N, 0.00°E"`
- `Api._composePlacemark`：
  - 中文 locale + 全字段 → `"上海市 上海市 浦东新区"` 风格
  - 中文 locale + 缺 subLocality → `"上海市 上海市"`
  - 中文 locale + 全空 → `null`
  - 英文 locale + 有 locality+country → `"Shanghai, China"`
  - 英文 locale + 只有 country → `"China"`

（`_formatCoords` 和 `_composePlacemark` 需提至 `@visibleForTesting` 或挪到独立文件以便测试。）

### 手动测试（Android 15 真机）

1. 新建日记 → 点定位按钮 → 弹层从底部滑上 → 滑动天气和温度 → 确认 → 列表项展示 "上海市 浦东新区 23°C"
2. 取消按钮 → 啥也没变
3. 关闭定位权限 → 弹层照常打开 → 只选天气 → 确认 → 只更新天气，位置保留旧值
4. 飞行模式 → geocoding 失败 → 位置显示成 `"31.23°N, 121.47°E"`
5. 老日记打开详情页 → 城市和天气展示和原来一样
6. 切换到英文 locale → 弹层文案、placemark 都变英文（"Sunny" / "Pudong, Shanghai" 等）

### 回归点

- `analyse_*.dart`、`map_*.dart`、`share_view.dart`、`laboratory_*.dart`、`diary_details_view.dart` 全部读 `weather[i]` / `position[i]` 索引 → 数据格式未变，无影响
- 设置页 qweather key 配置项依然存在但不再生效（按用户决定保留）

## 兼容性

- Isar schema 不变 → 老日记直接可读
- 旧日记 `weather` / `position` 字段格式与新写入格式一致 → 详情页/分析页无差异
- 设置页 `qweatherKey` / `qweatherApiHost` 保留 → 用户配置不会被吞
