import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/diary_card/basic_card_logic.dart';
import 'package:moodiary/utils/file_util.dart';

class GirdDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const GirdDiaryCardComponent({super.key, required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    Widget buildImage() {
      return Container(
        height: 154.0,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: ResizeImage(
              FileImage(
                  File(FileUtil.getRealPath('image', diary.imageName.first))),
              width: (250 * pixelRatio).toInt(),
            ),
            fit: BoxFit.cover,
          ),
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
      );
    }

    return Card.filled(
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        onTap: () {
          toDiary(diary);
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diary.imageName.isNotEmpty) ...[buildImage()],
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 4.0,
                    children: [
                      if (diary.title.isNotEmpty)
                        EllipsisText(
                          diary.title.trim(),
                          maxLines: 1,
                          style: textStyle.titleMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      if (diary.contentText.isNotEmpty)
                        EllipsisText(
                          diary.contentText.trim().removeLineBreaks(),
                          maxLines: 4,
                          style: textStyle.bodyMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      Text(
                        DateFormat.yMd().add_Hms().format(diary.time),
                        style: textStyle.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
