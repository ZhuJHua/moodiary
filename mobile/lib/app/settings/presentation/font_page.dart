import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class FontPage extends ConsumerStatefulWidget {
  const FontPage({super.key});

  @override
  ConsumerState<FontPage> createState() => _FontPageState();
}

class _FontPageState extends ConsumerState<FontPage> {
  /// 拖动中的临时档：仅驱动本页滑块 + 预览。松手才提交全局 —— 换档会重建整套主题
  /// 并重排所有存活路由的文本，逐档提交会整段拖动都在掉帧。
  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.fontTitle)),
      body: ValueListenableBuilder<String>(
        valueListenable: MoodiaryKVs.customFont.getNotifier(),
        builder: (context, currentFamily, _) => ListView(
          padding: const .all(8),
          children: [
            SettingTitleTile(
              title: context.l10n.app.fontTitle,
              subtitle: context.l10n.app.fontImportSubtitle,
            ),
            Card.filled(
              color: scheme.surfaceContainerLow,
              margin: .zero,
              child: Padding(
                padding: const .symmetric(vertical: 16),
                child: _FontPicker(currentFamily: currentFamily),
              ),
            ),
            const SizedBox(height: 4),
            SettingTitleTile(
              title: context.l10n.app.fontPreview,
              subtitle: context.l10n.app.fontPreviewSubtitle,
            ),
            Card.filled(
              color: scheme.surfaceContainerLow,
              margin: .zero,
              child: Padding(
                padding: const .all(16),
                child: _Preview(fontFamily: currentFamily),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontPicker extends ConsumerWidget {
  final String currentFamily;

  const _FontPicker({required this.currentFamily});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFonts = ref.watch(fontControllerProvider);
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          _FontCard(
            label: context.l10n.app.fontSystem,
            family: '',
            selected: currentFamily.isEmpty,
            onTap: () =>
                ref.read(fontControllerProvider.notifier).setActive(null),
          ),
          ...asyncFonts.maybeWhen(
            data: (fonts) => fonts.map(
              (f) => _FontCard(
                label: f.fontFamily,
                family: f.fontFamily,
                // 非空 wght 轴表 ⇒ 可变字体（非 VF 在 Rust 解析层即报错、落库为空表）。
                isVariable: f.fontWghtAxisMap.isNotEmpty,
                selected: currentFamily == f.fontFamily,
                onTap: () =>
                    ref.read(fontControllerProvider.notifier).setActive(f),
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
    final ok = await MAlert.confirm(
      context,
      title: l10n.app.fontDeleteTitle,
      message: l10n.app.fontDeleteMessage(name: font.fontFamily),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!ok) return;
    await ref.read(fontControllerProvider.notifier).removeFont(font);
  }
}

class _FontCard extends StatelessWidget {
  final String label;
  final String family;
  final bool selected;
  final bool isVariable;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FontCard({
    required this.label,
    required this.family,
    required this.selected,
    this.isVariable = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      mainAxisSize: .min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              color: selected
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHigh,
              border: .all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            width: 72,
            height: 72,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    'Aa',
                    style:
                        (selected
                                ? context
                                      .theme
                                      .typography
                                      .headlineMedium
                                      .onSecondaryContainer
                                : context
                                      .theme
                                      .typography
                                      .headlineMedium
                                      .onSurface)
                            .copyWith(
                              fontFamily: family.isEmpty ? null : family,
                            ),
                  ),
                ),
                if (isVariable)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const .symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        // 用 tertiary（accent 调）而非 tertiaryContainer：暗色下后者与
                        // secondaryContainer 卡片同明度，仅靠色相区分、几乎不可见。
                        color: scheme.tertiary,
                        borderRadius: .circular(999),
                      ),
                      child: Text(
                        context.l10n.app.fontVariable,
                        // 徽标属 UI 装饰，不随字号偏好缩放（0.8 档会低于可读下限）。
                        textScaler: .noScaling,
                        style: context.theme.typography.labelSmall.onTertiary
                            .copyWith(fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Center(
            child: AdaptiveText(
              label,
              style: selected
                  ? context.theme.typography.labelSmall.emphasized.primary
                  : context.theme.typography.labelSmall.onSurfaceVariant,
              maxWidth: 72,
            ),
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
    final scheme = context.theme.colors;
    return Column(
      mainAxisSize: .min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              color: scheme.surfaceContainerHigh,
            ),
            width: 72,
            height: 72,
            child: Center(
              child: Icon(LucideIcons.plus, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Center(
            child: AdaptiveText(
              context.l10n.app.fontAdd,
              style: context.theme.typography.labelSmall.onSurfaceVariant,
              maxWidth: 72,
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  final String fontFamily;

  const _Preview({required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final family = fontFamily.isEmpty ? null : fontFamily;
    // 预览的是**这个字体**，不是当前主题字体，所以现算一份排版换掉 family。
    final font = MuiFontConfig(family: family, wghtAxis: theme.font.wghtAxis);
    final typography = MuiTypography(
      buildTextTheme(font, theme.colors.onSurface),
      theme.colors,
      theme.onMedia,
      font,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.l10n.app.fontPreviewTitle,
          style: typography.titleLarge.onSurface.copyWith(height: 2),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.app.fontPreviewText,
          style: typography.bodyMedium.onSurface.copyWith(height: 2),
        ),
      ],
    );
  }
}
