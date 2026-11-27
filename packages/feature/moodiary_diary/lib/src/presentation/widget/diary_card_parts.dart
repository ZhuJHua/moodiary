import 'package:fast_image/fast_image.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class DiaryMediaCell extends StatelessWidget {
  final DiaryVisualMedia media;
  final double width;
  final bool pending;
  final int moreCount;

  const DiaryMediaCell(
    this.media, {
    super.key,
    required this.width,
    required this.pending,
    this.moreCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final isVideo = media.isVideo;
    final path = AppFiles.getRealPath(
      isVideo ? 'thumbnail' : 'image',
      media.name,
    );
    final decodeWidth = (width * dpr).round();
    return ClipRRect(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      child: Stack(
        fit: .expand,
        children: [
          ColoredBox(color: colors.surfaceContainerHighest),
          Image(
            key: ValueKey('$path#$pending'),
            image: FastImage(
              path,
              tier: isVideo ? null : FastImageTier.fit(decodeWidth),
              decodeWidth: isVideo ? decodeWidth : null,
            ),
            fit: .cover,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => pending
                ? const SizedBox.shrink()
                : Icon(LucideIcons.imageOff, color: colors.onSurfaceVariant),
          ),
          if (isVideo)
            Positioned(
              left: 6,
              bottom: 6,
              // 只标出类型：不加底板，靠阴影压住浅色封面
              child: Icon(
                LucideIcons.video,
                size: 16,
                color: context.theme.onMedia,
                shadows: [
                  Shadow(
                    color: colors.scrim.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          if (moreCount > 0)
            ColoredBox(
              color: colors.scrim.withValues(alpha: 0.44),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: context.theme.typography.labelLarge.emphasized.onMedia,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DiaryCardMeta extends StatelessWidget {
  final DiarySummary diary;
  final String stamp;
  final Place? place;
  final DiaryCardSyncState syncState;
  final bool showMood;

  const DiaryCardMeta({
    super.key,
    required this.diary,
    required this.stamp,
    required this.place,
    required this.syncState,
    this.showMood = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colors.onSurfaceVariant;
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final icon = diary.weatherIcon;
    // 天气文案是写入时的快照（语言、长短都不定），卡片只给图标 + 温度
    final temp = diary.weatherTemp?.trim() ?? '';
    final placeName = place?.name.trim() ?? '';
    const separator = ' · ';

    Widget text(String value) =>
        Text(value, style: style, maxLines: 1, overflow: .ellipsis);

    Widget attachment(IconData icon, int count) => Row(
      mainAxisSize: .min,
      children: [
        const SizedBox(width: 5),
        Icon(icon, size: 12, color: color),
        if (count > 1) text('$count'),
      ],
    );

    return Row(
      children: [
        if (showMood) ...[
          MoodGlyph(mood: diary.mood, size: 16),
          const SizedBox(width: 6),
        ],
        // 一段文字从尾部省略，正好是地点 → 天气 → 时间的让位顺序，尾部图标始终留住
        Expanded(
          child: icon == null
              ? text(placeName.isEmpty ? stamp : '$stamp$separator$placeName')
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: stamp),
                      const TextSpan(text: separator),
                      WidgetSpan(
                        alignment: .middle,
                        child: Padding(
                          padding: const .only(right: 2),
                          child: Icon(
                            qweatherIcon(icon) ?? LucideIcons.cloud,
                            size: 12,
                            color: color,
                          ),
                        ),
                      ),
                      if (temp.isNotEmpty) TextSpan(text: '$temp°'),
                      if (placeName.isNotEmpty)
                        TextSpan(text: '$separator$placeName'),
                    ],
                  ),
                  style: style,
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
        ),
        if (diary.audioCount > 0) attachment(LucideIcons.mic, diary.audioCount),
        if (diary.fileCount > 0)
          attachment(LucideIcons.paperclip, diary.fileCount),
        if (syncState != .none) ...[
          const SizedBox(width: 5),
          DiarySyncBadge(state: syncState),
        ],
      ],
    );
  }
}

double diaryScaledLineHeight(BuildContext context, TextStyle style) =>
    MediaQuery.textScalerOf(context).scale(style.fontSize!) *
    (style.height ?? 1);
