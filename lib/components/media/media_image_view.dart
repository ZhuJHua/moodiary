import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/l10n/l10n.dart';
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
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.theme.colorScheme.secondary,
                ),
              ),
              Text(
                context.l10n.mediaImageCount(imageList.length),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            childAspectRatio: 1.0,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final image = MoodiaryImage(
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
            return image;
          },
          itemCount: imageList.length,
        ),
      ],
    );
  }
}
