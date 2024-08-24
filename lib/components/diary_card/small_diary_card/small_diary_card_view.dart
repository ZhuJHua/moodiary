import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';

import 'small_diary_card_logic.dart';

class SmallDiaryCardComponent extends StatelessWidget {
  const SmallDiaryCardComponent({super.key, required this.diary, required this.tag});

  final Diary diary;

  final String tag;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SmallDiaryCardLogic(), tag: tag);
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    Widget buildImage() {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: FileImage(File(Utils().fileUtil.getRealPath('image', diary.imageName.first))),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          ),
        ),
      );
    }

    return GetBuilder<SmallDiaryCardLogic>(
      init: logic,
      assignId: true,
      tag: tag,
      autoRemove: false,
      builder: (logic) {
        return InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
          onTap: () async {
            await logic.toDiary(diary);
          },
          child: Card.filled(
            color: colorScheme.surfaceContainer,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 122),
              child: Row(
                children: [
                  if (diary.imageName.isNotEmpty && int.parse(tag) & 1 == 0) ...[buildImage()],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (diary.title != null) ...[
                            Text(
                              diary.title!,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle.titleMedium,
                              maxLines: 1,
                            )
                          ],
                          Text(
                            diary.contentText.trim(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                    ),
                  ),
                  if (diary.imageName.isNotEmpty && int.parse(tag) & 1 == 1) ...[buildImage()],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
