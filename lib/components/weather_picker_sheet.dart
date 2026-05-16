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
