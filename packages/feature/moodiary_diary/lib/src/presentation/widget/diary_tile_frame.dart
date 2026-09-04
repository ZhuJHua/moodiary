import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// 条目的同步状态：内联进元信息行，不用会盖住内容的角标。
enum DiaryCardSyncState { none, dirty, syncing }

/// 心情值 → 颜色。与详情页的 [MoodIconComponent] 取同一对端点。
///
/// 注意这条色阶是红→绿在 sRGB 里直插，**中点是浑浊的土黄**，而 0.5 恰好是
/// 心情三分类的语义色（离散取色，旧红绿插值已废）。
Color diaryMoodColor(DiaryMood mood) => mood.color;

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

  /// 列表处于多选态 —— 无论本条选没选中都要出勾选位（未选是空心圈）。
  final bool selecting;
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
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  /// 勾选标记的边长，以及它到外壳上边 / 右边的距离（两个方向同一个值）。
  /// 标记由外壳统一摆放：时间线与信息流的元信息行一个在顶、一个在底，内联进去必然
  /// 一个在右上、一个在右下。
  static const double _kMarkSize = 18.0;
  static const double _kMarkInset = 8.0;

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
        child: MInkWell(
          borderRadius: borderRadius,
          // 无边框的连续流里高亮要更轻一档，否则整张卡都在闪。
          // （水波本来就没有：MInkWell 画的是一层遮罩，不是扩散动画。）
          overlayColor: colors.onSurface.withValues(alpha: 0.06),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              // 浮在内容之上，不占位：让槽会把缩略图挤窄，进出多选态整列都在跳。
              // top 与 right 同一个值，两种布局看上去在同一个位置。
              if (selecting)
                Positioned(
                  top: _kMarkInset,
                  right: _kMarkInset,
                  width: _kMarkSize,
                  height: _kMarkSize,
                  child: DiarySelectMark(selected: selected),
                ),
            ],
          ),
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

/// 多选态的勾选标记：选中 = 实心圆 + 白勾，未选 = 描边空圈。
///
/// 自绘圆而不是用 `circleCheck` 字形 —— 图标字重细、在缩略图上方几乎看不见，
/// 且实心/空心两态的视线跳动太小。铺满父级给的方框（[DiaryTileFrame] 统一定尺寸）。
class DiarySelectMark extends StatelessWidget {
  final bool selected;

  const DiarySelectMark({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return AnimatedContainer(
      duration: Durations.short3,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: .circle,
        // 不透明：它浮在内容之上，半透会让底下的字透出来糊成一团。
        color: selected ? colors.primary : colors.surfaceContainerLowest,
        border: .all(
          color: selected ? colors.primary : colors.outline,
          width: 1.25,
        ),
      ),
      child: selected
          ? Icon(LucideIcons.check, size: 12, color: colors.onPrimary)
          : null,
    );
  }
}
