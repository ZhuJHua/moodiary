import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/diary_card/basic_diary_card/basic_card_logic.dart';
import 'package:mood_diary/utils/utils.dart';

class CalendarDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const CalendarDiaryCardComponent({super.key, required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    Widget buildContent() {
      return Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...[
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
        ],
      );
    }

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
                    image: FileImage(File(Utils().fileUtil.getRealPath('image', diary.imageName[index]))),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: AppBorderRadius.mediumBorderRadius,
                ),
              ),
            );
          }),
        ),
      );
    }

    Widget buildTime() {
      return Text(
        DateFormat.jms().format(diary.time),
        style: textStyle.labelSmall,
      );
    }

    return InkWell(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      onTap: () async {
        await toDiaryInCalendar(diary);
      },
      child: Card.filled(
          color: colorScheme.surfaceContainerLow,
          child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                spacing: 4.0,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [buildTime(), buildContent(), buildImage()],
              ))),
    );
  }
}
