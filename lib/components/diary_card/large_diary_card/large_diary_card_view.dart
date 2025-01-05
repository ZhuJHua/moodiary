import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/diary_card/basic_diary_card/basic_card_logic.dart';

import '../../../utils/file_util.dart';

class LargeDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const LargeDiaryCardComponent({super.key, required this.diary});

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
                        Text(
                          diary.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.titleMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      if (diary.contentText.isNotEmpty)
                        Text(
                          diary.contentText.trim(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 4,
                          style: textStyle.bodyMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      Text(
                        DateFormat.yMd().add_Hms().format(diary.time),
                        style: textStyle.labelSmall?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
            // Positioned(
            //   top: 4,
            //   right: 4,
            //   child: Container(
            //     decoration: ShapeDecoration(
            //         shape: const CircleBorder(),
            //         color: colorScheme.surfaceContainerLow),
            //     width: 12,
            //     height: 12,
            //     child: Center(
            //       child: Container(
            //         decoration: ShapeDecoration(
            //           shape: const CircleBorder(),
            //           color: Color.lerp(AppColor.emoColorList.first,
            //               AppColor.emoColorList.last, diary.mood),
            //         ),
            //         width: 8,
            //         height: 8,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
