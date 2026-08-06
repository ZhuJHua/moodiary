import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

class ColorSheet extends ConsumerWidget {
  const ColorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showMoodiarySheet<void>(context, builder: (_) => const ColorSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSystemColor = ThemeManager().supportDynamic;

    final indices = <int>[
      if (hasSystemColor) -1,
      for (int i = 0; i < AppColor.themeColorList.length; i++) i,
    ];

    return MoodiarySheetScaffold<void>(
      title: context.l10n.colorCommon,
      icon: LucideIcons.palette,
      actions: [MoodiaryAction(label: context.l10n.ok, isPrimary: true)],
      // 选中态必须自己订阅 KV：弹窗页面被路由缓存（builder 只跑一次），本 widget 若不
      // 依赖任何会变的 InheritedWidget 就永远不重建，对勾会冻在打开时的那一格。
      child: ValueListenableBuilder<int?>(
        valueListenable: MoodiaryKVs.color.getNotifier(),
        builder: (context, color, _) {
          final currentColor = color ?? (hasSystemColor ? -1 : 0);
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 80,
              childAspectRatio: 1.0,
            ),
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: indices.length,
            itemBuilder: (context, index) {
              final colorIndex = indices[index];
              return _ColorOption(
                colorIndex: colorIndex,
                isSelected: currentColor == colorIndex,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await MoodiaryKVs.color.set(colorIndex);
                  await ref
                      .read(appSettingsControllerProvider.notifier)
                      .bumpTheme();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final int colorIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.colorIndex,
    required this.isSelected,
    required this.onTap,
  });

  ColorScheme _buildScheme(BuildContext context) {
    final brightness = context.theme.colorScheme.brightness;
    if (colorIndex == -1) {
      return brightness == Brightness.light
          ? ThemeManager().lightDynamic!
          : ThemeManager().darkDynamic!;
    }
    return ColorScheme.fromSeed(
      seedColor: AppColor.themeColorList[colorIndex],
      brightness: brightness,
      dynamicSchemeVariant: colorIndex == 0
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _buildScheme(context);
    final label = AppColor.colorName(colorIndex, context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: scheme.primary,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        child: InkWell(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 6,
                bottom: 6,
                right: 6,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: 14,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
