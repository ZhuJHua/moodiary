import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';

import 'large_diary_card_logic.dart';

class LargeDiaryCardComponent extends StatelessWidget {
  const LargeDiaryCardComponent({super.key, required this.diary, required this.tag});

  final Diary diary;

  final String tag;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(LargeDiaryCardLogic(), tag: tag);

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
          borderRadius: const BorderRadius.all(Radius.circular(12.0)),
        ),
      );
    }

    return GetBuilder<LargeDiaryCardLogic>(
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
              constraints: const BoxConstraints(maxHeight: 252),
              child: Column(
                children: [
                  if (diary.imageName.isNotEmpty) ...[buildImage()],
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
                              style: textStyle.titleMedium!.copyWith(),
                              maxLines: 1,
                            )
                          ],
                          Text(
                            diary.contentText.trim(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
