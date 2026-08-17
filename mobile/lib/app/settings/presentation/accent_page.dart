import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

/// 自定义强调色。页面主体就是**这个种子生成出来的真实色板** —— 每格底色即该角色的色、
/// 文字用它配对的 on 色，所以「这个色上放字读不读得清」是直接看出来的，不必另做预览。
///
/// 改色只刷新本页，不动全局主题：`bumpTheme()` 会重读字体文件（磁盘 IO），
/// 逐次调用会卡。真正生效在「保存」。
class AccentPage extends ConsumerStatefulWidget {
  const AccentPage({super.key});

  @override
  ConsumerState<AccentPage> createState() => _AccentPageState();
}

class _AccentPageState extends ConsumerState<AccentPage> {
  late Color _seed = Color(MoodiaryKVs.themeAccentColor.get()!);

  Future<void> _pick() async {
    final picked = await MColorPicker.show(context, initialColor: _seed);
    if (picked != null) setState(() => _seed = picked);
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    MoodiaryKVs.themeAccentColor.set(_seed.toARGB32());
    MoodiaryKVs.themeAccentMode.set(ThemeAccentMode.custom.index);
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = resolveColorScheme(
      context.theme.brightness,
      MuiAccent.seeded(_seed),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.app.accentCustomTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(context.l10n.common.save)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const .fromLTRB(20, 8, 20, 32),
          children: [
            _SeedCard(seed: _seed, onTap: _pick),
            const SizedBox(height: 20),
            MSwatchRow(
              selected: _seed,
              onSelected: (color) => setState(() => _seed = color),
            ),
            _GroupLabel(context.l10n.app.accentGroupAccent),
            _TokenGrid(
              columns: 2,
              tokens: [
                (label: 'primary', color: scheme.primary, on: scheme.onPrimary),
                (
                  label: 'primaryContainer',
                  color: scheme.primaryContainer,
                  on: scheme.onPrimaryContainer,
                ),
                (
                  label: 'secondary',
                  color: scheme.secondary,
                  on: scheme.onSecondary,
                ),
                (
                  label: 'secondaryContainer',
                  color: scheme.secondaryContainer,
                  on: scheme.onSecondaryContainer,
                ),
                (
                  label: 'tertiary',
                  color: scheme.tertiary,
                  on: scheme.onTertiary,
                ),
                (
                  label: 'tertiaryContainer',
                  color: scheme.tertiaryContainer,
                  on: scheme.onTertiaryContainer,
                ),
              ],
            ),
            _GroupLabel(context.l10n.app.accentGroupSurface),
            _TokenGrid(
              columns: 4,
              tokens: [
                (label: 'surface', color: scheme.surface, on: scheme.onSurface),
                (
                  label: 'low',
                  color: scheme.surfaceContainerLow,
                  on: scheme.onSurface,
                ),
                (
                  label: 'container',
                  color: scheme.surfaceContainer,
                  on: scheme.onSurface,
                ),
                (
                  label: 'highest',
                  color: scheme.surfaceContainerHighest,
                  on: scheme.onSurface,
                ),
              ],
            ),
            _GroupLabel(context.l10n.app.accentGroupSemantic),
            _TokenGrid(
              columns: 2,
              tokens: [
                (label: 'error', color: scheme.error, on: scheme.onError),
                (
                  label: 'errorContainer',
                  color: scheme.errorContainer,
                  on: scheme.onErrorContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 当前种子色。点开取色弹窗 —— 用户挑的是**种子**，上面那些格子才是 Material
/// 生成的结果，两者几乎不会相同，所以这里的 hex 单独摆着。
class _SeedCard extends StatelessWidget {
  final Color seed;
  final VoidCallback onTap;

  const _SeedCard({required this.seed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    // 这层不是为了托水波 —— 它画着那圈描边，所以留着，只是换成不带 ink 的形态。
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.largeBorderRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: MInkWell(
        borderRadius: AppBorderRadius.largeBorderRadius,
        onTap: onTap,
        child: Padding(
          padding: const .all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: seed,
                  borderRadius: AppBorderRadius.mediumBorderRadius,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    Text(
                      context.l10n.app.accentSeed,
                      style:
                          context.theme.typography.labelSmall.onSurfaceVariant,
                    ),
                    Text(
                      hexOfColor(seed),
                      style: context.theme.typography.titleMedium.onSurface
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.pipette,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Token = ({String label, Color color, Color on});

class _TokenGrid extends StatelessWidget {
  final int columns;
  final List<_Token> tokens;

  const _TokenGrid({required this.columns, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: .zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: columns == 2 ? 2.6 : 1.15,
      ),
      itemCount: tokens.length,
      itemBuilder: (context, index) {
        final token = tokens[index];
        return Container(
          padding: const .all(9),
          decoration: BoxDecoration(
            color: token.color,
            borderRadius: AppBorderRadius.smallBorderRadius,
            // 近白的表面格在白底页面上会没边，补一道发丝线。
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: .start,
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                token.label,
                maxLines: 2,
                overflow: .ellipsis,
                style: context.theme.typography.labelSmall.emphasized.onSurface
                    .copyWith(color: token.on),
              ),
              Text(
                hexOfColor(token.color),
                style: context.theme.typography.labelSmall.onSurface.copyWith(
                  color: token.on,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 22, bottom: 8),
      child: Text(
        label,
        style: context.theme.typography.labelMedium.emphasized.onSurfaceVariant
            .copyWith(letterSpacing: 0.6),
      ),
    );
  }
}
