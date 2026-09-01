import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

/// 网格第一格：拍摄 / 录像。
///
/// 它在这里，编辑器那个「相册 / 拍照」二选一弹窗才能整个去掉 —— 弹窗让两条路都多
/// 一次点击，而拍照本来就该和相册在同一屏里选。
///
/// iOS 上要显式 `shouldRevertGrid: false` 才真的是「第一格」：包里 Apple 分支默认
/// 翻转整个网格，`prepend` 的那格会被甩到视觉最后。
class CaptureTile extends StatelessWidget {
  const CaptureTile({super.key, required this.video, required this.onTap});

  final bool video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return MInkWell(
      onTap: onTap,
      child: ColoredBox(
        color: theme.colors.surfaceContainerHigh,
        child: Column(
          mainAxisAlignment: .center,
          spacing: 6,
          children: [
            Icon(
              video ? LucideIcons.video : LucideIcons.camera,
              size: 22,
              color: theme.colors.onSurfaceVariant,
            ),
            Text(
              video ? l10n.picker.record : l10n.picker.capture,
              style: theme.typography.labelSmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
