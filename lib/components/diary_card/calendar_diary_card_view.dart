import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/base/image.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/diary_card/basic_card_logic.dart';
import 'package:moodiary/utils/file_util.dart';

class CalendarDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const CalendarDiaryCardComponent({super.key, required this.diary});

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    Widget buildImage() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 8.0,
          children: List.generate(diary.imageName.length, (index) {
            return SizedBox(
              width: 100,
              height: 100,
              child: MoodiaryImage(
                imagePath: FileUtil.getRealPath(
                  'image',
                  diary.imageName[index],
                ),
                borderRadius: AppBorderRadius.smallBorderRadius,
                showBorder: true,
                size: 100,
              ),
            );
          }),
        ),
      );
    }

    Widget buildTime() {
      return Text(
        DateFormat.yMMMMEEEEd().add_jms().format(diary.time),
        style: context.textTheme.labelSmall?.copyWith(
          color: context.theme.colorScheme.secondary,
        ),
      );
    }

    return InkWell(
      child: Card.filled(
        color: context.theme.colorScheme.surfaceContainerLow,
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
                Row(
                  spacing: 4.0,
                  children: [
                    buildTime(),
                    FaIcon(
                      DiaryType.fromValue(diary.type).icon,
                      size: 10,
                      color: context.theme.colorScheme.secondary,
                    ),
                  ],
                ),
                if (diary.title.isNotEmpty)
                  EllipsisText(
                    diary.title.trim(),
                    maxLines: 1,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                if (diary.contentText.isNotEmpty)
                  EllipsisText(
                    diary.contentText.trim().removeLineBreaks(),
                    maxLines: 4,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                buildImage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
