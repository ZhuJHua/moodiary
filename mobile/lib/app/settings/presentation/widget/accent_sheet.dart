import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 强调色来源选择。三行，没别的 —— 前两档点了立刻生效并留在弹窗里，
/// 「自定义」进单独一页。
class AccentSheet extends ConsumerWidget {
  const AccentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showMoodiarySheet<void>(context, builder: (_) => const AccentSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 壁纸取色只有 Android 12+ 拿得到。拿不到就整档不显示 —— 摆一个永远点不亮的
    // 开关只会让人怀疑是不是坏了。
    final modes = [
      ThemeAccentMode.neutral,
      if (ThemeManager().supportDynamic) ThemeAccentMode.system,
      ThemeAccentMode.custom,
    ];

    return MoodiarySheetScaffold<void>(
      title: context.l10n.accentTitle,
      icon: LucideIcons.palette,
      // 选中态自己订阅 KV：弹窗页面被路由缓存（builder 只跑一次），本 widget 若不
      // 依赖任何会变的 InheritedWidget 就永远不重建，对勾会冻在打开时的那一格。
      child: ValueListenableBuilder<int>(
        valueListenable: MoodiaryKVs.themeAccentMode.getNotifier(),
        builder: (context, index, _) {
          final current = index >= 0 && index < ThemeAccentMode.values.length
              ? ThemeAccentMode.values[index]
              : ThemeAccentMode.neutral;
          return Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              for (final mode in modes)
                _AccentModeRow(
                  mode: mode,
                  selected: mode == current,
                  onTap: () => _select(context, ref, mode),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    ThemeAccentMode mode,
  ) async {
    HapticFeedback.selectionClick();
    if (mode == .custom) {
      // 自定义得先挑色再落库 —— 这里只负责跳转，KV 由取色页在「保存」时写。
      // 路由器必须在 pop 之前拿好：pop 之后本 widget 的 element 已失效，
      // 再用它查 InheritedWidget 会炸。
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(const AccentRoute().location);
      return;
    }
    await MoodiaryKVs.themeAccentMode.set(mode.index);
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
  }
}

class _AccentModeRow extends StatelessWidget {
  final ThemeAccentMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _AccentModeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const .only(bottom: 6),
        child: Material(
          color: selected ? scheme.surfaceContainerLow : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            onTap: onTap,
            child: Padding(
              padding: const .symmetric(horizontal: 14, vertical: 12),
              child: Row(
                spacing: 12,
                children: [
                  SizedBox(width: 28, height: 28, child: _swatch(context)),
                  Expanded(
                    child: Text(
                      _label(context),
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: selected ? .w600 : .w400,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(LucideIcons.check, size: 18, color: scheme.primary)
                  else if (mode == .custom)
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context) => switch (mode) {
    .neutral => context.l10n.accentNeutral,
    .system => context.l10n.accentSystem,
    .custom => context.l10n.accentCustom,
  };

  Widget _swatch(BuildContext context) {
    final scheme = context.colorScheme;
    const radius = AppBorderRadius.smallBorderRadius;
    return switch (mode) {
      // 白到黑的连续渐变。没有任何一条边，也就没有锯齿 —— 硬断点（stops [0.5, 0.5]）
      // 是着色器逐像素求值，不走几何抗锯齿，28px 下的斜边会糊成一条灰带。
      // 纯 #FFFFFF / #000000 且不随明暗档翻转：它是「没有颜色」这个概念的符号，不是某张表面。
      .neutral => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
          gradient: const LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFF000000)],
          ),
        ),
      ),
      .system => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: ThemeManager().systemAccentSeed ?? scheme.primary,
        ),
      ),
      .custom => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Color(MoodiaryKVs.themeAccentColor.get()!),
        ),
      ),
    };
  }
}
