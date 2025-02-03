import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/diary_card/basic_card_logic.dart';
import 'package:moodiary/utils/file_util.dart';

class ListDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const ListDiaryCardComponent(
      {super.key, required this.diary, required this.tag});

  final Diary diary;

  final String tag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    Widget buildImage() {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ResizeImage(
                FileImage(
                    File(FileUtil.getRealPath('image', diary.imageName.first))),
                width: (132 * pixelRatio).toInt(),
              ),
              fit: BoxFit.cover,
            ),
            borderRadius: AppBorderRadius.mediumBorderRadius,
          ),
        ),
      );
    }

    return Card.filled(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        onTap: () async {
          await toDiary(diary);
        },
        child: SizedBox(
          height: 132.0,
          child: Row(
            children: [
              if (diary.imageName.isNotEmpty && int.parse(tag) & 1 == 0) ...[
                buildImage()
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4.0,
                    children: [
                      if (diary.title.isNotEmpty) ...[
                        EllipsisText(
                          diary.title,
                          style: textStyle.titleMedium
                              ?.copyWith(color: colorScheme.onSurface),
                          maxLines: 1,
                        )
                      ],
                      Expanded(
                        child: EllipsisText(
                          diary.contentText.trim(),
                          maxLines: diary.title.isNotEmpty ? 3 : 4,
                          style: textStyle.bodyMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMEEEEd().add_Hms().format(diary.time),
                        style: textStyle.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              if (diary.imageName.isNotEmpty && int.parse(tag) & 1 == 1) ...[
                buildImage()
              ],
            ],
          ),
        ),
      ),
    );
  }
}
