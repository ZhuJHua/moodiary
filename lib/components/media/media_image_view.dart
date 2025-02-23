import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:uuid/uuid.dart';

class MediaImageComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> imageList;

  const MediaImageComponent({
    super.key,
    required this.dateTime,
    required this.imageList,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
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
                DateFormat.yMMMMEEEEd().format(dateTime),
                style: textStyle.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
              Text(
                l10n.mediaImageCount(imageList.length),
                style: textStyle.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              childAspectRatio: 1.0,
              crossAxisSpacing: 1.5,
              mainAxisSpacing: 1.5,
            ),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final image = ThumbnailImage(
                imagePath: imageList[index],
                size: 120,
                heroTag: '$heroPrefix$index',
                onTap: () async {
                  await showImageView(
                    context,
                    imageList,
                    index,
                    heroTagPrefix: heroPrefix,
                  );
                },
              );
              return GestureDetector(
                onTap: () async {
                  await showImageView(
                    context,
                    imageList,
                    index,
                    heroTagPrefix: heroPrefix,
                  );
                },
                child: image,
              );
            },
            itemCount: imageList.length,
          ),
        ),
      ],
    );
  }
}
