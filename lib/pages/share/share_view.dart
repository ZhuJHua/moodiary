import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'share_logic.dart';

class SharePage extends StatelessWidget {
  const SharePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<ShareLogic>();
    final state = Bind.find<ShareLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme;
    var imageColor = state.diary.imageColor;
    final colorScheme = imageColor != null
        ? ColorScheme.fromSeed(seedColor: Color(imageColor), brightness: Theme.of(context).brightness)
        : Theme.of(context).colorScheme;
    const cardSize = 300.0;
    return GetBuilder<ShareLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Theme(
          data: imageColor != null
              ? Theme.of(context).copyWith(
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: Color(imageColor), brightness: Theme.of(context).brightness))
              : Theme.of(context),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                i18n.shareTitle,
              ),
            ),
            extendBodyBehindAppBar: true,
            body: Center(
              child: RepaintBoundary(
                key: state.key,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withAlpha((255 * 0.5).toInt()),
                        blurRadius: 5.0,
                        offset: const Offset(5.0, 10.0),
                      )
                    ],
                  ),
                  width: cardSize,
                  height: cardSize * 1.618,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (state.diary.imageName.isNotEmpty) ...[
                        Container(
                          height: cardSize * 1.618 * 0.618,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                                image:
                                    FileImage(File(Utils().fileUtil.getRealPath('image', state.diary.imageName.first))),
                                fit: BoxFit.cover),
                          ),
                        )
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Center(
                            child: Text(
                              state.diary.contentText,
                              overflow: TextOverflow.fade,
                              style: textStyle.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                MoodIconComponent(
                                  value: state.diary.mood,
                                  width: (textStyle.titleSmall!.fontSize! * textStyle.titleSmall!.height!),
                                ),
                                if (state.diary.weather.isNotEmpty) ...[
                                  const SizedBox(
                                    height: 12.0,
                                    child: VerticalDivider(
                                      width: 12.0,
                                    ),
                                  ),
                                  Icon(
                                    WeatherIcon.map[state.diary.weather.first],
                                    size: textStyle.titleSmall!.fontSize! * textStyle.titleSmall!.height!,
                                  )
                                ],
                                const SizedBox(
                                  width: 12.0,
                                ),
                                Text(
                                  state.diary.time.toString().split(' ')[0],
                                  style: textStyle.titleSmall,
                                ),
                              ],
                            ),
                            Text(
                              i18n.shareName,
                              style: textStyle.labelMedium,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                logic.share();
              },
              child: const Icon(Icons.share),
            ),
          ),
        );
      },
    );
  }
}
