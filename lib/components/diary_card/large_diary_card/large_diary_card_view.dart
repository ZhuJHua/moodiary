import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/diary_card/basic_diary_card/basic_card_logic.dart';
import 'package:mood_diary/utils/utils.dart';

class LargeDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const LargeDiaryCardComponent({super.key, required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    Widget buildImage() {
      return Container(
        height: 154.0,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(Utils().fileUtil.getRealPath('image', diary.imageName.first))),
            fit: BoxFit.cover,
          ),
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
      );
    }

    return InkWell(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      onTap: () {
        toDiary(diary);
      },
      child: Card.filled(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            if (diary.imageName.isNotEmpty) ...[buildImage()],
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 4.0,
                children: [
                  if (diary.title.isNotEmpty) ...[
                    Text(
                      diary.title,
                      style: textStyle.titleMedium!.copyWith(),
                    )
                  ],
                  Text(
                    diary.contentText.trim(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: getMaxLines(diary.contentText),
                    style: textStyle.bodyMedium,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat.yMMMd().add_Hms().format(diary.time),
                        style: textStyle.labelSmall,
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
