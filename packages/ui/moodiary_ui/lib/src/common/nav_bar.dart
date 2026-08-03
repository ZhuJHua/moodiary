import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_ui/src/glass/glass_surface.dart';

/// 悬浮胶囊底栏的固定尺寸。改这里就等于改版式，别在调用方另写字面量。
const double kMoodiaryNavBarHeight = 60;
const double kMoodiaryNavBarSideMargin = 16;
const double kMoodiaryNavBarBottomGap = 10;

const double _kActionSize = 60;
const double _kActionSpacing = 10;

/// 胶囊内壁到内容的留白，**四边同一个数**。选中药丸铺满自己那一格，于是第一个 tab 的
/// 左边距、最后一个 tab 的右边距、以及所有 tab 的上下边距全都等于它。
///
/// 取 6 而不是 8：药丸高 = 60 − 2×6 = 48，而每个 tab 的点击区就是自己那一格
/// （见 [_Tab]），48 正好压在 Material 的最小点击目标上，再往里缩就不达标了。
const double _kTrackInset = 6;

/// 底栏是导航不是正文：字号缩放到这里封顶，否则 1.6× 下标签会把胶囊顶穿。
const double _kMaxTextScale = 1.15;

/// 一个 tab。只有一个图标 —— Lucide 是单线图标集，没有 Material 那种填充变体，
/// 选中态由药丸和变色承担。
class MoodiaryNavDestination {
  final Widget icon;
  final String label;

  const MoodiaryNavDestination({required this.icon, required this.label});
}

/// 胶囊右侧那颗独立按钮。与 iOS 侧 `GlassBottomBar.extraButton` 对齐：它不是 tab，
/// 不参与选中态。
class MoodiaryNavAction {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const MoodiaryNavAction({required this.icon, this.tooltip, this.onPressed});
}

/// 安卓侧的悬浮胶囊底栏：一段玻璃胶囊装 tab，右边跟一颗独立的动作按钮。
///
/// 放进 `Scaffold.bottomNavigationBar` 并开 `extendBody: true` —— 这样 Scaffold 会把本
/// 组件的整条带高折进 body 的 `MediaQuery.padding.bottom`，各页面照常读
/// `MediaQuery.paddingOf(context).bottom` 就能拿到正确留白，不需要谁去手算。
class MoodiaryNavBar extends StatelessWidget {
  final List<MoodiaryNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MoodiaryNavAction? action;

  const MoodiaryNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.action,
  });

  /// 整条带高（含安全区）。常规页面不需要它 —— 见类注释。
  static double bandHeight(BuildContext context) =>
      kMoodiaryNavBarHeight +
      kMoodiaryNavBarBottomGap +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // 字号封顶：防止标签把胶囊顶穿。底栏是导航不是正文。
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxTextScale,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kMoodiaryNavBarSideMargin,
          0,
          kMoodiaryNavBarSideMargin,
          bottom + kMoodiaryNavBarBottomGap,
        ),
        child: SizedBox(
          height: kMoodiaryNavBarHeight,
          child: Row(
            children: [
              Expanded(
                child: _Capsule(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: _kActionSpacing),
                _ActionButton(action: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  final List<MoodiaryNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _Capsule({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return MoodiaryGlassSurface(
      shape: const StadiumBorder(),
      child: Padding(
        // 四边同一个 inset，药丸铺满自己那一格 —— 于是首/末 tab 的左右边距与上下
        // 边距天然相等。药丸窄于格子的话，两端就会多出 (格宽 − 药丸宽)/2 对不齐。
        padding: const EdgeInsets.all(_kTrackInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = destinations.length;
            final tabWidth = constraints.maxWidth / count;
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: Durations.medium2,
                  curve: Easing.emphasizedDecelerate,
                  left: tabWidth * selectedIndex,
                  top: 0,
                  width: tabWidth,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.secondaryContainer,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _Tab(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final MoodiaryNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    // 图标和标签同色，取所在背景的配对色：选中态整格都盖在药丸上 → onSecondaryContainer，
    // 未选中坐在玻璃（surfaceContainer / High）上 → onSurfaceVariant。
    //
    // **别照抄 `_NavigationBarDefaultsM3`**：那边标签用 onSurface，是因为 M3 的药丸只包
    // 图标、标签落在药丸外的底栏背景上，两者本来就在两个不同的背景上。我们的药丸铺满
    // 整格，标签也在药丸上，跟着图标走才是对的配对。
    //
    // 已知代价：浅色主题下 onSecondaryContainer 与 onSurfaceVariant 同为 tone 30，经
    // harmonized() 后对比度正好 1.00（六套主题里除 monochrome 全中）——选中态的前景色
    // 其实不变色，全靠药丸在说话。M3 那边图标靠填充 / 描边两个字形补这一刀，而 Lucide
    // 是单线图标集，没有这根柱子。铺满整格的药丸比 M3 只包图标的信号强得多，够用。
    final target = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      // 不用 InkWell：水波盖在药丸上并不好看，而且玻璃本身不是 Material，为了让水波
      // 显出来还得额外铺一层。反馈交给药丸的滑动和图标变色就够了。
      // opaque 让整格都可点，而不是只有图标和文字那一小块。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 视觉子树不再往上报语义：里面那个 Text 会和外层 Semantics.label 合并，
        // 读屏把标签念两遍。注意**不能**用外层 Semantics 的 excludeSemantics —
        // 那会把 GestureDetector 的点击动作一起剥掉。
        child: ExcludeSemantics(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: Durations.medium2,
            builder: (context, color, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 21, color: color),
                    child: destination.icon,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final MoodiaryNavAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    // 投影跟胶囊同款，所以不用 Material 的 elevation（那是另一套物理投影模型，
    // 形状和衰减都对不上）。按钮本身不透明，直接让 ShapeDecoration 画就行 ——
    // 玻璃那边要自绘挖空是因为投影会被 BackdropFilter 当背景采走，这里没这问题。
    Widget button = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        shadows: MoodiaryGlassSurface.defaultShadows(scheme.brightness),
      ),
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onPressed,
          child: SizedBox.square(
            dimension: _kActionSize,
            child: IconTheme.merge(
              data: IconThemeData(size: 22, color: scheme.onPrimary),
              child: Center(child: action.icon),
            ),
          ),
        ),
      ),
    );
    final tooltip = action.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}
