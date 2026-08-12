import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;
import 'package:mui/mui.dart';

/// 条目的同步状态：内联进元信息行，不用会盖住内容的角标。
enum DiaryCardSyncState { none, dirty, syncing }

/// 心情值 → 颜色。与详情页的 [MoodIconComponent] 取同一对端点。
///
/// 注意这条色阶是红→绿在 sRGB 里直插，**中点是浑浊的土黄**，而 0.5 恰好是
/// [Diary.empty] 的默认值。等色阶改成发散型（两端各自朝中性色收敛 + 在 OKLab 里插值）
/// 时，只需要改这一个函数。
Color diaryMoodColor(double mood) => Color.lerp(
  AppColor.emoColorList.first,
  AppColor.emoColorList.last,
  mood.clamp(0.0, 1.0).toDouble(),
)!;

/// 首页条目的公共外壳：选中态描边 / 底色、点击与长按、按压高亮。
///
/// 抽出来是因为时间线与信息流**都不套 [Card]**——本仓的多选态与同步态原本只由
/// `Card` 承载（选中描边 + 右上勾选圈），每种布局各写一份必然走形。
class DiaryTileFrame extends StatelessWidget {
  final Widget child;

  /// 外壳与内容之间的留白。高亮和选中描边都画在这层之外。
  final EdgeInsetsGeometry padding;

  /// 外壳与列表边缘之间的留白 —— 让圆角高亮不至于贴着屏幕边。
  final EdgeInsetsGeometry margin;

  /// 画成一张卡片（填充底色）还是透明贴在页面上。
  /// 时间线走透明——它左边有一条轴，卡片会把轴切断；信息流走卡片。
  final bool card;

  final BorderRadius borderRadius;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DiaryTileFrame({
    super.key,
    required this.child,
    this.padding = const .fromLTRB(8, 2, 8, 6),
    this.margin = .zero,
    this.card = false,
    this.borderRadius = AppBorderRadius.mediumBorderRadius,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Padding(
      padding: margin,
      child: AnimatedContainer(
        duration: Durations.short3,
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.4)
              : (card ? colors.surfaceContainerLow : null),
          borderRadius: borderRadius,
          // 未选中也画一圈透明描边：否则选中时会因为多出 1.5px 而整条抖一下。
          border: .all(
            color: selected ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          // 无边框的连续流里，扩散水波比高亮更吵；只留一层轻微的按压高亮。
          splashFactory: NoSplash.splashFactory,
          highlightColor: colors.onSurface.withValues(alpha: 0.06),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 同步状态标记：待推 = 上传云图标，同步中 = 转圈。[DiaryCardSyncState.none] 不占位。
class DiarySyncBadge extends StatelessWidget {
  final DiaryCardSyncState state;

  const DiarySyncBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == .none) return const SizedBox.shrink();
    final color = context.theme.colors.primary;
    return state == .syncing
        ? SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        : Icon(LucideIcons.cloudUpload, size: 14, color: color);
  }
}

/// 多选态的勾选标记。选中实心勾，未选中空心圈。
class DiarySelectMark extends StatelessWidget {
  final bool selected;

  const DiarySelectMark({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Icon(
      selected ? LucideIcons.circleCheck : LucideIcons.circle,
      size: 16,
      color: selected ? colors.primary : colors.outline,
    );
  }
}
