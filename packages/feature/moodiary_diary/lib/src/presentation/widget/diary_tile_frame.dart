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
          overlayColor: colors.onSurface.withValues(alpha: 0.06),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              if (selecting)
                Positioned(
                  top: _kMarkInset,
                  right: _kMarkInset,
                  width: _kMarkSize,
                  height: _kMarkSize,
                  child: MSelectMark(selected: selected),
                ),
            ],
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
