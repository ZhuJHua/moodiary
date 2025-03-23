import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:refreshed/refreshed.dart';

import 'share_logic.dart';

class SharePage extends StatelessWidget {
  const SharePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<ShareLogic>();
    final state = Bind.find<ShareLogic>().state;

    final textStyle = Theme.of(context).textTheme;
    final imageColor = state.diary.imageColor;
    final colorScheme = imageColor != null
        ? ColorScheme.fromSeed(
            seedColor: Color(imageColor),
            brightness: Theme.of(context).brightness)
        : Theme.of(context).colorScheme;
    const cardSize = 300.0;
    return GetBuilder<ShareLogic>(
      builder: (_) {
        return Theme(
          data: imageColor != null
              ? Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: Color(imageColor),
                      brightness: Theme.of(context).brightness))
              : Theme.of(context),
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              title: Text(
                l10n.shareTitle,
              ),
            ),
            extendBodyBehindAppBar: true,
            body: Center(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: state.key,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withAlpha(
                            (255 * 0.5).toInt(),
                          ),
                          blurRadius: 5.0,
                          offset: const Offset(5.0, 10.0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.diary.imageName.isNotEmpty) ...[
                          Container(
                            height: cardSize * 1.618 * 0.618,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: FileImage(
                                  File(
                                    FileUtil.getRealPath(
                                      'image',
                                      state.diary.imageName.first,
                                    ),
                                  ),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          fit: FlexFit.loose,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Center(
                              child: Text(
                                state.diary.contentText,
                                style: textStyle.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            right: 12,
                            bottom: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  MoodIconComponent(
                                    value: state.diary.mood,
                                    width:
                                        (textStyle.titleSmall!.fontSize! *
                                            textStyle.titleSmall!.height!),
                                  ),
                                  if (state.diary.weather.isNotEmpty) ...[
                                    const SizedBox(
                                      height: 12.0,
                                      child: VerticalDivider(width: 12.0),
                                    ),
                                    Icon(
                                      WeatherIcon.map[state
                                          .diary
                                          .weather
                                          .first],
                                      size:
                                          textStyle.titleSmall!.fontSize! *
                                          textStyle.titleSmall!.height!,
                                    ),
                                  ],
                                  const SizedBox(width: 12.0),
                                  Text(
                                    state.diary.time.toString().split(' ')[0],
                                    style: textStyle.titleSmall,
                                  ),
                                ],
                              ),
                              Text(
                                l10n.shareName,
                                style: textStyle.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                logic.share(context);
              },
              child: const Icon(Icons.share),
            ),
          ),
        );
      },
    );
  }
}