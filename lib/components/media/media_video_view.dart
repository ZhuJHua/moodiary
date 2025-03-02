import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/pages/video/video_view.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class MediaVideoComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> videoList;

  const MediaVideoComponent({
    super.key,
    required this.dateTime,
    required this.videoList,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // 将视频路径转换为缩略图路径
    final thumbnailList =
        videoList.map((e) {
          final id = e.split('video-')[1].split('.')[0];
          return '${dirname(e)}/thumbnail-$id.jpeg';
        }).toList();
    final heroPrefix = const Uuid().v4();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.yMMMEd().format(dateTime),
                style: textStyle.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
              Text(
                l10n.mediaVideoCount(videoList.length),
                style: textStyle.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            childAspectRatio: 1.0,
            crossAxisSpacing: 1.0,
            mainAxisSpacing: 1.0,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () async {
                await showVideoView(
                  context,
                  videoList,
                  index,
                  heroTagPrefix: '$heroPrefix$index',
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ThumbnailImage(
                      imagePath: thumbnailList[index],
                      heroTag: '$heroPrefix$index',
                      size: 120,
                    ),
                  ),
                  const FrostedGlassButton(
                    size: 32,
                    child: Center(child: Icon(Icons.play_arrow_rounded)),
                  ),
                ],
              ),
            );
          },
          itemCount: thumbnailList.length,
        ),
      ],
    );
  }
}
