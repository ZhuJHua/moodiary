import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

enum DiaryCardSyncState { none, dirty, syncing }

class DiaryTileFrame extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry padding;

  final EdgeInsetsGeometry margin;

  final bool card;

  final BorderRadius borderRadius;

  final bool selecting;
  final bool selected;

  /// 勾选圈距右上角的距离：带图卡片要整个落进图片圆角里
  final double markInset;
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
    this.markInset = 8,
    this.onTap,
    this.onLongPress,
  });

  static const double _kMarkSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Padding(
      padding: margin,
      child: AnimatedContainer(
        duration: Durations.short3,
        // 选中色按设计系统取 secondaryContainer；整色在中性主题下太重，叠在底色上取六成
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  colors.secondaryContainer.withValues(alpha: 0.6),
                  card ? colors.surfaceContainerLow : colors.surface,
                )
              : (card ? colors.surfaceContainerLow : Colors.transparent),
          borderRadius: borderRadius,
        ),
        child: Semantics(
          container: true,
          selected: selecting ? selected : null,
          child: MInkWell(
            borderRadius: borderRadius,
            overlayColor: colors.onSurface.withValues(alpha: 0.06),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Padding(padding: padding, child: child),
                if (selecting)
                  Positioned(
                    top: markInset,
                    right: markInset,
                    width: _kMarkSize,
                    height: _kMarkSize,
                    child: ExcludeSemantics(
                      child: MSelectMark(selected: selected),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
