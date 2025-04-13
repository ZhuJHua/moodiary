import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/icons.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/diary_render/diary_render.dart';
import 'package:moodiary/components/image_view/images_view.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';

import 'diary_details_logic.dart';

class DiaryDetailsPage extends StatelessWidget {
  DiaryDetailsPage({super.key});

  final tag = (Get.arguments[0] as Diary).id;

  Widget buildAChip(
    Widget label,
    Widget? avatar, {
    required BuildContext context,
  }) {
    return Chip(
      label: label,
      avatar: avatar,
      side: BorderSide.none,
      backgroundColor: context.theme.colorScheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.zero,
    );
  }

  Widget buildChipList({required BuildContext context, required Diary diary}) {
    final dateTime = DateFormat.yMMMd().add_Hms().format(diary.time).split(' ');
    final date = dateTime.first;
    final time = dateTime.last;
    return Wrap(
      spacing: 8.0,
      children: [
        buildAChip(
          context: context,
          MoodIconComponent(value: diary.mood),
          null,
        ),
        buildAChip(
          context: context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: context.textTheme.labelSmall!.copyWith(
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
              Text(
                time,
                style: context.textTheme.labelSmall!.copyWith(
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Icon(Icons.access_time_outlined),
        ),
        if (diary.position.isNotEmpty) ...[
          buildAChip(
            context: context,
            Text(diary.position[2]),
            const Icon(Icons.location_city_rounded),
          ),
        ],
        if (diary.weather.isNotEmpty) ...[
          buildAChip(
            context: context,
            Text(
              '${diary.weather[2]} ${diary.weather[1]}°C',
              style: context.textTheme.labelLarge!.copyWith(
                color: context.theme.colorScheme.onSurface,
              ),
            ),
            Icon(WeatherIcon.map[diary.weather[0]]),
          ),
        ],
        buildAChip(
          context: context,
          Text(
            context.l10n.diaryCount(diary.contentText.length),
            style: context.textTheme.labelLarge!.copyWith(
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          const Icon(Icons.text_fields_outlined),
        ),
        ...List.generate(diary.tags.length, (index) {
          return buildAChip(
            context: context,
            Text(
              diary.tags[index],
              style: context.textTheme.labelLarge!.copyWith(
                color: context.theme.colorScheme.onSurface,
              ),
            ),
            const Icon(Icons.tag_outlined),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryDetailsLogic>(tag: tag);
    final state = Bind.find<DiaryDetailsLogic>(tag: tag).state;
    final size = MediaQuery.sizeOf(context);

    return GetBuilder<DiaryDetailsLogic>(
      tag: state.diary.id,
      builder: (_) {
        final customColorScheme =
            (state.imageColor != null &&
                    PrefUtil.getValue<bool>('dynamicColor') == true)
                ? ColorScheme.fromSeed(
                  seedColor: Color(state.imageColor!),
                  brightness: context.theme.colorScheme.brightness,
                )
                : context.theme.colorScheme;
        return Theme(
          data: context.theme.copyWith(colorScheme: customColorScheme),
          child: Builder(
            builder: (context) {
              return Scaffold(
                backgroundColor: customColorScheme.surface,
                body: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight:
                          state.diaryHeader
                              ? (state.aspect != null
                                  ? min(
                                    size.width / state.aspect!,
                                    size.height * 0.382,
                                  )
                                  : null)
                              : null,
                      title: Text(
                        state.diary.title,
                        style: context.textTheme.titleMedium,
                      ),
                      leading: const PageBackButton(),
                      centerTitle: false,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background:
                            state.diaryHeader
                                ? ImagesView(
                                  imageName: state.diary.imageName,
                                  customColorScheme: customColorScheme,
                                )
                                : null,
                      ),
                      pinned: true,
                      actions: [
                        // IconButton(
                        //     onPressed: () {
                        //       showModalBottomSheet(
                        //           context: context,
                        //           useSafeArea: true,
                        //           showDragHandle: true,
                        //           builder: (context) {
                        //             return Padding(
                        //               padding: MediaQuery.viewInsetsOf(context),
                        //               child: AskQuestionComponent(
                        //                 content: state.diary.contentText,
                        //               ),
                        //             );
                        //           });
                        //     },
                        //     icon: const Icon(Icons.chat)),
                        PopupMenuButton(
                          offset: const Offset(0, 46),
                          itemBuilder: (context) {
                            return <PopupMenuEntry<String>>[
                              if (state.showAction) ...[
                                PopupMenuItem(
                                  onTap: () async {
                                    logic.delete(state.diary);
                                  },
                                  child: Row(
                                    spacing: 16.0,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.delete_rounded),
                                      Text(context.l10n.diaryDelete),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  onTap: () async {
                                    logic.toEditPage(state.diary);
                                  },
                                  child: Row(
                                    spacing: 16.0,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.edit_rounded),
                                      Text(context.l10n.diaryEdit),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                              ],
                              PopupMenuItem(
                                onTap: () async {
                                  logic.toSharePage();
                                },
                                child: Row(
                                  spacing: 16.0,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.share_rounded),
                                    Text(context.l10n.diaryShare),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(4.0),
                      sliver: SliverList.list(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: buildChipList(
                                context: context,
                                diary: state.diary,
                              ),
                            ),
                          ),
                          Card.filled(
                            color: customColorScheme.surfaceContainerLow,
                            child: DiaryRender(
                              diary: state.diary,
                              customColorScheme: customColorScheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
