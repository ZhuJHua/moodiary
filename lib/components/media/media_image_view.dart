import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

class MediaImageComponent extends StatelessWidget {
  final DateTime dateTime;
  final List<String> imageList;

  const MediaImageComponent(
      {super.key, required this.dateTime, required this.imageList});

  void _toPhotoView(int index, List<String> filePath) {
    Get.toNamed(AppRoutes.photoPage, arguments: [filePath, index]);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            DateFormat.yMMMMEEEEd().format(dateTime),
            style: textStyle.titleSmall?.copyWith(color: colorScheme.secondary),
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
          padding: const EdgeInsets.all(4.0),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ThumbnailImage(
              imagePath: imageList[index],
              size: 120,
              onTap: () {
                _toPhotoView(index, imageList);
              },
            );
          },
          itemCount: imageList.length,
        ),
      ],
    );
  }
}
