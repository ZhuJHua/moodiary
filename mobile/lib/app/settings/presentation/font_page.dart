import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class FontPage extends ConsumerStatefulWidget {
  const FontPage({super.key});

  static String sizeLabel(MuiTextSize size) => switch (size) {
    .xSmall => '超小',
    .small => '小',
    .medium => '偏小',
    .large => '标准',
    .xLarge => '大',
    .xxLarge => '超大',
    .xxxLarge => '特大',
  };

  @override
  ConsumerState<FontPage> createState() => _FontPageState();
}

class _FontPageState extends ConsumerState<FontPage> {
  /// 拖动中的临时档：仅驱动本页滑块 + 预览。松手才提交全局 —— 换档会重建整套主题
  /// 并重排所有存活路由的文本，逐档提交会整段拖动都在掉帧。
  MuiTextSize? _dragSize;

  Future<void> _commitSize(MuiTextSize value) async {
    // 先提交（state 即时生效、KV 落盘后 notifier 推给编辑器），再清临时值——
    // 此时 KV 通知已送达本页 builder，滑块无缝接到全局值，不回跳。
    // 仅当临时值仍是本次提交值才清：await 期间若已开始新一轮拖动，不抢它的值。
    await ref.read(appSettingsControllerProvider.notifier).setTextSize(value);
    if (mounted && _dragSize == value) setState(() => _dragSize = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('字体')),
      body: ValueListenableBuilder<String>(
        valueListenable: MoodiaryKVs.customFont.getNotifier(),
        builder: (context, currentFamily, _) {
          return ValueListenableBuilder<int>(
            valueListenable: MoodiaryKVs.textSize.getNotifier(),
            builder: (context, storedIndex, _) {
              final size =
                  _dragSize ??
                  (storedIndex >= 0 && storedIndex < MuiTextSize.values.length
                      ? MuiTextSize.values[storedIndex]
                      : MuiTextSize.large);
              return ListView(
                padding: const .all(8),
                children: [
                  const SettingTitleTile(
                    title: '字体',
                    subtitle: '导入 ttf / otf 字体，长按可删除',
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
                  const SettingTitleTile(title: '字号'),
                  Card.filled(
                    color: scheme.surfaceContainerLow,
                    margin: .zero,
                    child: Padding(
                      padding: const .fromLTRB(16, 8, 16, 12),
                      child: _TextSizeSlider(
                        value: size,
                        // 拖动中只动本页（滑块 + 预览）；松手提交全局并推给编辑器。
                        onChanged: (v) => setState(() => _dragSize = v),
                        onChangeEnd: _commitSize,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SettingTitleTile(title: '预览'),
                  Card.filled(
                    color: scheme.surfaceContainerLow,
                    margin: .zero,
                    child: Padding(
                      padding: const .all(16),
                      child: _Preview(fontFamily: currentFamily, size: size),
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
            label: '系统',
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
    final ok = await showMoodiaryConfirm(
      context,
      title: '删除字体',
      message: '确认删除字体「${font.fontFamily}」吗？',
      confirmLabel: '删除',
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
                        '可变',
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
              '添加',
              style: context.theme.typography.labelSmall.onSurfaceVariant,
              maxWidth: 72,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextSizeSlider extends StatelessWidget {
  final MuiTextSize value;
  final ValueChanged<MuiTextSize> onChanged;
  final ValueChanged<MuiTextSize> onChangeEnd;

  const _TextSizeSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static MuiTextSize _snap(double v) =>
      MuiTextSize.values[v.round().clamp(0, MuiTextSize.values.length - 1)];

  @override
  Widget build(BuildContext context) {
    final label = FontPage.sizeLabel(value);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Text(
              'A',
              style: context.theme.typography.bodyMedium.onSurfaceVariant,
            ),
            Expanded(
              child: Slider(
                value: value.index.toDouble(),
                max: (MuiTextSize.values.length - 1).toDouble(),
                divisions: MuiTextSize.values.length - 1,
                label: label,
                onChanged: (v) {
                  final closest = _snap(v);
                  if (closest != value) HapticFeedback.selectionClick();
                  onChanged(closest);
                },
                onChangeEnd: (v) => onChangeEnd(_snap(v)),
              ),
            ),
            Text(
              'A',
              style: context.theme.typography.titleLarge.onSurfaceVariant,
            ),
          ],
        ),
        Center(
          child: Text(
            label,
            style: context.theme.typography.labelMedium.emphasized.primary,
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  final String fontFamily;
  final MuiTextSize size;

  const _Preview({required this.fontFamily, required this.size});

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
    final theme = context.theme;
    final family = fontFamily.isEmpty ? null : fontFamily;
    // 按选中档**现算一份排版**：字号已经解析进主题，预览不能再靠 textScaler 放大，
    // 否则松手提交后尺寸会和预览对不上。
    final typography = MuiTypography.resolve(
      size: size,
      font: MuiFontConfig(family: family, wghtAxis: theme.font.wghtAxis),
      colors: theme.colors,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          '八月的忧愁',
          style: typography.titleLarge.onSurface.copyWith(height: 2),
        ),
        const SizedBox(height: 8),
        Text(_poem, style: typography.bodyMedium.onSurface.copyWith(height: 2)),
      ],
    );
  }
}
