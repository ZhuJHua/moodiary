import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';

class FontPage extends ConsumerWidget {
  const FontPage({super.key});

  static const _fontScales = <double>[0.8, 0.9, 1.0, 1.1, 1.2];

  static String _scaleLabel(double scale) => switch (scale) {
    0.8 => '超小',
    0.9 => '小',
    1.0 => '标准',
    1.1 => '大',
    1.2 => '超大',
    _ => '标准',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('字体')),
      body: ValueListenableBuilder<String>(
        valueListenable: MoodiaryKVs.customFont.getNotifier(),
        builder: (context, currentFamily, _) {
          return ValueListenableBuilder<double>(
            valueListenable: MoodiaryKVs.fontScale.getNotifier(),
            builder: (context, currentScale, _) {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  _FontPicker(currentFamily: currentFamily),
                  const Divider(endIndent: 24, indent: 24, height: 32),
                  _FontScaleSlider(
                    value: currentScale,
                    onChanged: (v) => MoodiaryKVs.fontScale.set(v),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _Preview(
                      fontFamily: currentFamily,
                      scale: currentScale,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static List<double> get scales => _fontScales;
  static String scaleLabel(double scale) => _scaleLabel(scale);
}

class _FontPicker extends ConsumerWidget {
  final String currentFamily;

  const _FontPicker({required this.currentFamily});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFonts = ref.watch(fontControllerProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        spacing: 16,
        children: [
          _FontCard(
            label: '系统',
            family: '',
            selected: currentFamily.isEmpty,
            onTap: () => ref
                .read(fontControllerProvider.notifier)
                .setActive(null),
          ),
          ...asyncFonts.maybeWhen(
            data: (fonts) => fonts.map(
              (f) => _FontCard(
                label: f.fontFamily,
                family: f.fontFamily,
                selected: currentFamily == f.fontFamily,
                onTap: () => ref
                    .read(fontControllerProvider.notifier)
                    .setActive(f),
                onLongPress: () => _confirmDelete(context, ref, f),
              ),
            ),
            orElse: () => <Widget>[],
          ),
          _AddFontCard(
            onTap: () async {
              final result = await ref
                  .read(fontControllerProvider.notifier)
                  .addFont();
              if (result == null || result.isEmpty) return;
              toast.error(message: result);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Font font,
  ) async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除字体'),
        content: Text('确认删除字体「${font.fontFamily}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(fontControllerProvider.notifier).removeFont(font);
  }
}

class _FontCard extends StatelessWidget {
  final String label;
  final String family;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FontCard({
    required this.label,
    required this.family,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final active = scheme.primary;
    final inactive = scheme.surfaceContainerHighest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: Border.all(
                color: selected ? active : inactive,
                width: selected ? 2 : 1,
              ),
            ),
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 32,
                  fontFamily: family.isEmpty ? null : family,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: AdaptiveText(
            label,
            style: context.textTheme.labelSmall,
            maxWidth: 64,
          ),
        ),
      ],
    );
  }
}

class _AddFontCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFontCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              color: scheme.surfaceContainer,
            ),
            width: 64,
            height: 64,
            child: Center(
              child: Icon(
                Icons.add_circle_rounded,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: AdaptiveText(
            '添加',
            style: context.textTheme.labelSmall,
            maxWidth: 64,
          ),
        ),
      ],
    );
  }
}

class _FontScaleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontScaleSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = FontPage.scaleLabel(value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('字号'),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: FontPage.scales.first,
            max: FontPage.scales.last,
            divisions: FontPage.scales.length - 1,
            label: label,
            onChanged: (v) {
              final closest = FontPage.scales.reduce(
                (a, b) => (a - v).abs() < (b - v).abs() ? a : b,
              );
              onChanged(closest);
            },
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final String fontFamily;
  final double scale;

  const _Preview({required this.fontFamily, required this.scale});

  static const _poem =
      '黄水塘里游着白鸭，\n'
      '高粱梗油青的刚高过头，\n'
      '这跳动的心怎样安插，\n'
      '田里一窄条路，八月里这忧愁？\n'
      '天是昨夜雨洗过的，山岗\n'
      '照着太阳又留一片影；\n'
      '羊跟着放羊的转进村庄，\n'
      '一大棵树荫下罩着井，又像是心！\n'
      '从没有人说过八月什么话，\n'
      '夏天过去了，也不到秋天。\n'
      '但我望着田垄，土墙上的瓜，\n'
      '仍不明白生活同梦怎样的连牵。';

  @override
  Widget build(BuildContext context) {
    final family = fontFamily.isEmpty ? null : fontFamily;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '八月的忧愁',
            style: context.textTheme.titleLarge?.copyWith(
              height: 2,
              fontFamily: family,
            ),
            textScaler: TextScaler.linear(scale),
          ),
          const SizedBox(height: 8),
          Text(
            _poem,
            style: context.textTheme.bodyMedium?.copyWith(
              height: 2,
              fontFamily: family,
            ),
            textScaler: TextScaler.linear(scale),
          ),
        ],
      ),
    );
  }
}
