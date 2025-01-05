import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/diary_card/basic_diary_card/basic_card_logic.dart';

import '../../../utils/file_util.dart';

class SmallDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const SmallDiaryCardComponent(
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
                width: (122 * pixelRatio).toInt(),
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
          height: 122.0,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (diary.title.isNotEmpty) ...[
                        Text(
                          diary.title,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.titleMedium
                              ?.copyWith(color: colorScheme.onSurface),
                          maxLines: 1,
                        )
                      ],
                      Text(
                        diary.contentText.trim(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: textStyle.bodyMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      Text(
                        DateFormat.yMMMd().add_Hms().format(diary.time),
                        style: textStyle.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
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
