import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/diary_card/basic_card_logic.dart';
import 'package:moodiary/utils/file_util.dart';

class CalendarDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const CalendarDiaryCardComponent({super.key, required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    Widget buildImage() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 4.0,
          children: List.generate(diary.imageName.length, (index) {
            return SizedBox(
              height: 100,
              width: 100,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: ResizeImage(
                      FileImage(
                        File(FileUtil.getRealPath(
                            'image', diary.imageName[index])),
                      ),
                      width: (100 * pixelRatio).toInt(),
                    ),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: AppBorderRadius.smallBorderRadius,
                ),
              ),
            );
          }),
        ),
      );
    }

    Widget buildTime() {
      return Text(
        DateFormat.yMMMMEEEEd().add_jms().format(diary.time),
        style: textStyle.labelSmall?.copyWith(color: colorScheme.secondary),
      );
    }

    return InkWell(
      child: Card.filled(
          color: colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            onTap: () async {
              await toDiaryInCalendar(diary);
            },
            child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  spacing: 4.0,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTime(),
                    if (diary.title.isNotEmpty)
                      EllipsisText(
                        diary.title.trim(),
                        maxLines: 1,
                        style: textStyle.titleMedium!.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    if (diary.contentText.isNotEmpty)
                      EllipsisText(
                        diary.contentText.trim().removeLineBreaks(),
                        maxLines: 4,
                        style: textStyle.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    buildImage()
                  ],
                )),
          )),
    );
  }
}
